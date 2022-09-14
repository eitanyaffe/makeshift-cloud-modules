############################################################################################
# util functions
############################################################################################

create.final.stamp.command=function(job.keys, out.var, is.dir=T)
{
    if (is.dir)
        sprintf("echo %s > $%s/.done_dsub_task", job.keys[length(job.keys)], out.var)
    else
        sprintf("echo %s > $%s", job.keys[length(job.keys)], out.var)
}

path2bucket=function(path, out.bucket, base.mount)
{
    if (substr(path,1,1) == "/") {
        if (grepl(base.mount, path)) {
            return (gsub(base.mount, out.bucket, path))
        } else {
            return (gsub("/mnt/data/output/gs/", "gs://", path))
        }
    } else {
        return (paste0(out.bucket, "/", path))
    }
}

rnd.label=function(len=10) {
    vals = c(1:10, letters)
    N = length(vals)
    xx = pmin(N, pmax(1, round(1 + runif(len) * (N-1))))
    paste(vals[xx], collapse="", sep="")
}

get.job.keys=function(ms.level, name)
{
    # collect parent job keys
    cat(sprintf(">>> DSUB level: %s\n", ms.level))
    job.keys = NULL
    if (ms.level > 1) {
        for (ii in 1:(ms.level-1)) {
            job.key = Sys.getenv(paste0("MS_JOB_KEY_", ii))
            if (job.key == 0)
                stop(sprintf("MS_JOB_KEY_%s not defined", ii))
            cat(sprintf("parent job key %d: %s\n", ii, job.key))
            job.keys = c(job.keys, job.key)
        }
    }
    # create new key for job
    new.job.key = paste0(name, "-", "l", ms.level, "-", rnd.label(12))
    job.keys = c(job.keys, new.job.key)
    job.keys
}

parse.params=function(params, drop.params, module=NULL)
{    
    params = gsub("~", "=", params)
    param.names = sapply(params, function(x) {
        xx = strsplit(x, "=")[[1]]
        if (length(xx) > 1)
            return (xx[1])
        else
            return (NA)
    })
    drop = rep(F, length(params))
    for (i in 1:length(drop.params))
        drop = drop | grepl(drop.params[i], param.names)
    params = params[is.na(param.names) | !drop]
    
    rr = paste(params, collapse=" ")
    if (!is.null(module))
        rr = sprintf("%s %s", rr, paste0("m=", module))
    
    list(params=rr)
}

should.make=function(wdir, test.command)
{
    setwd(paste0(Sys.getenv("MAKESHIFT_ROOT"), "/", wdir))
    cat(sprintf(">>> DSUB test command: %s\n", test.command))
    test.command = paste(test.command, "> /dev/null 2>&1") 
    rc = system(test.command)
    if (rc == 0) {
        cat(">>> DSUB: target exists, skipping\n")
    } else if (rc == 1) {
        return (T)
    } else {
        stop(sprintf("DSUB test failed, rc: %d\n", rc))
    }
    F
}

############################################################################################
# children cleanup functions
############################################################################################

delete.subtree.tasks=function(project, provider, ms.level, job.key)
{
    cat(sprintf(">>> Cleaning up potentially running subtree tasks labelled with key: %s\n", job.key))

    # max attempts per level
    max.attempts = 4

    # dive down this number of levels
    max.levels = 5

    delete.f=function(level) {
        command = paste("ddel",
                        "--user makeshift-user",
                        sprintf("--label 'ms-job-key-%d=%s'", ms.level, job.key),
                        "--project",  project,
                        "--jobs '*'",
                        "--provider", provider)
        if (level > 0)
            command = paste(command, sprintf("--label 'ms-level=%s'", level))
        cat(sprintf(">>> running command: %s\n", command))
        xx = system(command, intern=T, ignore.stderr=T)
        N = as.numeric(strsplit(xx, " ")[[1]][1])
        if (is.na(N)) {
            cat(sprintf(">>> Warning: error parsing ddel result: %s\n", paste(xx, collapse="\n")))
            N = 0
        }
        N
    }
        
    total.deleted = 0
    for (level in (ms.level+1):(ms.level+max.levels)) {
        level.deleted = 0
        for (i in 1:max.attempts) {
            N = delete.f(level=level)
            level.deleted = level.deleted + N
            if (N > 0) {
                cat(sprintf(">>> number of children jobs deleted on level %d was: %d\n", level, N))
            } else {
                break
            }
        }
        total.deleted = total.deleted + level.deleted
    }

    # one last attempt to remove jobs
    for (i in 1:max.attempts) {
        N = delete.f(level=0)
        if (N > 0) {
            cat(sprintf(">>> number of children jobs deleted on all levels was: %d\n", N))
        } else {
            break
        }
        total.deleted = total.deleted + N
    }
    
    cat(sprintf(">>> total number of children jobs deleted: %d\n", total.deleted))
}

remove.previous.tasks=function(job.key.fn, project, provider, ms.level)
{
    cat(sprintf("cleaning up possible orphans in file: %s\n", job.key.fn))
    df = load.table(job.key.fn)

    # remove entire subtree of current task with single delete command
    N = dim(df)[1]
    delete.subtree.tasks(project=project, provider=provider, ms.level=ms.level, job.key=df$key[N])
}

save.job.key.file=function(ofn, ofn.bucket, job.keys, dry)
{
    df = data.frame(level=1:length(job.keys), key=job.keys)
    save.table(df, ofn, verbose=T)

    # copy to bucket
    command  = paste("gsutil -mq cp", ofn, ofn.bucket)
    # cat(sprintf("saving job key file to GCS using command: %s\n", command))
    if (system(command) != 0)
        stop(sprintf("failed running command: %s\n", command))
}

