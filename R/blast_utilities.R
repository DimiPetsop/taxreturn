
# .findExecutable ---------------------------------------------------------


#' Find executable
#'
#' @param exe
#' @param interactive
#'
#' @return
#' @export
#'
#' @examples
.findExecutable <- function(exe, interactive=TRUE) {
  path <- Sys.which(exe)
  if(all(path=="")) {
    if(interactive) stop("Executable for ", paste(exe, collapse=" or "), " not found! Please make sure that the software is correctly installed and, if necessary, path variables are set.", call.=FALSE)
    return(character(0))
  }

  path[which(path!="")[1]]
}


# Install BLAST -----------------------------------------------------------

#' Install BLAST
#'
#' @param url (Optional) Default will search for the latest version
#' URL to retrieve BLAST version from.
#' @param dest.dir (Optional)  Default "bin"
#' Directory to install BLAST within.
#' @force Whether existing installs should be forcefully overwritten
#'
#' @return
#' @export
#' @import stringr
#' @import RCurl
#' @import utils
#' @import httr
#'
#' @examples
blast_install <- function(url, dest.dir = "bin", force = FALSE) {

  # get start time
  time <- Sys.time()
  # get OS
  localos <- Sys.info()["sysname"]

  if (missing(url)) {
    # find the latest version of BLAST
    url <- 'ftp://ftp.ncbi.nlm.nih.gov/blast/executables/LATEST/'
    filenames <- RCurl::getURL(url, ftp.use.epsv = FALSE, dirlistonly = TRUE) %>%
      stringr::str_split("\r*\n") %>%
      unlist()

    if(localos == "Windows"){
    url <- filenames[stringr::str_detect(filenames,"win64.tar.gz$")] %>%
      paste0(url,.)
    } else if(localos == "Darwin"){
      url <- filenames[stringr::str_detect(filenames,"macosx.tar.gz$")] %>%
        paste0(url,.)
    } else if(localos == "unix"){
      url <- filenames[stringr::str_detect(filenames,"linux.tar.gz$")] %>%
        paste0(url,.)
    }

  }

  if (!dir.exists(dest.dir)) {
    dir.create(dest.dir) # Create first directory
  }

  blast_version <- basename(url) %>% stringr::str_replace("(-x64)(.*?)(?=$)", "")
  if (dir.exists(paste0(dest.dir, "/", blast_version)) && force == FALSE) {
    message("Skipped as BLAST already exists in directory, to overwrite set force to TRUE")
    return(NULL)
  } else  if (dir.exists(paste0(dest.dir, "/", blast_version)) && force == TRUE) {
    unlink(paste0(dest.dir, "/", blast_version), recursive = TRUE) # Remove old version
  }

  destfile <- file.path(dest.dir, basename(url))
  if (exists(destfile)) {
    file.remove(destfile) # Remove old zip file
  }

  #Download and unzip
  httr::GET(url, httr::write_disk(destfile, overwrite=TRUE))
  utils::untar(destfile, exdir = dest.dir)
  file.remove(destfile)

  #Set new $Paths variable for mac & linux
  if(localos == "Darwin" | localos == "unix"){
    old_path <- Sys.getenv("PATH")
    install_path <- list.dirs(dest.dir, full.names = TRUE)[str_detect(list.dirs(dest.dir, full.names = TRUE),"/bin$")]
    Sys.setenv(PATH = paste(old_path, normalizePath(install_path), sep = ":"))
  }

  time <- Sys.time() - time
  message(paste0("Downloaded ", blast_version, " in ", format(time, digits = 2)))
}


# Make Blast DB -----------------------------------------------------------

#' Make blast Database
#'
#' @param file (Required) A fasta file to create a database from.
#' @param dbtype (Optional) Molecule type of database, accepts "nucl" for nucleotide or "prot" for protein.
#' @param args (Optional) Extra arguments passed to BLAST
#'
#' @return
#' @export
#' @import R.utils
#' @import stringr
#'
#' @examples
makeblastdb <- function (file, dbtype = "nucl", args = NULL, quiet = FALSE) {
  time <- Sys.time() # get time
  .findExecutable("makeblastdb") # Check blast is installed
  if (is.null(args)){args <- ""}
  if (stringr::str_detect(file, ".gz")) {
    message("Unzipping file")
    compressed <- TRUE
    R.utils::gunzip(file, remove=FALSE)
    file <- stringr::str_replace(file, ".gz", "")
  }else (compressed <- FALSE)
  results <- system2(command = .findExecutable("makeblastdb"),
                     args = c("-in", file, "-dbtype", dbtype, args),
                     wait = TRUE,
                     stdout = TRUE)
  time <- Sys.time() - time
  if (compressed) {file.remove(file)}
  if (!quiet) (message(paste0("made BLAST DB in ", format(time, digits = 2))))

}


