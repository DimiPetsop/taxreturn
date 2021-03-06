# Propagate taxonomic assignments to species level ------------------------

#' Propagate taxonomy
#'
#' @param tax
#' @param from
#'
#' @return
#' @export
#'
#' @examples
propagate_tax <- function(tax, from = "Family") {
  .Deprecated(new="seqateurs::na_to_unclassified", package="seqateurs", old="taxreturn::propagate_tax")
  col.prefix <- substr(colnames(tax), 1, 1) # Assumes named Kingdom, ...

  # Highest level to propagate from
  if (from == "Phylum") (start <- 2)
  if (from == "Class") (start <- 3)
  if (from == "Order") (start <- 4)
  if (from == "Family") (start <- 5)
  if (from == "Genus") (start <- 6)
  if (from == "Species") (start <- 7)

  # Propagate
  for (col in seq(start, ncol(tax))) {
    prop <- is.na(tax[, col]) & !is.na(tax[, col - 1])
    newtax <- tax[prop, col - 1]
    needs.prefix <- !grepl("^[A-z]__", newtax)
    newtax[needs.prefix] <- paste(col.prefix[col - 1], newtax[needs.prefix], sep = "__")
    tax[prop, col] <- newtax
  }
  tax
}



# Reformat hierarchy ------------------------------------------------------

#' Reformat hierarchy
#'
#' @param x A DNAbin with names formatted Accession|taxid;taxonomy
#' @param quiet Whether progress should be printed to console
#' @param ranks The taxonomic ranks to return in the output names
#' @param cores The number of  cores to use for get_ott_lineage
#'
#' @return
#' @export
#' @import ape
#' @import stringr
#' @import tidyr
#' @import tibble
#' @import dplyr
#' @import magrittr
#'
#'
#' @examples
reformat_hierarchy <- function(x, db = NULL, quiet = FALSE,
                               ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"), cores=1) {
  time <- Sys.time() # get time
  # Convert to DNAbin
  if (!is(x, "DNAbin")) {
    x <- ape::as.DNAbin(x)
  }
  if (missing(db)) {
    stop("A taxonomic database needs to be provided, generate one with get_ncbi_lineage or get_ott_taxonomy")
  }
  if(attr(db, "type") == "ncbi"){
    # Split current names
    seqnames <- names(x) %>%
      stringr::str_remove(";$") %>%
      stringr::str_split_fixed(";", n = Inf) %>%
      tibble::as_tibble() %>%
      tidyr::separate(col = V1, into = c("acc", "tax_id"), sep = "\\|")%>%
      dplyr::select(1:2, tail(names(.), 1)) %>%
      magrittr::set_colnames(c("acc", "tax_id", "species")) %>%
      dplyr::mutate(tax_id = as.numeric(tax_id))

    # Get lineage from taxid
    lineage <- seqnames %>%
      dplyr::left_join (db %>% dplyr::select(-species), by = "tax_id")  %>%
      tidyr::unite(col = Acc, c(acc, tax_id), sep = "|") %>%
      tidyr::unite(col = names, c(!!ranks), sep = ";")
  } else if(attr(db, "type") == "OTT"){
    lineage <- get_ott_lineage(x, db=db, ranks=ranks, cores=cores) %>%
      tidyr::unite(col = names, c(!!ranks), sep = ";")
  }

  names(x) <- paste(lineage$Acc, lineage$names, "", sep = ";") %>%
  stringr::str_remove(";$")
  time <- Sys.time() - time
  if (!quiet) (message(paste0("Reformatted annotations for ", length(x), " sequences in ", format(time, digits = 2))))
  return(x)
}


# Reformat DADA2 Genus ------------------------------------------------------

# make this just run output hierarchy but removing species rank

