## parse.params=function(params)
## {
##     rr = ""
##     if (nchar(params) == 0) {
##         return (rr)
##     }
##     gr = gregexpr(pattern="--", params)[[1]][1]
##     if (gr != -1) {
##         params = substr(params, gr+3, nchar(params))
##     }
##     rr = gsub("~", "=", params)
##     if (rr == "NA") return ("") else return (rr)
 
## }

path2bucket=function(path, out.bucket, base.mount)
{
    if (grepl(base.mount, path)) {
        return (gsub(base.mount, out.bucket, path))
    } else {
        return (gsub("gs/", "gs://", gsub("/mnt/data/output/", "", path)))
    }
}

rnd.label=function(len=10) {
    vals = c(1:10, letters)
    N = length(vals)
    xx = pmin(N, pmax(1, round(1 + runif(len) * (N-1))))
    paste(vals[xx], collapse="", sep="")
}

dsub=function(module,
              base.mount,
              out.bucket,
              wdir,
              provider="google-cls-v2",
              project,
              zones,
              image,
              machine.ram.gb,
              machine.boot.gb,
              machine.disk.type,
              machine.disk.gb,
              machine.cpu.count,
              ms.root,
              target,
              name,
              wait=T,
              preemtible.count=0,
              credentials.file=NULL,
              mount.buckets,
              mount.bucket.vars,
              out.path,
              out.var,
              dry,
              log.interval,
              drop.params,
              metajob.id,
              params=NULL)
{
    out.bucket.path = path2bucket(path=out.path, out.bucket=out.bucket, base.mount=base.mount)
    cat(sprintf("out bucket path: %s\n", out.bucket.path))
    
    logging = paste0(out.bucket.path, "/.dsub/", name, "_logs")

    params = gsub("~", "=", params)
    param.names = sapply(params, function(x) {
        xx = strsplit(x, "=")[[1]]
        if (length(xx) > 1)
            return (xx[1])
        else
            return (NA)
    })
    params = params[is.na(param.names) | !is.element(param.names, drop.params)]
    params.str = paste(params, paste0("m=", module), collapse=" ")

    # skip if target requires no work
    setwd(paste0(Sys.getenv("MAKESHIFT_ROOT"), "/", wdir))
    test.command = paste("make -q", target, params.str)
    cat(sprintf(">>> DSUB test command: %s\n", test.command))
    
    rc = system(test.command)
    if (rc == 0) {
        cat(">>> DSUB: target exists, skipping\n")
        return (NULL)
    } else if (rc != 1) {
        stop(sprintf("DSUB test failed, rc: %d\n", rc))
    }

    make.command = paste0("make m=gcp dsub_update_local; make ", target, " ", params.str)
    
    if (metajob.id == "NA") {
        metajob.id = paste0(name, "-", rnd.label(12))
        make.command = paste0(make.command, " GCP_DSUB_METAJOB_ID=", metajob.id)
    } 
    
    ds = paste0("'cd ${MAKESHIFT_ROOT}/", wdir, " ; echo \"Running commands: ", make.command, "\"; ", make.command, "'")
    command = paste("dsub",
                    "--input-recursive", paste0("MAKESHIFT_ROOT=", ms.root),
                    "--log-interval", log.interval,
                    "--ssh",
                    "--boot-disk-size", machine.boot.gb,
                    "--min-ram", machine.ram.gb,
                    "--disk-type", machine.disk.type,
                    "--disk-size", machine.disk.gb,
                    "--min-cores", machine.cpu.count,
                    "--user makeshift-user",
                    paste0("--label 'metajob-id=", metajob.id, "'", collapse="", sep=""),
                    "--project", project,
                    if (wait) "--wait" else "",
                    "--name", name,
                    "--command", ds,
                    "--provider", provider,
                    "--project",  project,
                    "--zones", zones,
                    "--enable-stackdriver-monitoring",
                    "--image", image,
                    paste0("--env GCP_RSYNC_SRC_VAR=", out.var), 
                    paste0("--env GCP_RSYNC_TARGET_BUCKET=", out.bucket.path),
                    "--credentials-file", credentials.file,
                    "--logging", logging)
    
    if (preemtible.count > 0)
        command  = paste(command,
                          "--preemptible", preemtible.count,
                          "--retries", preemtible.count+1)

    command  = paste0(command,
                     " --output-recursive ", out.var, "=", out.bucket.path)

    for (i in 1:length(mount.buckets))
        command  = paste0(command,
                          " --mount ", mount.bucket.vars[i], "=", mount.buckets[i])

    ## if (!dry) {
    ##     cat(sprintf(">>> DSUB cleaning logs in: %s\n", logging))
    ##     if (system(paste("gsutil ls", logging), ignore.stdout=T, ignore.stderr=T) == 0)
    ##         system(paste("gsutil -mq rm -rf", logging))
    ## }
    
    cat(paste0(">>> DSUB: running dsub command: \n", gsub("--", '\\\\\n\t--', command), "\n"))
    if (dry) stop("dry run")
    
    tryCatch( {
        rc = system(command)
        if (rc != 0)
            stop("error in dsub")
    }, error = function(e) {
        command = paste("ddel",
                    "--user makeshift-user",
                    paste0("--label 'metajob-id=", metajob.id, "'", collapse="", sep=""),
                    "--project",  project,
                    "--jobs '*'",
                    "--provider", provider)
        cat(paste0(">>> DSUB: running ddel command: \n", gsub("--", '\\\\\n\t--', command), "\n"))
        rc = system(command)
        if (rc != 0) {
            stop("error in ddel")
        } else {
            cat(paste0(">>> DSUB: children jobs removed successfully\n"))
        }
        stop("dsub failed, stopping")
    })
    
}
