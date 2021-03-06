% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fetch_sequences.R
\name{gbSearch_subsample}
\alias{gbSearch_subsample}
\title{Genbank subsampling}
\usage{
gbSearch_subsample(
  x,
  database = "nuccore",
  marker = c("COI[GENE]", "CO1[GENE]", "COX1[GENE]"),
  quiet = FALSE,
  output = "h",
  minlength = 1,
  maxlength = 2000,
  subsample = 1000,
  chunksize = 300,
  compress = FALSE,
  force = FALSE,
  out.dir = NULL
)
}
\arguments{
\item{x}{A taxon name or vector of taxa to download sequences for}

\item{marker}{The barcode marker used as a search term for the database}

\item{output}{The output format for the taxonomy in fasta headers.
Options include "h" for full heirarchial taxonomy (SeqID;Domain;Phylum;Class;Order;Family;Genus;Species),
"binom" for just genus species binomials (SeqID;Genus Species),
"bold" for BOLD taxonomic ID only (SeqID;BoldTaxID),
"gb" for genbank taxonomic ID (SeqID;GBTaxID),
"gb-binom" which outputs Genus species binomials, as well as genbank taxonomic ID's, and translates all BOLD taxonomic ID's to genbank taxonomic ID's in the process
or "standard" which outputs the default format for each database. For genbank this is \verb{Accession Sequence definition}}

\item{minlength}{The minimum length of sequences to download}

\item{maxlength}{The maximum length of sequences to download}

\item{chunksize}{Split up the query into chunks of this size to avoid overloading API servers.
if left NULL, the default will be 10,000 for regular queries, 1,000 if marker is "mitochondria", and 1 if marker is "genome"}

\item{compress}{Option to compress output fasta files using gzip}

\item{force}{Option ot overwright files if they already exist}

\item{out.dir}{Output directory to write fasta files to}
}
\value{

}
\description{
Genbank subsampling
}