#' Reformat DADA2 Genus
#'
#' @param x
#' @param quiet
#' @param ranks
#'
#' @return
#' @export
#'
#' @examples
reformat_dada2_gen <- function(x, db = NULL, quiet = FALSE, ranks = NULL, force=FALSE) {
  if (!is.null(ranks)) {
    ranks <- ranks
  } else if (is.null(ranks)) {
    ranks <- c("kingdom", "phylum", "class", "order", "family", "genus")
    message("No ranks supplied, using default ranks for DADA2 assignTaxonomy: kingdom;phylum;class;order;family;genus")
  }
  x <- reformat_hierarchy(x, db = db, quiet = quiet, ranks = ranks)
  return(x)
}


# Reformat DADA2 Species ----------------------------------------------------

#' Reformat DADA2 Species
#'
#' @param x A DNAbin with names formatted Accession|taxid;taxonomy
#' @param quiet Whether progress should be printed to console
#'
#' @return
#' @export
#' @import ape
#' @import stringr
#' @import tibble
#' @import magrittr
#' @import dplyr
#'
#' @examples
reformat_dada2_spp <- function(x, quiet = FALSE) {
  time <- Sys.time() # get time
  # Convert to DNAbin
  if (!is(x, "DNAbin")) {
    x <- ape::as.DNAbin(x)
  }
  # Split current names
  seqnames <- names(x) %>%
    stringr::str_replace(";$", "") %>%
    stringr::str_split_fixed(";", n = Inf) %>%
    tibble::as_tibble() %>%
    dplyr::select(1, tail(names(.), 1)) %>%
    magrittr::set_colnames(c("acc", "species")) %>%
    dplyr::mutate(species = stringr::str_replace(species, pattern="_", replacement=" "))

  names(x) <- paste(seqnames$acc, seqnames$species, sep = " ")
  time <- Sys.time() - time
  if (!quiet) (message(paste0("Reformatted annotations for ", length(x), " sequences in ", format(time, digits = 2))))
  return(x)
}


# get_lineage -------------------------------------------------------------

#' Get lineage
#'
#' @param x
#' @param db
#'
#' @return
#' @export
#' @import stringr
#' @import tibble
#' @import dplyr
#' @import tidyr
#'
#' @examples
get_lineage <- function(x, db){
  if(missing(db)){ db <- taxreturn::get_ncbi_lineage()}
  cat("Getting taxonomic lineage from taxids\n")
  lineage <- names(x) %>%
    stringr::str_split_fixed(";", n = 2) %>%
    tibble::as_tibble() %>%
    tidyr::separate(col = V1, into = c("acc", "tax_id"), sep = "\\|") %>%
    dplyr::rename(species = V2) %>%
    dplyr::mutate(tax_id = as.numeric(tax_id))  %>%
    dplyr::left_join (db %>% dplyr::select(-species), by = "tax_id")  %>%
    tidyr::unite(col = V1, c(acc, tax_id), sep = "|")  %>%
    dplyr::rename(Acc = V1)
  return(lineage)
}


# train IDTAXA -----------------------------------------------------------

