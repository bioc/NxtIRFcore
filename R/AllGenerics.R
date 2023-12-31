# Generics from SummarizedExperiment

#' @export
setGeneric("rowData", signature="x",
    function(x, use.names=TRUE, ...) standardGeneric("rowData"))

#' @export
setGeneric("rowData<-",
    function(x, ..., value) standardGeneric("rowData<-"))
    
#' @export
setGeneric("colData", function(x, ...) standardGeneric("colData"))

#' @export
setGeneric("colData<-",
    function(x, ..., value) standardGeneric("colData<-"))
    
#' @export
setGeneric("assays", signature="x",
    function(x, withDimnames=TRUE, ...) standardGeneric("assays"))

#' @export
setGeneric("assays<-", signature=c("x", "value"),
    function(x, withDimnames=TRUE, ..., value) standardGeneric("assays<-"))

#' @export
setGeneric("assay", signature=c("x", "i"),
    function(x, i, withDimnames=TRUE, ...) standardGeneric("assay"))

#' @export
setGeneric("assay<-", signature=c("x", "i"),
    function(x, i, withDimnames=TRUE, ..., value) standardGeneric("assay<-"))

#' @export
setGeneric("assayNames", function(x, ...) standardGeneric("assayNames"))

#' @export
setGeneric("assayNames<-",
    function(x, ..., value) standardGeneric("assayNames<-"))

# NxtSE specific functions:

setGeneric("realize_NxtSE", 
    function(x, withDimnames=TRUE, ...) standardGeneric("realize_NxtSE"))

setGeneric("up_inc", 
    function(x, withDimnames=TRUE, ...) standardGeneric("up_inc"))

setGeneric("down_inc", 
    function(x, withDimnames=TRUE, ...) standardGeneric("down_inc"))

setGeneric("up_exc", 
    function(x, withDimnames=TRUE, ...) standardGeneric("up_exc"))

setGeneric("down_exc", 
    function(x, withDimnames=TRUE, ...) standardGeneric("down_exc"))

setGeneric("covfile", 
    function(x, withDimnames=TRUE, ...) standardGeneric("covfile"))

setGeneric("sampleQC", 
    function(x, withDimnames=TRUE, ...) standardGeneric("sampleQC"))

setGeneric("ref", 
    function(x, withDimnames=TRUE, ...) standardGeneric("ref"))

setGeneric("up_inc<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("up_inc<-"))

setGeneric("down_inc<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("down_inc<-"))

setGeneric("up_exc<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("up_exc<-"))

setGeneric("down_exc<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("down_exc<-"))

setGeneric("covfile<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("covfile<-"))

setGeneric("sampleQC<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("sampleQC<-"))
    
setGeneric("ref<-",
    function(x, withDimnames=TRUE, ..., value) standardGeneric("ref<-"))