remove.bucket.path=function(path)
{
    command = paste("gsutil -mq rm -f", path, "> /dev/null 2>&1")
    cat(sprintf("removing old logs: %s\n", command)) 
    if (system(command) == 0)
        cat("previous log files removed\n")
}

############################################################################################
# shared functions
############################################################################################

dsub.base=function(job.work.dir,
                   base.mount,
                   out.bucket,
                   provider="google-cls-v2",
                   project,
                   zones,
                   region,
                   image,
                   machine.spec.style,
                   machine.type,
                   machine.ram.gb,
                   machine.boot.gb,
                   machine.disk.type,
                   machine.disk.gb,
                   machine.cpu.count,
                   name,
                   project.name,
                   preemtible.count=0,
                   non.preemtible.retry.count=0,
                   credentials.file=NULL,
                   dry,
                   wait,
                   log.interval,
                   batch.index,
                   ms.level,
                   job.id,
                   job.keys,
                   max.report.level,
                   email,
                   sendgrid.key,
                   use.private)
{
    job.key = job.keys[length(job.keys)]
    
    out.bucket.path = path2bucket(path=job.work.dir, out.bucket=out.bucket, base.mount=base.mount)
    cat(sprintf(">>> out bucket path: %s\n", out.bucket.path))

    batch.str = if (batch.index > 0) paste0("B", batch.index, "_") else ""
    logging = paste0(out.bucket.path, "/.dsub/", batch.str, "L", ms.level, "_", job.key, ".log")

    # remove old log files
    # remove.bucket.path(paste0(out.bucket.path, "/.dsub/", ms.level, "_", name, "*"))
    
    # handle job keys
#    job.key.fn =      paste0(job.work.dir, "/.dsub/", batch.str, "keys_", "L", ms.level, "_", name)
    job.key.fn =      paste0(job.work.dir, "/.dsub/", batch.str, "L", ms.level, "_", name, ".keys")
    job.key.fn.uniq = paste0(job.work.dir, "/.dsub/", batch.str, "L", ms.level, "_", job.key, ".keys")
    
    job.key.bucket = path2bucket(path=job.key.fn, out.bucket=out.bucket, base.mount=base.mount)
    job.key.bucket.uniq = path2bucket(path=job.key.fn.uniq, out.bucket=out.bucket, base.mount=base.mount)
    
    cat(sprintf(">>> job-key table: %s\n", job.key.bucket))
    if (!dry) {
        if (file.exists(job.key.fn) && file.info(job.key.fn)$size > 0)
            remove.previous.tasks(job.key.fn=job.key.fn, project=project, provider=provider, ms.level=ms.level)
        system(paste("mkdir -p", paste0(job.work.dir, "/.dsub")))
        save.job.key.file(ofn=job.key.fn, ofn.bucket=job.key.bucket, job.keys)
        save.job.key.file(ofn=job.key.fn.uniq, ofn.bucket=job.key.bucket.uniq, job.keys)
    }

    command = paste("dsub",
                    "--enable-stackdriver-monitoring",
                    "--log-interval", log.interval,
                    "--boot-disk-size", machine.boot.gb,
                    "--disk-type", machine.disk.type,
                    "--disk-size", machine.disk.gb,
                    "--user makeshift-user",
                    paste0("--label 'ms-project-name=", project.name, "'", collapse="", sep=""),
                    paste0("--label 'ms-level=", ms.level+1, "'", collapse="", sep=""),
                    "--env", paste0("MS_LEVEL=", ms.level+1),
                    "--env", paste0("PAR_JOB_ID=", job.id),
                    "--env", paste0("PAR_NOTIFY_MAX_LEVEL=", max.report.level),
                    paste0("--label 'ms-job-id=", job.id, "'", collapse="", sep=""),
                    "--name", name,
                    "--env", paste0("GCP_PROJECT_ID=", project),
                    "--project",  project,
                    "--provider", provider,
                    "--regions", region,
                    "--image", image,
                    "--credentials-file", credentials.file,
                    "--logging", logging)

    # note: if emails are needed we can't use the private network
    if (use.private)
        command = paste(command, "--use-private-address")

    # email variables
    command  = paste(command, "--env", paste0("SENDGRID_API_KEY=", sendgrid.key))
    command  = paste(command, "--env", paste0("PAR_NOTIFY_EMAIL=", email))

    # append config
    cfg = Sys.getenv("c")
    command  = paste(command, "--env", paste0("c=", cfg))
    
#    if (ms.level >= 2)
#        command = paste(command, "--use-private-address")

    if (machine.spec.style == "defined") {
        command  = paste(command, "--machine-type", machine.type)
    } else if (machine.spec.style == "custom") {
        command  = paste(command, 
                         "--min-ram", machine.ram.gb,
                         "--min-cores", machine.cpu.count)
    } else {
        stop(cat(sprintf("unknown machine spec style: %s", machine.spec.style)))
    }
    
    if (wait)
        command  = paste(command, "--wait")

    # add job keys as labels (to allow deletion) and environment variables (to pass on to nested calls)
    for (ii in 1:ms.level) {
        command  = paste(command, sprintf("--label 'ms-job-key-%d=%s'", ii, job.keys[ii]))
        command  = paste(command,"--env", sprintf("MS_JOB_KEY_%d=%s", ii, job.keys[ii]))
    }

    if (preemtible.count > 0)
        command  = paste(command,
                         "--preemptible", preemtible.count,
                         "--retries", preemtible.count+non.preemtible.retry.count+1)
    if (preemtible.count == 0 && non.preemtible.retry.count > 0)
        command  = paste(command, "--retries", non.preemtible.retry.count)
    
    list(command=command, job.key.fn=job.key.fn, logging=logging, sendgrid.key=sendgrid.key)
}

