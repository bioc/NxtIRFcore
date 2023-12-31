#' @useDynLib NxtIRFcore, .registration = TRUE
#' @import NxtIRFdata
#' @importFrom methods as is coerce callNextMethod new
#' @importFrom parallel detectCores
#' @importFrom stats as.formula model.matrix qt runif na.omit prcomp aggregate
#' @importFrom utils download.file packageVersion getFromNamespace
#' @importFrom utils setTxtProgressBar txtProgressBar
#' @importFrom tools R_user_dir
#' @importFrom magrittr %>%
#' @importFrom R.utils gzip
#' @importFrom Rcpp evalCpp
#' @import data.table
#' @importFrom fst read.fst write.fst
#' @import ggplot2
#' @importFrom AnnotationHub AnnotationHub cache
#' @importFrom BiocFileCache BiocFileCache bfcrpath bfcquery
#' @importFrom BiocGenerics start end width
#' @importFrom BiocGenerics nrow ncol rbind cbind
#' @importFrom BiocParallel SnowParam MulticoreParam SerialParam
#' @importFrom BiocParallel bpparam bplapply
#' @importFrom Biostrings readDNAStringSet DNAStringSet translate
#' @importFrom BSgenome getSeq
#' @importFrom DelayedArray qlogis plogis rowMeans DelayedArray rowSums
#' @importFrom DelayedMatrixStats rowSds
#' @importFrom genefilter rowttests
#' @importFrom GenomeInfoDb sortSeqlevels seqinfo seqlengths seqlevels<- 
#' @importFrom GenomeInfoDb seqlevels seqlevelsStyle seqlevelsStyle<-
#' @importFrom GenomeInfoDb genomeStyles
#' @importFrom GenomicRanges GRanges reduce findOverlaps 
#' @importFrom GenomicRanges makeGRangesFromDataFrame 
#' @importFrom GenomicRanges makeGRangesListFromDataFrame mcols split strand 
#' @importFrom GenomicRanges flank setdiff seqnames psetdiff disjoin mcols<- 
#' @importFrom GenomicRanges strand<- seqnames<-
#' @importFrom HDF5Array HDF5Array writeHDF5Array h5writeDimnames 
#' @importFrom IRanges IRanges Views RleList
#' @importFrom plotly config layout plotlyOutput event_data ggplotly 
#' @importFrom plotly plotlyProxy plotlyProxyInvoke renderPlotly subplot 
#' @importFrom plotly highlight
#' @importFrom rhdf5 h5createFile h5createDataset h5delete h5write h5createGroup
#' @importFrom rtracklayer import export TwoBitFile track
#' @importFrom S4Vectors metadata Rle metadata<- SimpleList 
#' @importFrom S4Vectors from to setValidity2 DataFrame
#' @importFrom S4Vectors bindCOLS bindROWS getListElement setListElement
#' @importFrom SummarizedExperiment SummarizedExperiment 
#' @importFrom SummarizedExperiment rowData colData rowData<- colData<-
#' @importFrom SummarizedExperiment assay assays assay<- assays<-
#' @importFrom SummarizedExperiment assayNames assayNames<-
#' @importClassesFrom S4Vectors DataFrame 
#' @importClassesFrom SummarizedExperiment SummarizedExperiment
NULL

# Import namespaces of internal functions of BiocGenerics and S4Vectors
# Used to set up NxtSE class

BG_replaceSlots <- getFromNamespace("replaceSlots", "BiocGenerics")
S4_disableValidity <- getFromNamespace("disableValidity", "S4Vectors")
S4_selectSome <- getFromNamespace("selectSome", "S4Vectors")

# Checks character indices on NxtSE object
SE_charbound <- function(idx, txt, fmt) {
    orig <- idx
    idx <- match(idx, txt)
    if (any(bad <- is.na(idx))) {
        msg <- paste(S4_selectSome(orig[bad]), collapse=" ")
        stop(sprintf(fmt, msg))
    }
    idx
}

