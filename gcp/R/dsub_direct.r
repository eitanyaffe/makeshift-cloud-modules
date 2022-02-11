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

dsub.direct=function(out.bucket,
                     base.mount,
                     basedir.log.path,
                     provider,
                     project,
                     zones,
                     image,
                     ms.root,
                     machine.ram.gb,
                     machine.boot.gb,
                     machine.disk.type,
                     machine.disk.gb,
                     machine.cpu.count,
                     name,
                     preemtible.count=0,
                     credentials.file=NULL,
                     ifn.vars,
                     ofn.vars,
                     ifn.paths,
                     ofn.paths,
                     command,
                     dry,
                     log.interval,
                     metajob.id,
                     wait=T)
{
    if (metajob.id == "NA")
        metajob.id = paste0(name, "-", rnd.label(12))
    
    out.bucket.path = path2bucket(path=basedir.log.path, out.bucket=out.bucket, base.mount=base.mount)
    cat(sprintf("out bucket path: %s\n", out.bucket.path))
    
    logging = paste0(out.bucket.path, "/.dsub/", name, "_logs")
    
    command = gsub("~", "=", command)
    
    dsub.command = paste("dsub",
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
                         "--command", paste0("'", paste(command, collapse=" "), "'"),
                         "--provider", provider,
                         "--project",  project,
                         "--zones", zones,
                         "--enable-stackdriver-monitoring",
                         "--image", image,
                         "--credentials-file", credentials.file,
                         "--logging", logging)
    
    if (preemtible.count > 0)
        dsub.command  = paste(dsub.command,
                          "--preemptible", preemtible.count,
                          "--retries", preemtible.count+1)

    for (i in 1:length(ifn.vars)) {
        obucket = path2bucket(path=ifn.paths[i], out.bucket=out.bucket, base.mount=base.mount)
        dsub.command  = paste0(dsub.command,
                               " --input ", ifn.vars[i], "=", obucket)
    }
    for (i in 1:length(ofn.vars)) {
        obucket = path2bucket(path=ofn.paths[i], out.bucket=out.bucket, base.mount=base.mount)
        dsub.command  = paste0(dsub.command,
                               " --output ", ofn.vars[i], "=", obucket)
    }
    
    cat(paste0(">>> DSUB: running dsub dsub.command: \n", gsub("--", '\\\\\n\t--', dsub.command), "\n"))
    if (dry) stop("dry run")
    
    if (system(dsub.command) != 0)
        stop("error in dsub")
}