format.email.message=function(ll)
{
    result = NULL
    for (i in 1:length(ll)) {
        result.i = sprintf("<b>%s</b>: %s<br>", gsub("_", " ", names(ll)[i]), ll[[i]])
        result = paste0(result, result.i)
    }
    result
}

verify.final.file=function(out.paths, job.key)
{
    rc = 0
    failed.paths = NULL
    max.attempts = 5
    sleep.time = "2m"
    for (i in 1:length(out.paths)) {
        fn = paste0(out.paths[i], "/.done_dsub_task")
        success.ii = F
        for (j in 1:max.attempts) {
            cmd = sprintf("gsutil cat %s", fn)
            rr = system(cmd, intern=T)
            if (length(rr) > 0) {
                if (rr == job.key) {
                    success.ii = T
                    # cat(sprintf(">>> job key verified: file: %s, key: %s\n", fn, job.key))
                } else {
                    cat(sprintf(">>> Error: file: %s, expected key: %s, found key: %s\n", fn, job.key, rr))
                }
                break
            }
            system(paste("sleep", sleep.time))
        }
        if (!success.ii) {
            failed.paths = c(failed.paths, out.paths[i])
            rc = -1
        }
    }
    if (length(failed.paths) > 0) {
        cat(sprintf(">>> Error: some tasks failed:\n%s\n", paste("-", failed.paths, collapse="\n")))
    }
    rc
}

dsub.run=function(command, dry, wait, project, provider, job.keys, ms.level, log.basedir, job.id, 
                  project.name, ms.type, ms.title, ms.desc, logging, email, max.report.level,
                  send.email.flag, sendgrid.key, out.paths)
{
    cat(paste0(">>> DSUB: running dsub command: \n", gsub("--", '\\\\\n\t--', command), "\n"))
    if (dry) stop("dry run")
    
    if (ms.level == 1) {
        cat(paste0("======================================================================================\n"))
        cat(sprintf(">>> Makeshift job instructions: \n"))
        cat(sprintf("The <run_key> associated with this run is %s\n", job.keys[1]))
        log.dir = paste0(log.basedir, "/runs/", job.keys[1])
        system(paste("mkdir -p", log.dir))
        log.fn = paste0(log.dir, "/run.info")
        write.table(x=logging, file=log.fn, quote=F, row.names=F, col.names=F)
        if (wait) {
            cat(sprintf("Waiting for job to finish. Hit Ctrl-C to terminate the job.\n"))
            cat(sprintf("Open a new terminal to run the following commands.\n"))
        }
        cat(sprintf("1. To delete job:\n%% make m=gcp ddel X=%s\n", job.keys[1]))
        cat(sprintf("2. To download logs (wait until done for complete logs):\n"))
        cat(sprintf("%% make m=gcp gcp_logs_download_key RUN_KEY=%s\n", job.keys[1]))
        cat(sprintf("3. To see status of all running jobs:\n"))
        cat(sprintf("%% make m=gcp dstat_s\n"))
        cat(paste0("======================================================================================\n"))
    }
    
    job.rc = system(command)
    cat(sprintf("dsub call return code: %d\n", job.rc))

    # verify the stamp file was created
    if (job.rc == 0 && wait) {
        job.rc = verify.final.file(out.paths=out.paths, job.key=job.keys[length(job.keys)])
    }
    
    if (job.rc != 0) {
        # remove entire subtree of current task with single delete command
        N = length(job.keys)
        delete.subtree.tasks(job.key=job.keys[N], project=project, provider=provider, ms.level=ms.level)
    }

    if (send.email.flag && email != "NONE" && sendgrid.key != "NONE") {
        if (wait && (job.rc != 0 || ms.level <= max.report.level)) {
            email.subject = sprintf("MS: %s/%d/%s: %s", job.id, ms.level, ms.title, if (job.rc == 0) "done" else "error")
            labels = paste0("<br>", 1:ms.level, ") ms-job-key-", 1:ms.level, "=", job.keys, collapse=" ")
            email.ll = list(Sender="Makeshift_pipeline_messenger", Project=project.name, Job_type=ms.type, Level=ms.level, Command=paste(ms.desc, collapse=" "), Return_code=job.rc, Logs=logging, Labels=labels)
            email.message = format.email.message(email.ll)
            
            # get logs
            fns = system(sprintf("gsutil -mq ls %s*.log", gsub(".log", "", logging)), intern=T)
            
            # do not send too many log files if successful 
            if (length(fns) > 100)
                fns = fns[1:100]
            
            system("rm -rf /tmp/ms_logs && mkdir -p /tmp/ms_logs")
            cat(sprintf("attaching to email log files: %s\n", paste(fns, collapse=" ")))
            attachments = NULL
            for (fn in fns) {
                tfn = paste0("/tmp/ms_logs/", basename(fn))
                exec(sprintf("gsutil -mq cat %s | grep -v 'INFO: gsutil -h Content-Type:text/plain' | grep -v 'Starting a garbage collection run' | grep -v 'Garbage collection succeeded after' > %s",
                             fn, tfn), ignore.error=T)
                if (file.info(tfn)$size > 0)
                    attachments = c(attachments, tfn)
            }
            if (length(fns) > 12) {
                exec(sprintf("tar cvf /tmp/ms_logs.tar -C /tmp/ms_logs ."))
                attachments = "/tmp/ms_logs.tar"
                
            }
            rc = 1
            count = 1
            while (rc && count <= 4) { 
                rc = send.email(sendgrid.key=sendgrid.key,
                                from.email=email,
                                to.email=email,
                                subject=email.subject,
                                message=email.message,
                                attachments=attachments)
                if (rc) {
                    system("sleep 30s")
                    count = count + 1
                    if (count == 4) attachments = NULL
                }
            }
        }
    }

    if (job.rc != 0)
        stop("dsub error")
    
    if (wait) {
        cat(sprintf(">>> DSUB: job ended successfully\n"))
    } else {
        cat(sprintf(">>> DSUB: job launched successfully\n"))
        if (send.email.flag && email != "NONE" && sendgrid.key != "NONE") {
            cat(sprintf(">>> DSUB: status emails will be sent to %s\n", email))
        }
    }
}

