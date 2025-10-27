
pck <- c("stringr", "stringi", "plyr", "seqinr", "stats", "parallel", "doParallel",
         "beepr", "stats4", "devtools", "dplyr", "BiocManager", "tibble")

foo <- function(x){
  for( i in x ){
    if( ! require( i , character.only = TRUE ) ){
      install.packages( i , dependencies = TRUE )
      require( i , character.only = TRUE )
    }
  }
}
foo(pck)
BiocManager::install(c("BiocGenerics", "S4Vectors", "Biostrings", "biomartr", "IRanges") ,
                     ask = FALSE, update = TRUE)

devtools::install_github("EfresBR/G4iMGrinder")
