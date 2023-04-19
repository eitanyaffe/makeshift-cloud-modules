

get.bucket.paths=function(path, depth, project)
{
    if (depth == 0)
        return (path)
    command = paste("gsutil ls -p", project, path)
    children = system(command, intern=T)
    children = children[grepl("/$", children)]
    rr = NULL
    for (child in children) {
        rr = c(rr, get.bucket.paths(path=child, depth=depth-1, project=project))
    }
    gsub('/$', '', sort(unique(rr)))
}

du=function(ifn, project, check.all)
{
    df = load.table(ifn)
    if (check.all) {
        command = paste("gsutil ls -p", project)
        buckets.all = gsub('/$', '',  system(command, intern=T))
    } else {
        buckets.all = NULL
    }
    # buckets = c(df$bucket, setdiff(buckets.all, df$bucket))
    buckets = c(setdiff(buckets.all, df$bucket), df$bucket)
    
    cat(sprintf("minimal size of reported item: 1 GiB\n"))
    cat(sprintf("traversing buckets:\n%s\n", paste("-", buckets, collapse="\n")))
    
    for (bucket in buckets) {
        if (is.element(bucket, df$bucket)) {
            depth = df$depth[match(bucket, df$bucket)]
            paths = get.bucket.paths(path=bucket, depth=depth, project=project)
        } else {
            paths = bucket
        }
        tryCatch(
            exec(paste("gsutil -mq du -hs ", paste(paths, collapse=" "), " | grep 'TiB\\|GiB'"),
                 ignore.error=F, verbose=F),
            interrupt = function(err) {
                message("interrupted")
                exit(1)
            } )
    }
}

path.usage=function(paths, unit) {
    ll = system(paste("gsutil -mq du -s ", paste(paths, collapse=" ")), intern=T)
    ss = sapply(ll, function(x)  { as.numeric(strsplit(x, "\\s+")[[1]][1]) })
    rr = switch(unit, KiB=10^3, MiB=10^6, GiB=10^9, TiB=10^12, stop("unknown unit"))
    sum(ss) / rr
}

du.bucket=function(bucket, depth, unit, project)
{
    paths = get.bucket.paths(path=bucket, depth=depth, project=project)
    cat(sprintf("traversing buckets (depth=%d):\n%s\n", depth, paste(paths, collapse="\n")))

    
    # cat(sprintf("computing total space for project: %s ...\n", project))
    # command = paste("gsutil ls -p", project)
    # all.paths = gsub('/$', '',  system(command, intern=T))
    # tot = path.usage(paths=all.paths, unit=unit)
    # tot = 75
    # cat(sprintf("total project space: %.1f %s\n", tot, unit))
    
    cat(sprintf("results:\n"))
    for (path in paths) {
        usage.i = path.usage(paths=path, unit=unit)
        cat(sprintf("%s: %.1f %s\n", path, usage.i, unit))
        # pct.i = 100 * usage.i / tot
        # cat(sprintf("%s: %.1f %s (%.1f%%)\n", path, usage.i, unit, pct.i))
    }
}

total.project.usage=function(project, unit)
{
    command = paste("gsutil ls -p", project)
    paths = gsub('/$', '',  system(command, intern=T))
    cat(sprintf("traversing all project buckets:\n%s\n", paste(paths, collapse="\n")))
    
    tt = path.usage(paths=paths, unit=unit)
    cat(sprintf("total project space: %.1f %s\n", tt, unit))
}