############################################################################################
# makeshift single command
############################################################################################

dsub.ms=function(job.work.dir,
                 module,
                 base.mount,
                 out.bucket,
                 out.var,
                 out.dir,
                 wdir,
                 provider="google-cls-v2",
                 project,
                 zones,
                 region,
                 image,
                 machine.spec.style,
                 machine.type,
                 machine.ram.gb,
                 machine.boot.gb,
                 machine.disk.type,
                 machine.disk.gb,
                 machine.cpu.count,
                 ms.root,
                 ms.cfg,
                 target,
                 name,
                 project.name,
                 preemtible.count=0,
                 non.preemtible.retry.count=0,
                 credentials.file=NULL,
                 mount.buckets,
                 mount.bucket.vars,
                 idir.vars,
                 idir.paths,
                 idir.buckets,
                 idir.basedirs,
                 dry,
                 wait,
                 log.basedir,
                 log.interval,
                 drop.params,
                 batch.index,
                 ms.level,
                 job.id,
                 download.intermediates,
                 upload.intermediates,
                 email,
                 max.report.level,
                 send.email.flag,
                 sendgrid.key,
                 params=NULL)
{
    job.keys = get.job.keys(ms.level=ms.level, name=name)
    pp = parse.params(params=params, drop.params=drop.params, module=module)
    params.str = pp$params

    out.path = path2bucket(path=out.dir, out.bucket=out.bucket, base.mount=base.mount)
    dbase = dsub.base(job.work.dir=job.work.dir,
                      base.mount=base.mount, 
                      out.bucket=out.bucket,
                      provider=provider,
                      project=project,
                      zones=zones,
                      region=region,
                      image=image,
                      machine.spec.style=machine.spec.style,
                      machine.type=machine.type,
                      machine.ram.gb=machine.ram.gb,
                      machine.boot.gb=machine.boot.gb,
                      machine.disk.type=machine.disk.type,
                      machine.disk.gb=machine.disk.gb,
                      machine.cpu.count=machine.cpu.count,
                      name=name,
                      project.name=project.name,
                      preemtible.count=preemtible.count,
                      non.preemtible.retry.count=non.preemtible.retry.count,
                      credentials.file=credentials.file,
                      dry=dry,
                      wait=wait,
                      log.interval=log.interval,
                      job.keys=job.keys,
                      job.id=job.id,
                      batch.index=0,
                      sendgrid.key=sendgrid.key,
                      max.report.level=max.report.level,
                      email=email,
                      ms.level=ms.level,
                      use.private=!send.email.flag)

    # skip if target requires no work
    test.command = paste("make -q", target, params.str)
    sm = should.make(wdir=wdir, test.command=test.command)
    if (!sm)
        return (NULL)

    make.command = ""
    if (download.intermediates)
        make.command = paste0("make m=gcp dsub_update_local && ")
    make.base = paste0("make ", target, " ", params.str)

    make.command = paste0(make.command, make.base)

    # check free space at end of command
    make.command = paste0(make.command)

    # add file with job key that is created after job is done
    make.command = paste0(make.command, " && ", create.final.stamp.command(job.keys=job.keys, out.var=out.var))

    command.start = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_start.sh ${", out.var, "}")
    command.end = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_end.sh ${", out.var, "}")
    
    ds = paste0("'", command.start, " && cd ${MAKESHIFT_ROOT}/", wdir, " ; echo \"Running commands: ", make.command, "\"; ", make.command, " && ", command.end, "'")
    command = paste(dbase$command,
                    "--command", ds,
                    "--input-recursive", paste0("MAKESHIFT_ROOT=", ms.root),
                    "--input-recursive", paste0("MAKESHIFT_CONFIG=", ms.cfg))

    # input dirs
    for (i in 1:length(idir.vars)) {
        if (is.na(idir.vars[i]) || idir.vars[i] == "NA")
            next
        obucket = path2bucket(path=idir.paths[i], out.bucket=idir.buckets[i], base.mount=idir.basedirs[i])
        command  = paste0(command,
                          " --input-recursive ", idir.vars[i], "=", obucket)
    }
    
    if (upload.intermediates)
        command = paste(command,
                    paste0("--env GCP_RSYNC_SRC_VAR=", out.var),
                    paste0("--env GCP_RSYNC_TARGET_BUCKET=", out.path))

    command  = paste0(command,
                     " --output-recursive ", out.var, "=", out.path)

    for (i in 1:length(mount.buckets))
        command  = paste0(command,
                          " --mount ", mount.bucket.vars[i], "=", mount.buckets[i])
    
    dsub.run(command=command, dry=dry, wait=wait, 
             project=project, provider=provider,
             job.keys=job.keys, ms.level=ms.level, log.basedir=log.basedir,
             project.name=project.name, max.report.level=max.report.level, job.id=job.id,
             ms.title=name, ms.type="single", ms.desc=make.base, logging=dbase$logging, email=email,
             send.email.flag=send.email.flag, sendgrid.key=sendgrid.key, out.paths=out.path)
}