#' Train IDTAXA
#'
#' @param x A DNAbin
#' @param maxGroupSize The
#' @param maxIterations The number of i
#' @param allowGroupRemoval
#' @param orient Training sequences must all be in the same orientation. Set this to TRUE to reorient the sequences if you are unsure.
#' @param get_lineage Get full taxonomic lineage using reformat_hierarchy if not already present
#' @param db A database file generated by `get_ncbi_lineage` or `get_ott_lineage`. Required if get_lineage is TRUE
#' @param quiet Whether progress should be printed to console
#'
#' @return
#' @export
#' @import Biostrings
#' @import ape
#' @import DECIPHER
#' @import stringr
#'
#' @examples
train_idtaxa <- function(x, maxGroupSize=10, maxIterations = 3,  allowGroupRemoval = TRUE, orient=FALSE,
                         get_lineage=FALSE, db = NULL, quiet = FALSE) {
  time <- Sys.time() # get time

  #Reformat to complete taxonomic hierarchy
  if(get_lineage & !is.null(db)){
    seqs <- taxreturn::reformat_hierarchy(x, db=db, quiet=FALSE)
  } else if(get_lineage &  is.null(db)){
    stop("If get_lineage is TRUE, a db needs to be provided")
  } else  (seqs <- x)

  #Remove NA's
  if(length(names(seqs)[str_detect(names(seqs), ";NA;")]) > 1){
    remove <- names(seqs)[str_detect(names(seqs), ";NA;")]
    subset <- seqs[!names(seqs) %in% remove]
    message(paste0(length(seqs) - length(subset)," Sequences with NA's in taxonomy removed"))
    seqs <- subset
  }

  # Convert to DNAstringset for DECIPHER
  if(is(seqs, "DNAbin")){
    seqs <- taxreturn::DNAbin2DNAstringset(seqs)
  }

  # Remove gaps
  if(!quiet){ message("Removing gaps")}
  seqs <- DECIPHER::RemoveGaps(seqs)

  if(orient){
    if(!quiet){ message("Orienting sequences")}
    seqs <- DECIPHER::OrientNucleotides(seqs)
  }

  # As taxonomies are encoded in the sequence names rather than a separate file, use:
  taxid <- NULL

  #Add Root Rank
  names(seqs) <- names(seqs)  %>% stringr::str_replace(";[;]*", ";Root;")

  # obtain the taxonomic assignments
  groups <- names(seqs) # sequence names

  # assume the taxonomy begins with 'Root;'
  groups <- gsub("(.*)(Root;)", "\\2", groups) # extract the group label
  groupCounts <- table(groups)
  u_groups <- names(groupCounts) # unique groups

  if (!quiet) {message(paste0(length(u_groups), " unique species"))}

  # Pruning training set
  remove <- logical(length(seqs))
  for (i in which(groupCounts > maxGroupSize)) {
    index <- which(groups==u_groups[i])
    keep <- sample(length(index),
                   maxGroupSize)
    remove[index[-keep]] <- TRUE
  }
  if (!quiet) {message(paste0(sum(remove), " sequences pruned from over-represented groups"))}

  # Training the classifier
  probSeqsPrev <- integer() # suspected problem sequences from prior iteration
  for (i in seq_len(maxIterations)) {
    if (!quiet) {message("Training iteration: ", i, "\n", sep="")}
    # train the classifier
    trainingSet <- DECIPHER::LearnTaxa(seqs[!remove], names(seqs)[!remove], taxid)

    # look for problem sequences
    probSeqs <- trainingSet$problemSequences$Index
    if (length(probSeqs)==0) {
      if (!quiet) {message("No problem sequences remaining.\n")}
      break
    } else if (length(probSeqs)==length(probSeqsPrev) &&
               all(probSeqsPrev==probSeqs)) {
      if (!quiet) {message("Iterations converged.\n")}
      break
    }
    if (i==maxIterations)
      break
    probSeqsPrev <- probSeqs

    # remove any problem sequences
    index <- which(!remove)[probSeqs]
    remove[index] <- TRUE # remove all problem sequences
    if (!allowGroupRemoval) {
      # replace any removed groups
      missing <- !(u_groups %in% groups[!remove])
      missing <- u_groups[missing]
      if (length(missing) > 0) {
        index <- index[groups[index] %in% missing]
        remove[index] <- FALSE # don't remove
      }
    }
  }
  if (!quiet) {message(paste0(sum(remove), " sequences removed"))}
  if (!quiet) {message(paste0(length(probSeqs), " problem sequences remaining"))}

  time <- Sys.time() - time
  if (!quiet) (message(paste0("trained IDTAXA on ", length(x), " sequences in ", format(time, digits = 2))))
  return(trainingSet)
}


# taxonomy_to_newick ------------------------------------------------------

