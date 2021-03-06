% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fetch_sequences.R
\name{gbSearch}
\alias{gbSearch}
\title{Genbank search function}
\usage{
gbSearch(
  x,
  database = "nuccore",
  marker = c("COI[GENE]", "CO1[GENE]", "COX1[GENE]"),
  quiet = FALSE,
  output = "h",
  minlength = 1,
  maxlength = 2000,
  subsample = NULL,
  chunksize = NULL,
  out.dir = NULL,
  compress = FALSE,
  force = FALSE
)
}
\arguments{
\item{x}{A taxon name or vector of taxa to download sequences for}

\item{marker}{The barcode marker used as a search term for the database.
If this is set to "mitochondria" or "mitochondrion" it will download full mitochondrial genomes. If set to "genome" it will download entire genomes only.}

\item{quiet}{(Optional) Print text output}

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

\item{out.dir}{Output directory to write fasta files to}

\item{compress}{Option to compress output fasta files using gzip}

\item{force}{Option ot overwright files if they already exist}
}
\value{

}
\description{
Genbank search function
}
