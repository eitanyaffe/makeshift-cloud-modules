path2bucket=function(path, out.bucket, base.mount)
{
    if (grepl(base.mount, path)) {
        return (gsub(base.mount, out.bucket, path))
    } else {
        return (gsub("gs/", "gs://", gsub("/mnt/data/output/", "", path)))
    }
}

remove.paths=function(base.mount, out.bucket, paths)
{
    for (path in paths) {
        pp = path2bucket(path=path, out.bucket=out.bucket, base.mount=base.mount)

        if (system(paste("gsutil ls", pp), ignore.stdout=T, ignore.stderr=T) == 0) {
            cat(sprintf("removing bucket path: %s\n", pp))
            system(paste("gsutil -mq rm -rf", pp))
        }
        
    }
}

remove.find=function(base.mount, out.bucket, base.dir, name.pattern)
{
    paths = system(sprintf("find %s -name '%s'", base.dir, name.pattern), intern=T)
    if (is.null(paths) || (length(paths) == 0))
        return (NULL)
    for (path in paths) {
        pp = path2bucket(path=path, out.bucket=out.bucket, base.mount=base.mount)
        if (system(paste("gsutil ls", pp), ignore.stdout=T, ignore.stderr=T) == 0) {
            cat(sprintf("removing bucket path: %s\n", pp))
            system(paste("gsutil -mq rm -rf", pp))
        }
        
    }
}