#' tax2tree
#'
#' @param x a DNAbin object or an object coercible to DNAbin
#' @param ranks The taxonomic ranks currently assigned to the names
#' @param depth The depth within the tree to return. Default NULL to return lowest input rank
#' @param summarise Select a taxonomic rank to summarise below. Default is FALSE to return a tree of the same size as input
#' @param output The output to return, options are:
#' "phylo" to return an ape phylo object. If summarise is set to a rank, the number of distinct taxa at that rank numbers are appended to the tip labels if append_sum is TRUE, or returned as an attribute and can be accessed with attr(tree, "sum")
#' "data.tree" to return a data.tree node object
#' "treedf" to return a simplified tree with taxon summaries in a data frame
#' "newick" to return a newick file for visualisation in other software. If summarise is set to a rank, the number of distinct taxa at that rank numbers are returned as an attribute and can be accessed with attr(tree, "sum")
#' @param replace_bads An option to automatically replace invalid newick characters with '-'
#' @param append_sum An option to append the summary number to the output trees tip labels when summarise is a rank and output is 'phylo'.
#' If FALSE, summary numbers are returned as an attribute and can be accessed with attr(tree, "sum")
#'
#' @return a phylo, data.tree, newick, or treedf object
#' @import data.tree
#' @import ape
#' @import stringr
#' @import dplyr
#' @import tidyr
#' @import magrittr
#' @import phytools
#' @export
#'
#' @examples
tax2tree <- function(x, ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
                     depth=NULL, summarise = FALSE,  output="phylo", replace_bads=FALSE, append_sum = TRUE){

  # start timer
  time <- Sys.time()

  #Checks
  if (!is(x, "DNAbin")) {
    x <- ape::as.DNAbin(x)
    if (all(is.na(ape::base.freq(x)))) {stop("Error: Object is not coercible to DNAbin \n")}
  }
  if (!output %in% c("phylo", "treedf", "data.tree", "newick")) { stop("Output must be 'phylo', 'data.tree', 'newick' or 'treedf'")}

  if(any(stringr::str_detect(names(x) %>% stringr::str_remove("\\|.*$"), "\\,|\\;|\\:|\\(|\\)|\\[|\\]")) && output %in% c("newick", "phylo")){
    if(replace_bads){
      names(x) <- names(x) %>%
        stringr::str_split_fixed("\\|", n=2) %>%
        as.data.frame() %>%
        dplyr::mutate(
          V1 = V1 %>%
            stringr::str_remove("\\|.*$") %>%
            stringr::str_replace_all("\\,|\\;|\\:|\\(|\\)|\\[|\\]", "_")
        ) %>%
        tidyr::unite("names", everything(), sep="|") %>%
        dplyr::pull(names)

    }else{
      stop("Sequence accessions contain one or more of the invalid characters , ; : ( ) [ ] charcters, set replace_bads to TRUE to replace with '-' ")
    }
  }

  # leave an autodetect for ranks?
  ranks <- stringr::str_to_lower(ranks)

  if (!is.null(depth)){
    ranks <- ranks[1:depth]
  }

  if(is(summarise, "character")){
    summarise <- stringr::str_to_lower(summarise)

    if(summarise %in% ranks){
      groupranks <- ranks[1:match(summarise, ranks)]
    } else {
      stop("Summarise must be one of the values in ranks")
    }
  }
  #Get taxonomic lineage
  lineage <- names(x) %>%
    stringr::str_remove(pattern=";$") %>%
    stringr::str_split_fixed(";", n=Inf) %>%
    as.data.frame() %>%
    magrittr::set_colnames(c("Acc", ranks ))

  lineage <- lineage[,!is.na(colnames(lineage))]

  if(is(summarise, "character")){
    lineage <- lineage %>%
      dplyr::select(-Acc) %>%
      dplyr::group_by_at(groupranks) %>%
      dplyr::summarise(sum = dplyr::n())

    tipsums <- lineage %>%
      dplyr::pull(sum)
    names(tipsums) <- lineage%>%
      dplyr::pull(!!summarise)

    lineage <- lineage %>%
      tidyr::unite(col=pathString, !!groupranks, sep="/") %>%
      dplyr::mutate(pathString = paste0("Root/", pathString))%>%
      data.tree::as.Node(.)

  } else if(isFALSE(summarise)){
    lineage <- lineage %>%
      mutate(Acc = Acc %>% str_remove("\\|.*$")) %>%
      tidyr::unite(col=pathString, !!ranks, Acc, sep="/") %>%
      dplyr::mutate(pathString = paste0("Root/", pathString)) %>%
      data.tree::as.Node(.)
  } else(
    stop("Summarise must refer to a taxonomic rank, or be FALSE")
  )

  if (output=="phylo"){
    nwk <- lineage  %>%
      data.tree::ToNewick(heightAttribute = NULL)
    out <-  phytools::read.newick(textConnection(nwk))
    if(is(summarise, "character") & append_sum){
      out$tip.label <- paste0(out$tip.label, "-", tipsums)
      attr(out, "sum") <- tipsums
    }else if(is(summarise, "character") & !append_sum){
      attr(out, "sum") <- tipsums
    }
  } else if (output=="treedf" & is(summarise, "character")){
    out <- data.tree::ToDataFrameTree(lineage, "sum")
  } else if (output=="treedf" & !is(summarise, "character")){
    out <- data.tree::ToDataFrameTree(lineage)
  } else if (output=="data.tree"){
    out <- lineage
  } else if (output =="newick"){
    out <- lineage  %>%
      data.tree::ToNewick(heightAttribute = NULL)
    if(is(summarise, "character")){
      attr(out, "sum") <- tipsums
    }
  }

  time <- Sys.time() - time
  message(paste0("Generated a taxonomic tree for ", length(x), " Sequences in ", format(time, digits = 2)))

  return(out)
}