############################################################################################
# makeshift tasks
############################################################################################

dsub.ms.tasks.batch=function(task.odir.vals, task.item.vals, batch.size, ...)
{
    if (length(task.odir.vals) != length(task.item.vals))
        stop("output dirs ('task.odir.vals') and input variables ('task.item.vals') must be same length")
    N = length(task.item.vals)
    if (N <= batch.size) {
        dsub.ms.tasks(task.odir.vals=task.odir.vals, task.item.vals=task.item.vals, batch.index=0, ...)
    } else {
        N.batches = ceiling(N / batch.size)
        ss = split(1:N, cut(1:10, N.batches))
        for (i in 1:length(ss)) {
            ii = ss[[i]]
            cat(sprintf(">>> processing batch %d/%d, number of tasks: %d\n", i, length(ss), length(ii)))
            dsub.ms.tasks(task.odir.vals=task.odir.vals[ii], task.item.vals=task.item.vals[ii], batch.index=i, ...)
        }
    }
}

dsub.ms.tasks=function(job.work.dir,
                       module,
                       base.mount,
                       out.bucket,
                       wdir,
                       provider="google-cls-v2",
                       project,
                       zones,
                       region,
                       image,
                       machine.spec.style,
                       machine.type,
                       machine.ram.gb,
                       machine.boot.gb,
                       machine.disk.type,
                       machine.disk.gb,
                       machine.cpu.count,
                       ms.root,
                       ms.cfg,
                       target,
                       name,
                       project.name,
                       preemtible.count=0,
                       non.preemtible.retry.count=0,
                       credentials.file=NULL,
                       mount.buckets,
                       mount.bucket.vars,
                       idir.vars,
                       idir.paths,
                       idir.buckets,
                       idir.basedirs,
                       task.odir.var,
                       task.odir.vals,
                       task.item.var,
                       task.item.vals,
                       dry,
                       wait,
                       log.basedir,
                       log.interval,
                       drop.params,
                       ms.level,
                       job.id,
                       batch.index,
                       download.intermediates,
                       upload.intermediates,
                       email,
                       max.report.level,
                       send.email.flag,
                       sendgrid.key,
                       params=NULL)
{
    job.keys = get.job.keys(ms.level=ms.level, name=name)
    pp = parse.params(params=params, drop.params=drop.params, module=module)
    params.str = pp$params
    
    dbase = dsub.base(job.work.dir=job.work.dir,
                      base.mount=base.mount, 
                      out.bucket=out.bucket,
                      provider=provider,
                      project=project,
                      zones=zones,
                      region=region,
                      image=image,
                      machine.spec.style=machine.spec.style,
                      machine.type=machine.type,
                      machine.ram.gb=machine.ram.gb,
                      machine.boot.gb=machine.boot.gb,
                      machine.disk.type=machine.disk.type,
                      machine.disk.gb=machine.disk.gb,
                      machine.cpu.count=machine.cpu.count,
                      name=name,
                      project.name=project.name,
                      preemtible.count=preemtible.count,
                      non.preemtible.retry.count=non.preemtible.retry.count,
                      credentials.file=credentials.file,
                      dry=dry,
                      wait=wait,
                      log.interval=log.interval,
                      job.keys=job.keys,
                      job.id=job.id,
                      batch.index=batch.index,
                      email=email,
                      sendgrid.key=sendgrid.key,
                      max.report.level=max.report.level,
                      ms.level=ms.level,
                      use.private=!send.email.flag)

    ############################################################################################
    # skip if target requires no work
    ############################################################################################

    # if over 10 tasks skip testing here and launch jobs
    check.targets = length(task.item.vals) <= 10
    if (check.targets) { 
        indices = NULL
        for (i in 1:length(task.item.vals)) {
            test.command = sprintf("make -q %s=%s %s %s", task.item.var, task.item.vals[i], target, params.str)
            sm = should.make(wdir=wdir, test.command=test.command)
        if (sm)
            indices = c(indices, i)
        }
        if (length(indices) == 0) {
            cat(">>> DSUB: all targets exists, returning\n")
            return (NULL)
        }
    } else {
        indices = 1:length(task.item.vals)
    }
   
    ############################################################################################
    # prep task file
    ############################################################################################

    task.wdir = paste0(job.work.dir, "/tasks_", name)
    if (system(paste("mkdir -p", task.wdir)) != 0)
        stop("cannot create task directory")
    tfile = paste0(task.wdir, "/task_table.tsv")
    cat(sprintf(">>> creating task tsv file: %s\n", tfile))

    if (length(task.odir.vals) != length(task.item.vals))
        stop("output dirs ('task.odir.vals') and input variables ('task.item.vals') must be same length")
    
    # header
    hline = sprintf("--env %s\t--output-recursive %s", task.item.var, task.odir.var)
    if (download.intermediates)
        hline = paste0(hline, "\t--env GCP_RSYNC_SRC_VAR\t--env GCP_RSYNC_TARGET_BUCKET")
    lines = hline

    out.paths = NULL
    for (i in indices) {
        opath = path2bucket(path=task.odir.vals[i], out.bucket=out.bucket, base.mount=base.mount)
        out.paths = c(out.paths, opath)
        cat(sprintf(">>> task out bucket path %d: %s\n", i, opath))
        vline = sprintf("%s\t%s", task.item.vals[i], opath)
        if (download.intermediates)
            vline = paste0(vline, sprintf("\t%s\t%s", task.odir.var, opath))
        lines = c(lines, vline)
    }
    fc = file(tfile)
    writeLines(lines, fc)
    close(fc)
    
    ############################################################################################

    task.params = paste0(task.item.var, "=", "${", task.item.var, "}")

    make.command = ""
    if (download.intermediates)
        make.command = paste0("make m=gcp dsub_update_local && ")
    make.base = paste0("make ", target, " ", task.params, " ", params.str)
    make.command = paste0(make.command, make.base)

    # check free space at end of command
    make.command = paste0(make.command)

    # add file with job key that is created after job is done
    make.command = paste0(make.command, " && ", create.final.stamp.command(job.keys=job.keys, out.var=task.odir.var))

    command.start = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_start.sh ${", task.odir.var, "}")
    command.end = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_end.sh ${", task.odir.var, "}")
    
    ds = paste0("'", command.start, " && cd ${MAKESHIFT_ROOT}/", wdir, " ; echo \"Running commands: ",
                make.command, "\"; ", make.command, " && ", command.end, "'")
    command = paste(dbase$command,
                    "--input-recursive", paste0("MAKESHIFT_ROOT=", ms.root),
                    "--input-recursive", paste0("MAKESHIFT_CONFIG=", ms.cfg),
                    "--command", ds,
                    "--tasks", tfile)

    # input dirs
    for (i in 1:length(idir.vars)) {
        if (is.na(idir.vars[i]) || idir.vars[i] == "NA")
            next
        obucket = path2bucket(path=idir.paths[i], out.bucket=idir.buckets[i], base.mount=idir.basedirs[i])
        command  = paste0(command,
                          " --input-recursive ", idir.vars[i], "=", obucket)
    }
    
    for (i in 1:length(mount.buckets))
        command  = paste0(command,
                          " --mount ", mount.bucket.vars[i], "=", mount.buckets[i])

    dsub.run(command=command, dry=dry, wait=wait,
             project=project, provider=provider,
             job.keys=job.keys, ms.level=ms.level, log.basedir=log.basedir,
             project.name=project.name, max.report.level=max.report.level, job.id=job.id,
             ms.title=name, ms.type="tasks_simple", ms.desc=make.base, logging=dbase$logging, email=email,
             send.email.flag=send.email.flag, sendgrid.key=sendgrid.key, out.paths=out.paths)
}

