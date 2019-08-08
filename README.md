
<!-- README.md is generated from README.Rmd. Please edit that file -->

# taxreturn

<!-- badges: start -->

[![Travis build
status](https://travis-ci.org/alexpiper/taxreturn.svg?branch=master)](https://travis-ci.org/alexpiper/taxreturn)
<!-- badges: end -->

taxreturn is an R package for fetching DNA barcode sequences and
associated taxonomic annotations from public databases such as the
Barcode of Life Database (BOLD) and NCBI GenBank, curating these
sequences and formatting them into training sets compatible with popular
taxonomic classifiers used for metabarcoding and marker gene analysis.

## Installation

This package is still in development and not yet available on CRAN. You
can install development version from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
#devtools::install_github("alexpiper/taxreturn")
```

``` r
library(taxreturn)

## Fetch sequences from GenBank - Might also be good having an output="all" option
fetchSeqs("Scaptodrosophila", database="genbank",downstream=TRUE,quiet=FALSE, downto="Family", marker="COI OR COI OR COX1 OR COXI", output = "gb-binom",compress=FALSE, cores=3)

#Note - Chrysomelidae keeps failing 

#Check if all downloaded

taxon <- dplyr::bind_rows(taxizedb::downstream("Insecta", db = "ncbi")) %>%
    dplyr::filter(rank == stringr::str_to_lower("Family"))


fetchSeqs(failed, database="genbank",downstream=FALSE,quiet=FALSE, downto="Family", marker="COI OR COI OR COX1 OR COXI", output = "gb-binom",compress=FALSE, cores=1)


## Fetch sequences from BOLD
fetchSeqs("Insecta", database="bold",downstream=TRUE,quiet=FALSE, downto="Family", marker="COI-5P", output = "gb-binom",compress=FALSE, cores=1)

taxon <- dplyr::bind_rows(taxizedb::downstream("Insecta", db = "ncbi")) %>%
    dplyr::filter(rank == stringr::str_to_lower("Family"))

done <- list.files(path="bold",pattern=".fa") %>%
  stringr::str_split_fixed(pattern="_",n=2) %>%
  dplyr::as_tibble() %>%
  dplyr::pull(V1)

failed <- taxon$childtaxa_name[which(!taxon$childtaxa_name %in% done)]

fetchSeqs(failed, database="bold",downstream=FALSE,quiet=FALSE, downto="Family", marker="COI-5P", output = "gb-binom",compress=FALSE, cores=1)


#read in all fastas and merge
gbSeqs <-  readDNAStringSet(sort(list.files("genbank", pattern = ".fa", full.names = TRUE)))
boldSeqs <-  readDNAStringSet(sort(list.files("bold", pattern = ".fa", full.names = TRUE)))
mergedSeqs <- append(gbSeqs, boldSeqs, after=length(gbSeqs))
uniqSeqs <- mergedSeqs[unique(names(mergedSeqs)),] # Remove those sequnce names that are identical across both databases


#Need to have a filter that removes degenerate bases in reads!  

#Filter using hidden markov model

#build PHMM from midori longest - sequences need to be same length
midori <-  Biostrings::readDNAStringSet("MIDORI_LONGEST_20180221_COI.fasta")
insecta_midori <- as.DNAbin(midori[str_detect(names(midori),pattern=";Insecta;"),])
folmer <- insect::virtualPCR(insecta_midori, up = "TITCIACIAAYCAYAARGAYATTGG",down= "TAIACYTCIGGRTGICCRAARAAYCA",cores=2, rcdown = TRUE, trimprimers = TRUE)
filt <- folmer[lengths(folmer)==658]

#Filtered was then aligned in MAFFT - mafft folmer_insecta_fullength.fa > folmer_insecta_fullength_aligned.fa
#alignment was then manually curated in geneious primer
folmer_curated <-  ape::read.dna("folmer_insecta_fullength_aligned_curated.fa",format="fasta")
model <- aphid::derivePHMM(folmer_curated)

#Clean taxa

#Should be able to speed up function by including the shave call within the first viterbii. Current problem is it needs to call viterbi twice
testSeqs <-  Biostrings::readDNAStringSet("test_set.fa")
filtered <- clean_seqs(testSeqs, model,minscore = 100, cores=2, shave=TRUE,maxNs = 0)

#Get unique sequences only
duplicates <- insect::duplicated.DNAbin(filtered, point = TRUE)
filtered <- insect::subset.DNAbin(filtered, subset = !duplicates)

#Save old names into attributes
attributes(filtered)$oldnames <- names(filtered)
#Get names in format for insect::purge
names(filtered) <- names(filtered) %>%
  str_split_fixed(";",n=2) %>%
  as_tibble() %>%
  pull("V1") 


#filter using insect::purge - Could wrap this in a function for ease of use?
db <- insect::taxonomy(db = "NCBI", synonyms = TRUE)

#test <- insect::prune_taxonomy(db,taxIDs =6656, keep=TRUE)
#Prune to arthropod only
#db <- insect::prune_taxonomy(db,taxIDs =6656)

#get unique names only
dupnames <- duplicated(names(filtered))
filtered <- insect::subset.DNAbin(filtered, subset = !dupnames)

purged  <- insect::purge(filtered, db = db, level = "species", confidence = 0.2,
                  threshold = 0.99, method = "farthest")

#Filter the database
db <- db %>% 
  filter(!str_detect(name,"sp\\.")) %>%
  filter(!str_detect(name,"[^[:alnum:]]")) %>% # remove special characters
  filter(!str_detect(name,"[-]?[0-9]+[.]?[0-9]*|[-]?[0-9]+[L]?|[-]?[0-9]+[.]?[0-9]*[eE][0-9]+"))

test2 <- db %>% 
  filter(!str_detect(name,"Scaptodrosophila lebanonensis"))

test <- names(filtered) %>% str_split_fixed("\\|",n=2) %>% as_tibble() %>% pull("V2")

match("7225",test2$taxID)

table(test2$taxID %in% test[1:5])


#Restore old names
names(purged) <- attributes(purged)$oldnames

#Prune group sizes down to 5 #Add a discardby=Random, or discardby=Length to the  function
pruned <- prune_groups(purged,maxGroupSize = 8, removeby="length", quiet = FALSE)


"1986136" %in% db$taxID

#Check alignments
filt_aligned <- pruned %>% as.character %>% lapply(.,paste0,collapse="") %>% unlist %>% DNAStringSet
filt_aligned <- AlignSeqs(filt_aligned)
BrowseSeqs(filt_aligned)


#Filter out misannotated terms and species that arent binomials - Maybe this can be done during groups as well?
filtseqs <- filter_taxa(mergedseqs,minlength=200,maxlength=1000,unique=TRUE,binomials=TRUE, removeterms=c("sp.","cf.","NA"))


#Merge in inhouse sequences
merged <-  readFASTA("merged_cleaned.fa")
inhouse <- readFASTA("inhouse/Inhouse_taxonomy_trimmed.fasta")

merged2 <- join(merged, inhouse)
writeFASTA(merged2,"merged_cleaned_inhouse.fa")

#write out format for training

#format_ref function

#Trim to primer region using virtualPCR from insect package
amplicon <- virtualPCR(filtseqs, up = "ACWGGWTGRACWGTNTAYCC",down= "ARYATDGTRATDGCHCCDGC",cores=3, rcdown = TRUE, trimprimers = TRUE)
writeFASTA(amplicon,"gb_trimmed.fa")
```