# tax2phylo ---------------------------------------------------------------


#' @param ranks The taxonomic ranks currently assigned to the names
#' @param summarise Select a taxonomic rank to summarise below. Default is FALSE to return a tree of the same size as input
#' @param output The output to return, options are:
#' "phylo" to return an ape phylo object. If summarise is set to a rank, the number of distinct taxa at that rank numbers are appended to the tip labels if append_sum is TRUE, or returned as an attribute and can be accessed with attr(tree, "sum")
#' "data.tree" to return a data.tree node object
#' "treedf" to return a simplified tree with taxon summaries in a data frame
#' "newick" to return a newick file for visualisation in other software. If summarise is set to a rank, the number of distinct taxa at that rank numbers are returned as an attribute and can be accessed with attr(tree, "sum")
#' @param replace_bads An option to automatically replace invalid newick characters with '-'
#' @param append_sum An option to append the summary number to the output trees tip labels when summarise is a rank and output is 'phylo'.
#' If FALSE, summary numbers are returned as an attribute and can be accessed with attr(tree, "sum")
#'
#'
#' tax2phylo
#'
#' @description A newer, faster tax2tree that grafts tips. Only returns a phylo objec
#' @param x
#' @param ranks The taxonomic ranks currently assigned to the names
#' @param depth The depth within the ranks to return. Default all to return lowest input rank
#' @param summarise Summarise the number of sequences at depth.
#' @param append_sum Append the summary number to the output trees tip labels when summarise is TRUE
#' @param hex Convert the accessions to hexadecimal format to avoid newick incompatible characters. Can be reversed with hex2acc
#' @param resolve_poly Randomly resolve polytomies in tree using `ape::multi2di`. use 'all' to resolve all polytomies, or 'upper' to only resolve upper branches, useful for making constraints trees
#'
#' @return
#' @export
#' @import data.tree
#' @import ape
#' @import stringr
#' @import dplyr
#' @import tidyr
#' @import magrittr
#' @import phytools
#'
#' @examples
tax2phylo <- function(x, ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"), depth="all",
                      summarise = FALSE, append_sum = TRUE, hex=FALSE, resolve_poly=FALSE){

  # start timer
  time <- Sys.time()

  #Checks
  if (!is(x, "DNAbin")) {
    x <- ape::as.DNAbin(x)
    if (all(is.na(ape::base.freq(x)))) {stop("Error: Object is not coercible to DNAbin \n")}
  }

  if(isTRUE(hex)){
    x <- acc2hex(x)
  }

  if(any(stringr::str_detect(names(x) %>% stringr::str_remove("\\|.*$"), "\\,|\\;|\\:|\\(|\\)|\\[|\\]"))) {
    stop("Sequence accessions contain one or more of the invalid characters , ; : ( ) [ ] charcters, set hex to TRUE to convert to hexadecimal encoding ")
  }

  if(is.character(resolve_poly) & !resolve_poly %in% c("upper", "all")){
    stop("resolve_poly must either be FALSE, 'upper', or 'all ")
  }

  # leave an autodetect for ranks?
  ranks <- stringr::str_to_lower(ranks)
  depth <- stringr::str_to_lower(depth)

  if (depth %in% ranks){
    groupranks <- ranks[1:match(depth, ranks)]
    message("Ranks included at depth ", depth," : ", paste(ranks, collapse=" "))
  } else if(depth==all){
    groupranks <- ranks
  } else {
    stop("Depth must be 'all' or one of the values in ranks")
  }

  #Get taxonomic lineage
  lineage <- names(x) %>%
    stringr::str_remove(pattern=";$") %>%
    stringr::str_split_fixed(";", n=Inf) %>%
    as.data.frame() %>%
    magrittr::set_colnames(c("Acc", ranks ))

  #lineage <- lineage[,!is.na(colnames(lineage))]

  if(isTRUE(summarise)){
    lineage <- lineage %>%
      dplyr::select(-Acc) %>%
      dplyr::group_by_at(groupranks) %>%
      dplyr::summarise(sum = dplyr::n())

    tipsums <- lineage %>%
      dplyr::pull(sum)
    names(tipsums) <- lineage%>%
      dplyr::pull(!!depth)

    tree <- lineage %>%
      tidyr::unite(col=pathString, !!groupranks, sep="/") %>%
      dplyr::mutate(pathString = paste0("Root/", pathString))%>%
      data.tree::as.Node(.) %>%
      data.tree::ToNewick(heightAttribute = NULL) %>%
      textConnection() %>%
      phytools::read.newick()

    #Append summaries of lower ranks
    if(append_sum){
      tree$tip.label <- paste0(tree$tip.label, "-", tipsums)
      attr(tree, "sum") <- tipsums
    }else if(!append_sum){
      attr(tree, "sum") <- tipsums
    }

    #Resolve polytomies in tree
    if(resolve_poly == "upper"){
      tree <- ape::multi2di(tree)
    }

  } else if(isFALSE(summarise)){
    # get mapping table for grafting
    mapping <- lineage %>%
      dplyr::mutate(Acc = Acc %>% str_remove("\\|.*$")) %>%
      dplyr::select(tail(groupranks,1), Acc)%>%
      mutate_all(~str_replace_all(.x," ", "_"))

    upper_tree <- lineage %>%
      dplyr::select(!!groupranks) %>%
      dplyr::distinct() %>%
      tidyr::unite(col=pathString, !!groupranks, sep="/") %>%
      dplyr::mutate(pathString = paste0("Root/", pathString)) %>%
      data.tree::as.Node(.,
                         table,
                         pathName = "pathString",
                         pathDelimiter = "/",
                         colLevels = NULL,
                         na.rm = TRUE,
                         check = "check")  %>%
      data.tree::ToNewick(heightAttribute = NULL) %>%
      textConnection() %>%
      phytools::read.newick()

    #Resolve polytomies in upper tree
    if(resolve_poly == "upper"){
      upper_tree <- ape::multi2di(upper_tree)
    }

    # Graft tips onto upper tree
    tree <- graft_tips(upper_tree, mapping)
  }else(
    stop("Summarise must be TRUE or FALSE")
  )
  #Resolve polytomies in tree
  if(resolve_poly == "all"){
    tree <- ape::multi2di(tree)
  }
  time <- Sys.time() - time
  message(paste0("Generated a taxonomic tree for ", length(x), " Sequences in ", format(time, digits = 2)))
  return(tree)
}