############################################################################################
# makeshift tasks from table
############################################################################################

dsub.ms.complex.batch=function(task.input.table, task.odir.vals, batch.size, ...)
{
    df.tasks = load.table(task.input.table)

    N = dim(df.tasks)[1]
    if (N <= batch.size) {
        dsub.ms.complex(df.tasks=df.tasks, task.odir.vals=task.odir.vals, batch.index=0, ...)
    } else {
        N.batches = ceiling(N / batch.size)
        ss = split(1:N, cut(1:10, N.batches))
        for (i in 1:length(ss)) {
            ii = ss[[i]]
            cat(sprintf(">>> processing batch %d/%d, number of tasks: %d\n", i, length(ss), length(ii)))
            dsub.ms.complex(df.tasks=df.tasks[ii,], task.odir.vals=task.odir.vals[ii], batch.index=i, ...)
        }
    }
}

dsub.ms.complex=function(job.work.dir,
                         module,
                         base.mount,
                         out.bucket,
                         wdir,
                         provider="google-cls-v2",
                         project,
                         zones,
                         region,
                         image,
                         machine.spec.style,
                         machine.type,
                         machine.ram.gb,
                         machine.boot.gb,
                         machine.disk.type,
                         machine.disk.gb,
                         machine.cpu.count,
                         ms.root,
                         ms.cfg,
                         target,
                         name,
                         project.name,
                         preemtible.count=0,
                         non.preemtible.retry.count=0,
                         credentials.file=NULL,
                         mount.buckets,
                         mount.bucket.vars,
                         idir.vars,
                         idir.paths,
                         idir.buckets,
                         idir.basedirs,
                         df.tasks,
                         task.item.var,
                         task.odir.var,
                         task.odir.vals,
                         dry,
                         wait,
                         log.basedir,
                         log.interval,
                         drop.params,
                         ms.level,
                         job.id,
                         batch.index,
                         download.intermediates,
                         upload.intermediates,
                         email,
                         max.report.level,
                         send.email.flag,
                         sendgrid.key,
                         params=NULL)
{
    job.keys = get.job.keys(ms.level=ms.level, name=name)
    pp = parse.params(params=params, drop.params=drop.params, module=module)
    params.str = pp$params
    
    dbase = dsub.base(job.work.dir=job.work.dir,
                      base.mount=base.mount, 
                      out.bucket=out.bucket,
                      provider=provider,
                      project=project,
                      zones=zones,
                      region=region,
                      image=image,
                      machine.spec.style=machine.spec.style,
                      machine.type=machine.type,
                      machine.ram.gb=machine.ram.gb,
                      machine.boot.gb=machine.boot.gb,
                      machine.disk.type=machine.disk.type,
                      machine.disk.gb=machine.disk.gb,
                      machine.cpu.count=machine.cpu.count,
                      name=name,
                      project.name=project.name,
                      preemtible.count=preemtible.count,
                      non.preemtible.retry.count=non.preemtible.retry.count,
                      credentials.file=credentials.file,
                      dry=dry,
                      wait=wait,
                      log.interval=log.interval,
                      job.keys=job.keys,
                      job.id=job.id,
                      batch.index=batch.index,
                      email=email,
                      sendgrid.key=sendgrid.key,
                      max.report.level=max.report.level,
                      ms.level=ms.level,
                      use.private=!send.email.flag)
        
    ############################################################################################
    # skip if target requires no work
    ############################################################################################

    # if over 10 tasks skip testing here and launch jobs
    check.targets = dim(df.tasks)[1] <= 10
    if (check.targets) { 
        indices = NULL
        for (i in 1:dim(df.tasks)[1]) {
            test.command = sprintf("make -q %s %s %s", target, params.str,
                                   paste(colnames(df.tasks), df.tasks[i,], sep="=", collapse=" "))
            sm = should.make(wdir=wdir, test.command=test.command)
            if (sm)
                indices = c(indices, i)
        }
        if (length(indices) == 0) {
            cat(">>> DSUB: all targets exists, returning\n")
            return (NULL)
        }
    } else {
        indices = 1:dim(df.tasks)[1]
    }
    
    ############################################################################################
    # prep task file
    ############################################################################################

    task.wdir = paste0(job.work.dir, "/tasks_", name)
    if (system(paste("mkdir -p", task.wdir)) != 0)
        stop("cannot create task directory")
    tfile = paste0(task.wdir, "/tasks.tsv")
    cat(sprintf(">>> creating task tsv file: %s\n", tfile))
    lines = NULL

    # header
    hline = sprintf("--output-recursive %s\t", task.odir.var)
    if (download.intermediates)
        hline = paste0(hline, "--env GCP_RSYNC_SRC_VAR\t--env GCP_RSYNC_TARGET_BUCKET\t")
    hline = paste0(hline, paste0("--env", " ", colnames(df.tasks), sep="", collapse="\t"))
    lines = c(hline)

    out.paths = NULL
    for (i in indices) {
        opath = path2bucket(path=task.odir.vals[i], out.bucket=out.bucket, base.mount=base.mount)
        out.paths = c(out.paths, opath)
        cat(sprintf(">>> task out bucket %d path: %s\n", i, opath))
        vline = sprintf("%s\t", opath)
        if (download.intermediates)
            vline = paste0(vline, sprintf("%s\t%s\t",task.odir.var, opath))
        vline = paste0(vline, paste(df.tasks[i,], collapse="\t"))
        lines = c(lines, vline)
    }
    fc = file(tfile)
    writeLines(lines, fc)
    close(fc)
    
    ############################################################################################

    task.params = paste(colnames(df.tasks), "=", "${", colnames(df.tasks), "}", sep="", collapse=" ")

    make.command = ""
    if (download.intermediates)
        make.command = paste0("make m=gcp dsub_update_local && ")
    make.base = paste0("make ", target, " ", task.params, " ", params.str)
    make.command = paste0(make.command, make.base)

    # check free space at end of command
    make.command = paste0(make.command)
    
    # add file with job key that is created after job is done
    make.command = paste0(make.command, " && ", create.final.stamp.command(job.keys=job.keys, out.var=task.odir.var))

    command.start = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_start.sh ${", task.odir.var, "}")
    command.end = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_end.sh ${", task.odir.var, "}")
    
    ds = paste0("'", command.start, " && cd ${MAKESHIFT_ROOT}/", wdir, " ; echo \"Running commands: ",
                make.command, "\"; ", make.command, " && ", command.end, "'")
    command = paste(dbase$command,
                    "--input-recursive", paste0("MAKESHIFT_ROOT=", ms.root),
                    "--input-recursive", paste0("MAKESHIFT_CONFIG=", ms.cfg),
                    "--command", ds,
                    "--tasks", tfile)

    # input dirs
    for (i in 1:length(idir.vars)) {
        if (is.na(idir.vars[i]) || idir.vars[i] == "NA")
            next
        obucket = path2bucket(path=idir.paths[i], out.bucket=idir.buckets[i], base.mount=idir.basedirs[i])
        command  = paste0(command,
                          " --input-recursive ", idir.vars[i], "=", obucket)
    }
    
    for (i in 1:length(mount.buckets))
        command  = paste0(command,
                          " --mount ", mount.bucket.vars[i], "=", mount.buckets[i])

    dsub.run(command=command, dry=dry, wait=wait,
             project=project, provider=provider,
             job.keys=job.keys, ms.level=ms.level, log.basedir=log.basedir,
             project.name=project.name, max.report.level=max.report.level, job.id=job.id,
             ms.title=name, ms.type="tasks_complex", ms.desc=make.base, logging=dbase$logging, email=email,
             send.email.flag=send.email.flag, sendgrid.key=sendgrid.key, out.paths=out.paths)
             
}

