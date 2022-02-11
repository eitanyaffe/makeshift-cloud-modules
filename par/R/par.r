parse.params=function(params, drop.params, module)
{    
    params = gsub("~", "=", params)
    param.names = sapply(params, function(x) {
        xx = strsplit(x, "=")[[1]]
        if (length(xx) > 1)
            return (xx[1])
        else
            return (NA)
    })
    params = params[is.na(param.names) | !is.element(param.names, drop.params)]
    sprintf("%s %s", paste(params, collapse=" "), paste0("m=", module))
}

par.ms.complex=function(task.input.table, target, dry, module, params, drop.params)
{
    params.str = parse.params(params=params, drop.params=drop.params, module=module)
    df = load.table(task.input.table)
    for (i in 1:dim(df)[1]) {
        command = sprintf("make %s %s %s", target, params.str,
                          paste(colnames(df), df[i,], sep="=", collapse=" "))
        if (dry)
            command = paste(command, "-n")
        cat(sprintf("running command: %s\n", command))
        if (system(command) != 0)
            stop("error in command")
    }
    if (dry)
        stop("dry run")
}