# graft_tips --------------------------------------------------------------

#' Graft new tips onto an existing tree
#'
#' @param tree A phylo object
#' @param mapping A mapping data frame containing two columns.
#' The left column must be identical to the tip labels of the phylogeny, the right column contains new tips to be grafted.
#' @param branch_length A numeric giving the branch lengths for the new polytomic tips that are added.
#'
#' @return
#' @export
#' @import ape
#'
#' @examples
graft_tips <- function(tree, mapping, branch_length = 0){
  if (!inherits(tree, "phylo")) stop("'tree' is not of class 'phylo'")

  info <- apply(mapping, 2, setequal, y = tree$tip.label)
  if (!any(info)) stop("'mapping' is not congruent with tiplabels of 'tree'")

  #Split into current tips to be grafted
  mapping <- split(mapping[, !info], mapping[, info])
  add_tip <- function(z){
    z <- ape::read.tree(text = paste0("(", paste(z, collapse = ","), ");"))
    ape::compute.brlen(z, branch_length) ## set branch lengths to branch_length
  }
  combs <- lapply(mapping, add_tip)
  for (i in seq_along(combs)){
    tree <- ape::bind.tree(tree, combs[[i]], which(tree$tip.label == names(combs)[i]))
  }
  return(tree)
}


# Filter sequences by taxonomy --------------------------------------------

