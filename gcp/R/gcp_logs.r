resolve.log.paths=function(log.path)
{
    x = gsub(".log$", "", log.path)
    command = sprintf("gsutil ls %s*.log", x)

    defaultW = getOption("warn")
    options(warn = -1)
    rr = system(command, intern=T, ignore.stderr=T)
    options(warn = defaultW)
    
    if (!is.null(attr(rr,"status")) && attr(rr,"status") != 0) {
        if (attr(rr,"status") == 130) exit(1)
        return (NULL)
    }
    ix = !grepl("stderr", rr) & !grepl("stdout", rr) 
    if (any(ix)) {
        return (rr[ix])
    } else {
        return (NULL)
    }
}

get.sub.logs=function(log.path)
{
    command = sprintf("gsutil cat %s | grep '\\-\\-logging'", log.path)

    defaultW = getOption("warn")
    options(warn = -1)
    rr = system(command, intern=T, ignore.stderr=T)
    options(warn = defaultW)
    
    if (!is.null(attr(rr,"status")) && attr(rr,"status") != 0) {
        if (attr(rr,"status") == 130) exit(1)
        return (NULL)
    }

    rr = gsub(" \\\\", "", gsub("\t--logging ", "", rr))
    rr
}

localize.log=function(fn, out.bucket, odir)
{
    ofn = gsub(out.bucket, odir, fn)
    command = sprintf("gsutil -q cp %s %s", fn, ofn)
    rc = system(command)
    if (rc == 130) exit(1)
    if (rc != 0)
        cat(sprintf("warning: error downloading log file: %s", fn))
}

download.log=function(log.path, recursive, out.bucket, level.i, odir)
{
    fns = resolve.log.paths(log.path=log.path)
    count = length(fns)
    for (fn in fns) {
        cat(sprintf("%s> downloading %s ...\n", paste(rep("-", level.i), collapse=""), fn))
        localize.log(fn=fn, out.bucket=out.bucket, odir=odir)
        if (recursive) {
            sub.log.paths = get.sub.logs(fn)
            if (is.null(sub.log.paths) || length(sub.log.paths) == 0) {
                next
            }
            # cat(sprintf("number of nested log files found: %d\n", length(sub.log.paths)))
            for (sub.log.path in sub.log.paths) {
                x = download.log(log.path=sub.log.path, recursive=recursive, out.bucket=out.bucket,
                                 level.i=level.i+1, odir=odir)
                count = count + x
            }
            
        }
    }
    return (count)
}

#########################################################################################################
# download using explicit log path
#########################################################################################################

download.log.root=function(log.path, recursive, out.bucket, odir)
{
    cat(sprintf("root log file: %s\n", log.path))
    cat(sprintf("downloading to directory: %s\n", odir))
    cc = download.log(log.path=log.path, recursive=recursive, out.bucket=out.bucket, level.i=0, odir=odir)
    cat(sprintf("total number of log files located: %d\n", cc))
    cat(sprintf("done saving files to directory: %s\n", odir))
}

#########################################################################################################
# download using run key
#########################################################################################################

download.log.by.key=function(ifn, recursive, out.bucket, odir)
{
    log.path = read.delim(ifn, header=F)
    download.log.root(log.path=log.path, recursive=recursive, out.bucket=out.bucket, odir=odir)
}
