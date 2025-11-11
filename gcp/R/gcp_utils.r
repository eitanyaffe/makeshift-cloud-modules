
path2bucket=function(path, out.bucket, base.mount)
{
    if (grepl(base.mount, path)) {
        return (gsub(base.mount, out.bucket, path))
    } else {
        return (gsub("gs/", "gs://", gsub("/mnt/data/output/", "", path)))
    }
}

###############################################################################################
# remove
###############################################################################################

remove.paths=function(base.mount, out.bucket, paths)
{
    for (path in paths) {
        pp = path2bucket(path=path, out.bucket=out.bucket, base.mount=base.mount)

        if (system(paste("gsutil ls", pp), ignore.stdout=T, ignore.stderr=T) == 0) {
            cat(sprintf("removing bucket path: %s\n", pp))
            system(paste("sleep 1s"))
            system(paste("gsutil -mq rm -rf", pp))
        }
        
    }
}

remove.find=function(base.mount, out.bucket, base.dir, name.pattern)
{
    cmd = sprintf("find %s -name '%s'", base.dir, name.pattern)
    cat(sprintf("running command: %s\n", cmd))
    paths = system(cmd, intern=T)
    if (is.null(paths) || (length(paths) == 0))
        return (NULL)
    for (path in paths) {
        pp = path2bucket(path=path, out.bucket=out.bucket, base.mount=base.mount)
        if (system(paste("gsutil ls", pp), ignore.stdout=T, ignore.stderr=T) == 0) {
            cat(sprintf("removing bucket path: %s\n", pp))
            system(paste("sleep 1s"))
            system(paste("gsutil -mq rm -rf", pp))
        }
        
    }
}


###############################################################################################
# compress
###############################################################################################

compress.find=function(base.mount, out.bucket, base.dir, name.pattern)
{
    cmd = sprintf("find %s -name '%s'", base.dir, name.pattern)
    cat(sprintf("running command: %s\n", cmd))
    paths = system(cmd, intern=T)
    if (is.null(paths) || (length(paths) == 0))
        return (NULL)
    for (path in paths) {
        pp = path2bucket(path=path, out.bucket=out.bucket, base.mount=base.mount)
        if (system(paste("gsutil ls", pp), ignore.stdout=T, ignore.stderr=T) == 0) {
            # cat(sprintf("compressing %s\n", pp))
            # system(sprintf("pigz -p 8 -c %s > /tmp/x.gz", path))
            # system(sprintf("gsutil -mq cp /tmp/x.gz %s.gz", pp))
            cat(sprintf("handling %s\n", pp))
            system(sprintf("gsutil -mq cp %s.gz %s", pp, pp))
            system(sprintf("gsutil -mq rm %s.gz", pp))
        }
    }
}

###############################################################################################
# copy from bucket
###############################################################################################

copy.from.bucket=function(base.mount, out.bucket, source.path, dest.path)
{
    source.bucket = path2bucket(path=source.path, out.bucket=out.bucket, base.mount=base.mount)
    cmd = sprintf("gsutil cp %s %s", source.bucket, dest.path)
    cat(sprintf("running: %s\n", cmd))
    system(cmd)
}