#' Show BLAST parameters
#'
#' @param type (Required) Which BLAST function to display help page for
#'
#' @return
#' @export
#'
#' @examples
blast_params <- function(type = "blastn") {
  system(paste(.findExecutable(c(type)), "-help"))
}


# BLAST -------------------------------------------------------------------

#' Run BLAST search
#'
#' @param query (Required) Query sequence. Accepts a DNABin object, DNAStringSet object, Character string, or filepath.
#' @param db (Required) Reference sequences to conduct search against. Accepts a DNABin object, DNAStringSet object, Character string, or filepath.
#' If DNAbin, DNAStringSet or character string is provided, a temporary fasta file is used to construct BLAST database.
#' If db is set to "remote", this will conduct a search against NCBI nucleotide database.
#' @param type (Required) type of search to conduct, default 'blastn'
#' @param evalue (Required) Minimum evalue from search
#' @param output_format The output format to be returned.
#'  Default is tabular, which returns 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qcov
#' See https://www.ncbi.nlm.nih.gov/books/NBK279684/ for custom formatting information
#' @param args (Optional) Extra arguments passed to BLAST
#' @param ungapped Whether ungapped alignment should be conducted. Default is FALSE.
#' @param quiet (Optional) Whether progress should be printed to console, default is FALSE
#' @param multithread Whether multithreading should be used, if TRUE the number of cores will be automatically detected, or provided a numeric vector to manually set the number of cores to use
#'
#' @return
#' @export
#' @import insect
#' @import Biostrings
#' @import stringr
#' @import tibble
#' @import dplyr
#' @import future
#'
#' @examples
#'
#' Add qcov length filter
blast <- function (query, db, type="blastn", evalue = 1e-6,
                   output_format = "tabular", args=NULL, ungapped=FALSE,
                   quiet=FALSE, multithread=FALSE){
  time <- Sys.time() # get time
  # Create temp files
  tmp <- tempdir()
  tmpquery <- paste0(tmp, "/tmpquery.fa")
  tmpdb <- paste0(tmp, "/tmpquery.fa")

  .findExecutable(type) # check blast is installed

  #Setup multithreading
  ncores <- future::availableCores() -1
  if((isTRUE(multithread) | is.numeric(multithread) & multithread > 1) & db=="remote"){
    stop("Multithreading must be set to false for remote searches")
  } else if(isTRUE(multithread)){
    cores <- ncores
    if(!quiet){message("Multithreading with ", cores, " cores")}
  } else if (is.numeric(multithread) & multithread > 1){
    cores <- multithread
    if(cores > ncores){
      cores <- ncores
      message("Warning: the value provided to multithread is higher than the number of cores, using ", cores, " cores instead")
    }
    if(!quiet){message("Multithreading with ", cores, " cores")}
  } else if(isFALSE(multithread) | multithread==1){
    cores <- 1
  } else (
    stop("Multithread must be a logical or numeric vector of the numbers of cores to use")
  )

  # Check outfmt
  if(output_format=="tabular"){
    #Custom tabular format
    parsecols <- c("qseqid", "sseqid", "pident", "length", "mismatch", "gapopen",
                   "qstart", "qend", "sstart", "send", "evalue", "bitscore", "qcovs", "qcovhsp")
    outfmt <- paste0("\"",6," ", paste(parsecols, collapse=" "),"\"")
  } else if(is.numeric(output_format)){
    outfmt <- output_format
    parsecols <- NULL
  } else if (!is.na(str_extract(output_format, "."))){
    outfmt <- paste0("\"",output_format,"\"")
    parsecols <- output_format %>%
      str_remove("^..") %>%
      str_split_fixed("\ ", n=Inf) %>%
      as.character()
  }

  # Database
  if(db=="remote"){
    db <- "nt"
    remote <- "-remote"
  } else if(inherits(db, "DNAbin")){
    if (!quiet) { message("Database input is DNAbin: Creating temporary blast database") }
    insect::writeFASTA(db, tmpdb)
    makeblastdb(tmpdb)
    db <- tmpdb
    remote <- ""
  } else if (inherits(db, "DNAString") | inherits(db, "DNAStringSet")){
    if (!quiet) { message("Database input is DNAStringSet: Creating temporary blast database") }
    Biostrings::writeXStringSet(db, tmpdb)
    makeblastdb(tmpdb)
    db <- tmpdb
    remote <- ""
  } else if (inherits(db, "character") &&  all(stringr::str_to_upper(stringr::str_split(db,"")[[1]]) %in% Biostrings::DNA_ALPHABET)) { # Handle text input
    if (!quiet) { message("Database input is character string: Creating temporary blast database") }
    if (nchar(db[1]) == 1) {db <- paste0(db, collapse = "")}
    db <- insect::char2dna(db)
    insect::writeFASTA(db, tmpdb)
    makeblastdb(tmpdb)
    db <- tmpdb
    remote <- ""
  } else if (inherits(db, "character") &&  file.exists(file.path(db))){ # Handle filename
    makeblastdb(db)
    db <- stringr::str_replace(db, ".gz", "")
    remote <- ""
  } else {
    stop("Invalid BLAST database")
  }

  # Query
  if(inherits(query, "DNAbin")){
    if (!quiet) { message("Query is DNAbin: Creating temporary fasta file") }
    query <- ape::del.gaps(query)
    insect::writeFASTA(query, tmpquery)
    input <- tmpquery
  } else if (inherits(query, "DNAString") | inherits(query, "DNAStringSet")){
    if (!quiet) { message("Query is DNAString: Creating temporary fasta file") }
    query <- ape::as.DNAbin(query)
    query <- ape::del.gaps(query)
    insect::writeFASTA(query, tmpquery)
    input <- tmpquery
  }else if (inherits(query, "character") &&  all(str_to_upper(str_split(query,"")[[1]]) %in% Biostrings::DNA_ALPHABET)) { # Handle text query
    if (!quiet) { message("Query is character string: Creating temporary fasta file") }
    if (nchar(query[1]) == 1) {query <- paste0(query, collapse = "")}
    query <- insect::char2dna(query)
    query <- ape::del.gaps(query)
    insect::writeFASTA(query, tmpquery)
    input <- tmpquery
  } else if (inherits(query, "character") &&  file.exists(file.path(query))){ # Handle filenames
    input <- query
  }else {
    stop("Invalid BLAST query")
  }

  #Setup ungapped
  ungapped <- ifelse(ungapped, "-ungapped ","")

  nthreads <- ifelse(cores > 1, paste0("-num_threads ",unname(cores)), "")

  #  Conduct BLAST search
  if (!quiet) { message("Running BLASTn query: ", paste(c("-db", db,
                                                          "-query", input,
                                                          remote,
                                                          "-outfmt", outfmt,
                                                          "-evalue", evalue,
                                                          args,
                                                          nthreads,
                                                          ungapped), collapse=" "))}
  results <- system2(command = .findExecutable(type),
                     args = c("-db", db,
                              "-query", input,
                              remote,
                              "-outfmt", outfmt,
                              "-evalue", evalue,
                              args,
                              nthreads,
                              ungapped),
                     wait = TRUE,
                     stdout = TRUE)

  # Parse BLAST results
  if(!is.null(parsecols)){
    out <- results %>%
      tibble::enframe() %>%
      tidyr::separate(col = value, into = parsecols,  sep = "\t", convert = TRUE)
  } else{
    message("Warning, result parsing is currently only supported for output_format = 'tabular', returning raw results")
    out <- results %>%
      tibble::enframe()
  }
  time <- Sys.time() - time
  if (!quiet) (message(paste0("finished BLAST in ", format(time, digits = 2))))

  if(file.exists(tmpdb)){file.remove(tmpdb)}
  if(file.exists(tmpquery)){file.remove(tmpquery)}
  return(out)
}