############################################################################################
# direct command
############################################################################################

dsub.direct=function(job.work.dir,
                     out.bucket,
                     base.mount,
                     provider,
                     project,
                     zones,
                     region,
                     image,
                     ms.cfg,
                     machine.spec.style,
                     machine.type,
                     machine.ram.gb,
                     machine.boot.gb,
                     machine.disk.type,
                     machine.disk.gb,
                     machine.cpu.count,
                     name,
                     project.name,
                     preemtible.count=0,
                     non.preemtible.retry.count=0,
                     credentials.file=NULL,
                     ifn.vars,
                     ofn.vars,
                     odir.vars,
                     ifn.paths,
                     ofn.paths,
                     idir.vars,
                     idir.paths,
                     idir.buckets,
                     idir.basedirs,
                     odir.paths,
                     odir.var,
                     out.dir,
                     command,
                     dry,
                     wait,
                     log.basedir,
                     log.interval,
                     params,
                     ms.level,
                     ms.root,
                     job.id,
                     email,
                     max.report.level,
                     send.email.flag,
                     sendgrid.key,
                     save.job.stats,
                     drop.params)
{
    job.keys = get.job.keys(ms.level=ms.level, name=name)
    pp = parse.params(params=params, drop.params=drop.params)
    params.str = pp$params

    out.path = path2bucket(path=out.dir, out.bucket=out.bucket, base.mount=base.mount)
    out.file = paste0(out.path, "/.done_dsub_task")
    
    # note: can't use private network because image is not on GCR
    dbase = dsub.base(job.work.dir=job.work.dir,
                      base.mount=base.mount, 
                      out.bucket=out.bucket,
                      provider=provider,
                      project=project,
                      zones=zones,
                      region=region,
                      image=image,
                      machine.spec.style=machine.spec.style,
                      machine.type=machine.type,
                      machine.ram.gb=machine.ram.gb,
                      machine.boot.gb=machine.boot.gb,
                      machine.disk.type=machine.disk.type,
                      machine.disk.gb=machine.disk.gb,
                      machine.cpu.count=machine.cpu.count,
                      name=name,
                      project.name=project.name,
                      preemtible.count=preemtible.count,
                      non.preemtible.retry.count=non.preemtible.retry.count,
                      credentials.file=credentials.file,
                      dry=dry,
                      wait=wait,
                      log.interval=log.interval,
                      job.keys=job.keys,
                      job.id=job.id,
                      batch.index=0,
                      email=email,
                      sendgrid.key=sendgrid.key,
                      max.report.level=max.report.level,
                      ms.level=ms.level,
                      use.private=F)
    
    command = paste0(gsub("~", "=", command), collapse=" ")

    # add file with job key that is created after job is done
    command = paste0(command, " && ", create.final.stamp.command(job.keys=job.keys, out.var="GCP_DSUB_DONE_FILE", is.dir=F))

    cat(sprintf("container command: %s\n", paste0(command)))

    if (save.job.stats) {
        command.start = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_start.sh ${", odir.var, "}")
        command.end = paste0("bash ${MAKESHIFT_ROOT}/makeshift-core/job_end.sh ${", odir.var, "}")
        
        dsub.command = paste(dbase$command,
                             "--command", paste0("'", command.start, " && ", command, " && ", command.end, "'"),
                             paste0("--output GCP_DSUB_DONE_FILE=", out.file))
    } else {
        dsub.command = paste(dbase$command,
                             "--command", paste0("'", command, "'"),
                             paste0("--output GCP_DSUB_DONE_FILE=", out.file))
    }
    
    # input files
    if (all(ifn.vars != "NA")) {
        for (i in 1:length(ifn.vars)) {
            obucket = path2bucket(path=ifn.paths[i], out.bucket=out.bucket, base.mount=base.mount)
            dsub.command  = paste0(dsub.command,
                                   " --input ", ifn.vars[i], "=", obucket)
        }
    }

    # input dirs
    for (i in 1:length(idir.vars)) {
        if (is.na(idir.vars[i]) || idir.vars[i] == "NA")
            next
        obucket = path2bucket(path=idir.paths[i], out.bucket=idir.buckets[i], base.mount=idir.basedirs[i])
        dsub.command  = paste0(dsub.command,
                               " --input-recursive ", idir.vars[i], "=", obucket)
    }
    
    for (i in 1:length(ofn.vars)) {
        if (is.na(ofn.paths[i]) || ofn.paths[i] == "NA")
            next
        obucket = path2bucket(path=ofn.paths[i], out.bucket=out.bucket, base.mount=base.mount)
        dsub.command  = paste0(dsub.command,
                               " --output ", ofn.vars[i], "=", obucket)
    }
    for (i in 1:length(odir.vars)) {
        if (is.na(odir.paths[i]) || odir.paths[i] == "NA")
            next
        obucket = path2bucket(path=odir.paths[i], out.bucket=out.bucket, base.mount=base.mount)
        dsub.command  = paste0(dsub.command,
                               " --output-recursive ", odir.vars[i], "=", obucket)
    }
    dsub.command  = paste0(dsub.command,
                           " --output-recursive ", odir.var, "=", out.path)

    dsub.command  = paste0(dsub.command,
                           " --input-recursive ", paste0("MAKESHIFT_ROOT=", ms.root))
    
    dsub.run(command=dsub.command, dry=dry, wait=wait, 
             project=project, provider=provider,
             job.keys=job.keys, ms.level=ms.level, log.basedir=log.basedir,
             project.name=project.name, max.report.level=max.report.level, job.id=job.id,
             ms.title=name, ms.type="direct", ms.desc=command, logging=dbase$logging, email=email,
             send.email.flag=send.email.flag, sendgrid.key=sendgrid.key, out.paths=out.path)
}