#' Filter sequences by taxonomy
#'
#' @param x A DNAbin or DNAString with heirarchial taxonomy
#' @param filtrank The taxonomic rank to subset at i.e. 'Class'
#' @param filtvalue A taxonomic name or vector of taxonomic names to subset filtrank at at i.e. c('Insecta', 'Arachnida')
#' @param ranks The taxonomic ranks currently assigned to the sequences
#'
#' @return
#' @export
#' @import stringr
#' @import tidyr
#' @import dplyr
#' @import magrittr
#' @import ape
#' @import Biostrings
#'
#' @examples
filter_by_tax <- function(x, filtrank, filtvalue, ranks=c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species")){

  # Convert to DNAbin
  if (!class(x) %in% c("DNAbin", "DNAStringSet")  ) {
    stop("x must be a DNAbin or DNAstringset \n")
  }

  ranklength <- length(ranks)
  if(!stringr::str_count(names(x)[[1]] %>% stringr::str_remove(";$"), ";")== ranklength){
    stop("Error, the number of semicolon delimiters do not match the length of ranks")
  }

  filtnames <- names(x) %>%
    stringr::str_remove(";$") %>%
    stringr::str_split_fixed(";", n=(ranklength+1)) %>%
    as.data.frame(stringsAsFactors=FALSE) %>%
    magrittr::set_colnames(c("acc", tolower(ranks))) %>%
    dplyr::filter(!!sym(tolower(filtrank)) %in% filtvalue)%>%
    tidyr::unite(col="names", dplyr::everything(), sep=";") %>%
    pull(names)

  out <- x[names(x) %in% filtnames]

  if(length(filtvalue) > 10){
    out_message <- paste0(paste(filtvalue[1:10], collapse= ", "),"...[TRUNCATED]")
  } else(
    out_message <- paste(filtvalue, collapse= ", ")
  )

  message(length(x) - length(out), " sequences which did not pass the filter '", filtrank, " %in% ", out_message, "' removed")
  return(out)
}

# LCA probs ---------------------------------------------------------------