# BLAST_top_hit -----------------------------------------------------------

#' BLAST Top Hit
#'
#' @description Conduct BLAST search and return top hit
#' @param query (Required) Query sequence. Accepts a DNABin object, DNAStringSet object, Character string, or filepath.
#' @param db (Required) Reference sequences to conduct search against. Accepts a DNABin object, DNAStringSet object, Character string, or filepath.
#' If DNAbin, DNAStringSet or character string is provided, a temporary fasta file is used to construct BLAST database
#' @param type (Required) type of search to conduct, default 'blastn'
#' @param identity (Required) Minimum percent identity cutoff.
#' @param coverage (Required) Minimum percent query coverage cutoff.
#' @param evalue (Required) Minimum expect value (E) for saving hits
#' @param maxtargetseqs (Required) Number of aligned sequences to keep. Even if you are only looking for 1 top hit keep this higher for calculations to perform properly.
#' @param maxhsp (Required) Maximum number of HSPs (alignments) to keep for any single query-subject pair.
#' @param ranks (Required) The taxonomic ranks contained in the fasta headers
#' @param delim (Required) The delimiter between taxonomic ranks in fasta headers
#' @param args (Optional) Extra arguments passed to BLAST
#' @param quiet (Optional) Whether progress should be printed to console, default is FALSE
#'
#' @return
#' @export
#' @import dplyr
#' @import tidyr
#'
#' @examples
blast_top_hit <- function(query, db, type="blastn",
                          identity=95, coverage=95, evalue=1e06, maxtargetseqs=5, maxhsp=5,
                          ranks=c("Kingdom", "Phylum","Class", "Order", "Family", "Genus", "Species"), delim=";",
                          tie="first", args=NULL, quiet=FALSE ){

  # set input filters in advance to speed up blast
  args <- paste("-perc_identity", identity, "-max_target_seqs", maxtargetseqs, "-max_hsps", maxhsp, args)


  #Conduct BLAST
  result <- blast(query=query, type=type, db=db,
                  evalue = evalue,
                  args=args,
                  output_format = '6 qseqid sseqid stitle pident length mismatch gapopen qstart qend sstart send evalue bitscore qcovs') %>%
    dplyr::filter(!is.na(sseqid))

  #Subset to top hit
  top_hit <- result %>%
    dplyr::filter(pident > identity, qcovs > coverage)%>%
    dplyr::group_by(qseqid) %>%
    dplyr::top_n(1, bitscore) %>%
    tidyr::separate(stitle, c("acc", ranks), delim)

  if(tie == "first"){
    top_hit <- top_hit %>%
      dplyr::top_n(1, row_number(name)) %>% # Break ties by position
      dplyr::ungroup()
  } else if(tie == "all"){
    top_hit <- top_hit %>%
      dplyr::ungroup()
  }
  return(top_hit)
}


# BLAST assign species ----------------------------------------------------


#' Assign species using BLAST
#'
#' @description This is to be used alongside a hierarchial classifier such as IDTAXA or RDP to assign additional species level matches.
#' This is designed to be a more flexible version of dada2's assignSpecies function
#' @param query (Required) Query sequence. Accepts a DNABin object, DNAStringSet object, Character string, or filepath.
#' @param db (Required) Reference sequences to conduct search against. Accepts a DNABin object, DNAStringSet object, Character string, or filepath.
#' If DNAbin, DNAStringSet or character string is provided, a temporary fasta file is used to construct BLAST database
#' @param type (Required) type of search to conduct, default 'blastn'
#' @param identity (Required) Minimum percent identity cutoff.
#' @param coverage (Required) Minimum percent query coverage cutoff.
#' @param evalue (Required) Minimum expect value (E) for saving hits
#' @param maxtargetseqs (Required) Number of aligned sequences to keep. Even if you are only looking for 1 top hit keep this higher for calculations to perform properly.
#' @param maxhsp (Required) Maximum number of HSPs (alignments) to keep for any single query-subject pair.
#' @param ranks (Required) The taxonomic ranks contained in the fasta headers
#' @param delim (Required) The delimiter between taxonomic ranks in fasta headers
#' @param args (Optional) Extra arguments passed to BLAST
#' @param quiet (Optional) Whether progress should be printed to console, default is FALSE
#'
#' @return
#' @export
#' @import dplyr
#' @import tidyr
#' @import stringr
#'
#' @examples
blast_assign_species <- function(query, db, type="blastn",
                                 identity=975, coverage=95, evalue=1e06, maxtargetseqs=5, maxhsp=5,
                                 ranks=c("Kingdom", "Phylum","Class", "Order", "Family", "Genus", "Species"), delim=";",
                                 args=NULL, quiet=FALSE ){

  #Check input contains species and genus
  if(!any(tolower(ranks) %in% c("species", "genus"))){
    stop("Ranks must include Genus and Species")
  }

  #Conduct BLAST
  result <- blast_top_hit(query = query, db = db, type=type,
                          identity=identity, coverage=coverage, evalue=evalue, maxtargetseqs=maxtargetseqs, maxhsp=maxtargetseqs,
                          ranks=ranks, delim=delim, tie="all", args=args, quiet=quiet ) %>%
    dplyr::filter(!is.na(Species))

  top_hit <- result %>%
    dplyr::group_by(qseqid) %>%
    dplyr::mutate(spp = Species %>% stringr::str_remove("^.* ")) %>%
    dplyr::summarise(spp = paste(sort(unique(spp)), collapse = "/"), Genus, pident, qcovs,evalue, bitscore, .groups="keep") %>%
    dplyr::mutate(binomial = paste(Genus, spp)) %>%
    dplyr::distinct() %>%
    dplyr::add_tally() %>%
    dplyr::mutate(binomial =  dplyr::case_when( #Leave unassigned if conflicted at genus level
      n > 1 ~ as.character(NA),
      n == 1 ~ binomial
    )) %>%
    dplyr::select(OTU = qseqid, Genus, Species = binomial, pident, qcovs, evalue, bitscore)

  return(top_hit)
}