#' Probabilitys of sharing a rank as a function of sequence identity
#'
#' @param x a DNAbin object or an object coercible to DNAbin
#' @param method The distance matrix computation method to use,
#' accepts "mbed" which computes a distance matrix from each sequence to a subset of 'seed' sequences using the method outlined in Blacksheilds et al (2010).
#' This scales well to big datasets, alternatively "kdist" computes the full n * n distance matrix.
#' @param k integer giving the k-mer size used to generate the input matrix for k-means clustering.
#' @param nstart value passed to  nstart passed to kmeans. Higher increases computation time but can improve clustering accuracy considerably.
#' @param ranks The taxonomic ranks currently assigned to the names
#' @param delim The delimiter used between ranks
#'
#' @return
#' @export
#' @import ape
#' @import stringr
#' @import kmer
#' @import dplyr
#'
#'
#' @examples
lca_probs <- function(x, method="mbed",  k=5, nstart = 20, ranks=c("kingdom", "phylum", "class", "order", "family", "genus", "species"), delim=";"){
  # Convert to DNAbin
  if (!is(x, "DNAbin")) {
    x <- ape::as.DNAbin(x)
  }

  # Replace any trailing delimiters
  names(x) <- names(x) %>%
    stringr::str_remove(";$")
  # Count number of remaining delimiters
  ndelim <- stringr::str_count(names(x)[1], ";")

  #check if delims match ranks
  if(any(ndelim <=1)) {
    stop("Error: Needs to be in hierarchial format first, run get_lineage or get_ott_lineage")
  } else if (!ndelim==length(ranks)){
    stop("Error: Number of delimiters does not match number of ranks")
  }

  # Create distance matrix - could probably do this using random samples
  if(method == "kdist"){
    dist <- as.matrix(kmer::kdistance(x, k=k, method="edgar", residues="DNA"))
  } else if(method == "mbed"){
    dist <- as.matrix(kmer::mbed(x, k=k, residues="DNA")[,])
  }

  #convert to pairwise distances
  xy <- t(combn(colnames(dist), 2))
  pw <- data.frame(xy, dist=(100 - round(dist[xy] * 100)))

  # subset to the values in loop

  sim <- sort(unique(pw$dist), decreasing = TRUE)
  simlist <- vector("list", length=length(sim))
  s=1
  for (s in 1:length(sim)) {

    subsets <- pw %>%
      filter(dist==sim[s])

    df1 <- subsets %>%
      tidyr::separate(X1, into=c("Acc",ranks), sep=";") %>%
      dplyr::select(rev(ranks))

    df2 <- subsets %>%
      tidyr::separate(X2, into=c("Acc",ranks), sep=";") %>%
      dplyr::select(rev(ranks))

    #Get all shared ranks
    logidf <- as.data.frame(df1 == df2)

    #Get lowest common rank
    keepvec <- apply(logidf, 1, which.max)
    rows <- seq(logidf[,1])
    #cols <- seq(logidf[1,])
    #unselect <- matrix(ncol=2,c(rep(rows, length(cols)), sort(rep(cols, length(rows)))))
    select <- matrix(ncol=2,c(rows, keepvec))

    logidf[select] <- "KEEP"
    logidf[!logidf=="KEEP"] <- 0
    logidf[logidf=="KEEP"] <- 1
    logidf <- logidf  %>%
      mutate_all(as.numeric) %>%
      colSums() / length(rows)

    simlist[[s]]  <- data.frame(rank=names(logidf), prob=logidf, sim=sim[s])

  }
  names(simlist) <- sim
  out <- dplyr::bind_rows(simlist) %>%
    dplyr::group_by(rank, sim) %>%
    dplyr::summarise(prob = mean(prob))
  return(out)
}


# Accessions from fasta ---------------------------------------------------

#' Genbank accessions from fasta
#'
#' @param x A filepath or vector of filepaths to fasta files
#'
#' @return
#' @export
#' @import Biostrings
#' @import dplyr
#'
#' @examples
acc_from_fasta <- function(x) {
  if(!all(file.exists(x))){
    stop("Input must be a filepath or vector of filepaths to fasta files")
  }
  out <- Biostrings::fasta.index(x) %>%
    dplyr::mutate(acc = desc %>%
                    stringr::str_remove(pattern="\\|.*$")) %>%
    dplyr::pull(acc)

  return(out)
}
