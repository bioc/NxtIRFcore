#' Filtering for IR and Alternative Splicing Events
#'
#' This function implements filtering of IR or AS events based on customisable
#' criteria. See [NxtFilter] for details.
#'
#' @details
#' We highly recommend using the default filters, which are as follows:
#' * (1) Depth filter of 20,
#' * (2) Coverage filter requiring 90% coverage in IR events.
#' * (3) Coverage filter requiring 60% coverage in AS events
#'   (i.e. Included + Excluded isoforms must cover at least 60% of all junction
#'   events across the given region)
#' * (4) Consistency filter requring log difference of 2 (for skipped exon and
#'  mutually exclusive exon events, each junction must comprise at least 1/(2^2)
#'  = 1/4 of all reads associated with each isoform).
#'  For retained introns, the exon-intron overhangs must not differ by 1/4
#'
#' Also, in NxtIRFcore version 1.1.1 and above, we introduced two
#'   annotation-based filters:
#' * (5) Terminus filter: In alternate first exons, the splice junction must
#'   not be shared with another transcript for which it is not its first
#'   intron. For alternative last exons, the splice junction must not be
#'   shared with another transcript for which it is not its last intron
#' * (6) ExclusiveMXE filter: For MXE events, the two alternate
#'   casette exons must not overlap in their genomic regions
#'
#' In all data-based filters, we require at least 80% samples (`pcTRUE = 80`)
#'   to pass this filters from the entire dataset (`minCond = -1`).
#'
#' Events with event read depth (reads supporting either included or excluded
#'   isoforms) lower than 5 (`minDepth = 5`) are not assessed in filter #2, and
#'   in #3 and #4 this threshold is (`minDepth = 20`).
#'
#' For an explanation of the various parameters mentioned here, see [NxtFilter]
#'
#' @param legacy (default `FALSE`) Set to `TRUE` to get the first four 
#'   default filters introduced in the initial NxtIRFcore release.
#' @param se the \linkS4class{NxtSE} object to filter
#' @param filterObj A single \linkS4class{NxtFilter} object.
#' @param filters A vector or list of one or more NxtFilter objects. If left
#'   blank, the NxtIRF default filters will be used.
#' @return
#' For `runFilter` and `apply_filters`: a vector of type `logical`,
#'   representing the rows of NxtSE that should be kept.
#'
#' For `get_default_filters`: returns a list of default recommended filters
#'   that should be parsed into `apply_filters`.
#' @examples
#' # see ?MakeSE on example code of how this object was generated
#'
#' se <- NxtIRF_example_NxtSE()
#'
#' # Get the list of NxtIRF recommended filters
#'
#' filters <- get_default_filters()
#'
#' # View a description of what these filters do:
#'
#' filters
#'
#' # Filter the NxtSE using the first default filter ("Depth")
#'
#' se.depthfilter <- se[runFilter(se, filters[[1]]), ]
#'
#' # Filter the NxtSE using all four default filters
#'
#' se.defaultFiltered <- se[apply_filters(se, get_default_filters()), ]
#' @name Run_NxtIRF_Filters
#' @aliases get_default_filters apply_filters runFilter
#' @seealso [NxtFilter] for details describing how to create and assign settings
#'   to NxtFilter objects.
#' @md
NULL

#' @describeIn Run_NxtIRF_Filters Returns a vector of recommended default
#'   NxtIRF filters
#' @export
get_default_filters <- function(legacy = FALSE) {
    f1 <- NxtFilter("Data", "Depth", pcTRUE = 80, minimum = 20)
    f2 <- NxtFilter("Data", "Coverage", pcTRUE = 80,
        minimum = 90, minDepth = 5, EventTypes = c("IR", "RI"))
    f3 <- NxtFilter("Data", "Coverage", pcTRUE = 80,
        minimum = 60, minDepth = 20,
        EventTypes = c("MXE", "SE", "AFE", "ALE", "A5SS", "A3SS"))
    f4 <- NxtFilter("Data", "Consistency", pcTRUE = 80,
        maximum = 2, minDepth = 20, EventTypes = c("MXE", "SE", "RI"))
    f4_new <- NxtFilter("Data", "Consistency", pcTRUE = 80,
        maximum = 1, minDepth = 20, EventTypes = c("MXE", "SE", "RI"))
    f5 <- NxtFilter("Annotation", "Terminus")
    f6 <- NxtFilter("Annotation", "ExclusiveMXE")
    if(legacy) return(list(f1, f2, f3, f4))
    return(list(f1, f2, f3, f4_new, f5, f6))
}

#' @describeIn Run_NxtIRF_Filters Run a vector or list of NxtFilter objects
#'   on a NxtSE object
#' @export
apply_filters <- function(se, filters = get_default_filters()) {
    if (!is.list(filters)) filters <- list(filters)
    if (length(filters) == 0) .log("No filters given")
    for (i in length(filters)) {
        if (!is(filters[[i]], "NxtFilter")) {
            stopmsg <- paste("Element", i,
                "of `filters` is not a NxtFilter object")
            .log(stopmsg)
        }
    }
    if (!is(se, "NxtSE")) {
        .log(paste("In apply_filters(),",
            "se must be a NxtSE object"))
    }
    filterSummary <- rep(TRUE, nrow(se))
    for (i in seq_len(length(filters))) {
        filterSummary <- filterSummary & runFilter(
            se, filters[[i]]
        )
    }
    return(filterSummary)
}

#' @describeIn Run_NxtIRF_Filters Run a single filter on a NxtSE object
#' @export
runFilter <- function(se, filterObj) {
    if (!is(se, "NxtSE")) .log("`se` must be a NxtSE object")
    if (filterObj@filterClass == "Data") {
        if (filterObj@filterType == "Depth") {
            message("Running Depth filter")
            return(.runFilter_data_depth(se, filterObj))
        } else if (filterObj@filterType == "Coverage") {
            message("Running Coverage filter")
            return(.runFilter_data_coverage(se, filterObj))
        } else if (filterObj@filterType == "Consistency") {
            message("Running Consistency filter")
            return(.runFilter_data_consistency(se, filterObj))
        }
    } else if (filterObj@filterClass == "Annotation") {
        if (filterObj@filterType == "Protein_Coding") {
            message("Running Protein_Coding filter")
            return(.runFilter_anno_pc(se, filterObj))
        } else if (filterObj@filterType == "NMD") {
            message("Running NMD filter")
            return(.runFilter_anno_nmd(se, filterObj))
        } else if (filterObj@filterType == "TSL") {
            message("Running TSL filter")
            return(.runFilter_anno_tsl(se, filterObj))
        } else if (filterObj@filterType == "Terminus") {
            message("Running Terminus filter")
            return(.runFilter_anno_terminus(se, filterObj))
        } else if (filterObj@filterType == "ExclusiveMXE") {
            message("Running ExclusiveMXE filter")
            return(.runFilter_anno_mxe(se, filterObj))
        }
    } else {
        return(rep(TRUE, nrow(se)))
    }
}

################################################################################
# Individual functions:

.runFilter_cond_vec <- function(se, filterObj) {
    use_cond <- ifelse(
        (length(filterObj@condition) == 1 && filterObj@condition != "") &&
        filterObj@condition %in% colnames(colData(se)),
        TRUE, FALSE
    )
    if (use_cond) {
        cond_vec <- unlist(colData[,
            which(colnames(colData) == filterObj@condition)])
    } else {
        cond_vec <- NULL
    }
    return(cond_vec)
}

.runFilter_data_depth <- function(se, filterObj) {
    colData <- as.data.frame(colData(se))
    rowData <- as.data.frame(rowData(se))
    cond_vec <- .runFilter_cond_vec(se, filterObj)
    usePC <- filterObj@pcTRUE

    depth <- as.matrix(assay(se, "Depth"))
    sum_res <- rep(0, nrow(se))
    if (!is.null(cond_vec)) {
        for (cond in unique(cond_vec)) {
            depth.subset <- depth[, which(cond_vec == cond)]
            sum <- rowSums(depth.subset >= filterObj@minimum)
            sum_res <- sum_res +
                ifelse(sum * 100 / ncol(depth.subset) >= usePC, 1, 0)
        }
        n_TRUE <- filterObj@minCond
        if (n_TRUE == -1) n_TRUE <- length(unique(cond_vec))
        res <- (sum_res >= n_TRUE)
    } else {
        sum <- rowSums(depth >= filterObj@minimum)
        res <- ifelse(sum * 100 / ncol(depth) >= usePC, TRUE, FALSE)
    }
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_data_coverage <- function(se, filterObj) {
    colData <- as.data.frame(colData(se))
    rowData <- as.data.frame(rowData(se))
    cond_vec <- .runFilter_cond_vec(se, filterObj)
    usePC <- filterObj@pcTRUE
    minDepth <- filterObj@minDepth

    cov <- as.matrix(assay(se, "Coverage"))
    depth <- as.matrix(assay(se, "minDepth"))
    cov[depth < minDepth] <- 1 # do not test if depth below threshold

    sum_res <- rep(0, nrow(se))
    if (!is.null(cond_vec)) {
        for (cond in unique(cond_vec)) {
            cov.subset <- cov[, which(cond_vec == cond)]
            sum <- rowSums(cov.subset >= filterObj@minimum / 100)
            sum_res <- sum_res +
                ifelse(sum * 100 / ncol(cov.subset) >= usePC, 1, 0)
        }
        n_TRUE <- filterObj@minCond
        if (n_TRUE == -1) n_TRUE <- length(unique(cond_vec))
        res <- (sum_res >= n_TRUE)
    } else {
        sum <- rowSums(cov >= filterObj@minimum / 100)
        res <- ifelse(sum * 100 / ncol(cov) >= usePC, TRUE, FALSE)
    }
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_data_consistency <- function(se, filterObj) {
    colData <- as.data.frame(colData(se))
    rowData <- as.data.frame(rowData(se))
    cond_vec <- .runFilter_cond_vec(se, filterObj)
    usePC <- filterObj@pcTRUE
    minDepth <- filterObj@minDepth

    Up_Inc <- as.matrix(up_inc(se))
    Down_Inc <- as.matrix(down_inc(se))
    IntronDepth <- as.matrix(assay(se, "Included")[
        rowData$EventType %in% c("IR", "MXE", "SE", "RI"), ])
    minDepth.Inc <- Up_Inc + Down_Inc
    # do not test if depth below threshold
    Up_Inc[minDepth.Inc < minDepth] <- IntronDepth[minDepth.Inc < minDepth]
    Down_Inc[minDepth.Inc < minDepth] <- IntronDepth[minDepth.Inc < minDepth]

    Excluded <- as.matrix(assay(se, "Excluded")[
        rowData$EventType %in% c("MXE"), ])
    Up_Exc <- as.matrix(up_exc(se))
    Down_Exc <- as.matrix(down_exc(se))
    minDepth.Exc <- Up_Exc + Down_Exc
    # do not test if depth below threshold
    Up_Exc[minDepth.Exc < minDepth] <- Excluded[minDepth.Exc < minDepth]
    Down_Exc[minDepth.Exc < minDepth] <- Excluded[minDepth.Exc < minDepth]

    sum_res <- rep(0, nrow(se))
    if (!is.null(cond_vec)) {
        for (cond in unique(cond_vec)) {
            Up_Inc.subset <- Up_Inc[, which(cond_vec == cond)]
            Down_Inc.subset <- Down_Inc[, which(cond_vec == cond)]
            IntronDepth.subset <- IntronDepth[, which(cond_vec == cond)]
            Up_Exc.subset <- Up_Exc[, which(cond_vec == cond)]
            Down_Exc.subset <- Down_Exc[, which(cond_vec == cond)]
            Excluded.subset <- Excluded[, which(cond_vec == cond)]

            # sum_inc <- rowSums(
                # abs(log2(Up_Inc.subset + 1) - log2(IntronDepth.subset + 1))
                    # < filterObj@maximum &
                # abs(log2(Down_Inc.subset + 1) - log2(IntronDepth.subset + 1))
                    # < filterObj@maximum
            # )
            # sum_exc <- rowSums(
                # abs(log2(Up_Exc.subset + 1) - log2(Excluded.subset + 1))
                    # < filterObj@maximum &
                # abs(log2(Down_Exc.subset + 1) - log2(Excluded.subset + 1))
                    # < filterObj@maximum
            # )
            # sum_inc <- c(sum_inc, rep(ncol(Up_Inc.subset),
                # sum(!(rowData$EventType %in% c("IR", "MXE", "SE", "RI")))))
            # sum_exc <- c(
                # rep(ncol(Up_Inc.subset), sum(rowData$EventType == "IR")),
                # sum_exc,
                # rep(ncol(Up_Inc.subset),
                    # sum(!(rowData$EventType %in% c("IR", "MXE"))))
            # )
            # sum <- 0.5 * (sum_inc + sum_exc)
            sum <- .runFilter_data_consistency_truths(
                Up_Inc.subset, Down_Inc.subset, 
                Up_Exc.subset, Down_Exc.subset, 
                IntronDepth.subset, Excluded.subset, 
                filterObj@maximum, rowData(se)$EventType
            )            
            sum_res <- sum_res +
                ifelse(sum * 100 / ncol(Up_Inc.subset) >= usePC, 1, 0)
        }
        n_TRUE <- filterObj@minCond
        if (n_TRUE == -1) n_TRUE <- length(unique(cond_vec))
        res <- (sum_res >= n_TRUE)
    } else {
        # sum_inc <- rowSums(
            # abs(log2(Up_Inc + 1) - log2(IntronDepth + 1)) < filterObj@maximum &
            # abs(log2(Down_Inc + 1) - log2(IntronDepth + 1)) < filterObj@maximum
        # )
        # sum_exc <- rowSums(
            # abs(log2(Up_Exc + 1) - log2(Excluded + 1)) < filterObj@maximum &
            # abs(log2(Down_Exc + 1) - log2(Excluded + 1)) < filterObj@maximum
        # )
        # sum_inc <- c(sum_inc, rep(ncol(Up_Inc),
            # sum(!(rowData$EventType %in% c("IR", "MXE", "SE", "RI")))))
        # sum_exc <- c(
            # rep(ncol(Up_Inc), sum(rowData$EventType == "IR")),
            # sum_exc,
            # rep(ncol(Up_Inc),
                # sum(!(rowData$EventType %in% c("IR", "MXE"))))
        # )
        # sum <- 0.5 * (sum_inc + sum_exc)
        
        sum <- .runFilter_data_consistency_truths(
            Up_Inc, Down_Inc, Up_Exc, Down_Exc,
            IntronDepth, Excluded, 
            filterObj@maximum, rowData(se)$EventType
        )
        res <- ifelse(sum * 100 / ncol(Up_Inc) >= usePC, TRUE, FALSE)
    }
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_data_consistency_truths <- function(
    Up_Inc, Down_Inc, Up_Exc, Down_Exc,
    IntronDepth, Excluded, maximum, EventTypeVec
) {
    num_IR <- sum(EventTypeVec == "IR")
    num_MXE <- sum(EventTypeVec == "MXE")
    num_SE <- sum(EventTypeVec == "SE")
    num_other <- sum(!(EventTypeVec %in% c("IR", "MXE", "SE", "RI")))
    num_RI <- sum(EventTypeVec == "RI")
    num_samples <- ncol(Up_Inc)

    truth_inc_temp <- 
        abs(log2(Up_Inc + 1) - log2(IntronDepth + 1)) < maximum &
        abs(log2(Down_Inc + 1) - log2(IntronDepth + 1)) < maximum

    truth_inc <- rbind(
        truth_inc_temp[seq_len(num_IR + num_MXE + num_SE),],
        matrix(TRUE, nrow = num_other, ncol = num_samples),
        truth_inc_temp[-seq_len(num_IR + num_MXE + num_SE),]
    )
        
    truth_exc <- rbind(
        matrix(TRUE, nrow = num_IR, ncol = num_samples),
        (
            abs(log2(Up_Exc + 1) - log2(Excluded + 1)) < maximum &
            abs(log2(Down_Exc + 1) - log2(Excluded + 1)) < maximum
        ),
        matrix(TRUE, nrow = num_SE + num_other + num_RI, ncol = num_samples)
    )
    
    truth_total <- truth_inc & truth_exc
    
    sum <- rowSums(truth_total)
    
    return(sum)
}

# returns if any of included or excluded is protein_coding
.runFilter_anno_pc <- function(se, filterObj) {
    rowSelected <- as.data.table(rowData(se))
    rowSelected <- rowSelected[
        get("Inc_Is_Protein_Coding") == TRUE |
        get("Exc_Is_Protein_Coding") == TRUE]
    rowSelected <- rowSelected[get("EventType") != "IR" |
        get("Inc_Is_Protein_Coding") == TRUE] # filter for CDS introns
    res <- rowData(se)$EventName %in% rowSelected$EventName
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_anno_nmd <- function(se, filterObj) {
    rowSelected <- as.data.table(rowData(se))
    rowSelected <- rowSelected[!is.na(get("Inc_Is_NMD")) &
        !is.na(get("Exc_Is_NMD"))]
    rowSelected <- rowSelected[get("Inc_Is_NMD") != get("Exc_Is_NMD")]
    res <- rowData(se)$EventName %in% rowSelected$EventName
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_anno_tsl <- function(se, filterObj) {
    rowSelected <- as.data.table(rowData(se))
    rowSelected <- rowSelected[get("Inc_TSL") != "NA" &
        get("Exc_TSL") != "NA"]
    rowSelected[, c("Inc_TSL") := as.numeric(get("Inc_TSL"))]
    rowSelected[, c("Exc_TSL") := as.numeric(get("Exc_TSL"))]
    rowSelected <- rowSelected[get("Inc_TSL") <= filterObj@minimum &
        get("Exc_TSL") <= filterObj@minimum]
    res <- rowData(se)$EventName %in% rowSelected$EventName
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_anno_terminus <- function(se, filterObj) {
    rowSelected <- as.data.table(rowData(se))
    if(!all(c("is_always_first_intron","is_always_last_intron") %in% 
            colnames(rowSelected))) {
        .log(paste(
            "This experiment was collated with an old version of NxtIRFcore.",
            "Rerun CollateData with the current version before using the",
            "terminus filter"
        ), "message")
        return(rep(TRUE, nrow(se)))
    }
    AFE <- rowSelected[get("EventType") == "AFE"]
    ALE <- rowSelected[get("EventType") == "ALE"]
    rowSelected <- rowSelected[!(get("EventType") %in% c("ALE", "AFE"))]
    AFE = AFE[get("is_always_first_intron") == TRUE]
    ALE = ALE[get("is_always_last_intron") == TRUE]
    res <- rowData(se)$EventName %in% c(rowSelected$EventName, 
        ALE$EventName, AFE$EventName)
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_anno_mxe <- function(se, filterObj) {
    rowSelected <- as.data.table(rowData(se))
    MXE <- rowSelected[get("EventType") == "MXE"]
    rowSelected <- rowSelected[get("EventType") != "MXE"]
    cas_A <- .runFilter_anno_mxe_gr_casette(MXE$Event1a, MXE$Event2a)
    cas_B <- .runFilter_anno_mxe_gr_casette(MXE$Event1b, MXE$Event2b)
    OL <- findOverlaps(cas_A, cas_B)
    OL <- OL[from(OL) == to(OL)]
    MXE_exclude <- (seq_len(nrow(MXE)) %in% from(OL))
    MXE <- MXE[!MXE_exclude]

    res <- rowData(se)$EventName %in% c(rowSelected$EventName, MXE$EventName)        
    res[!(rowData(se)$EventType %in% filterObj@EventTypes)] <- TRUE
    return(res)
}

.runFilter_anno_mxe_gr_casette <- function(coord1, coord2) {
    if(length(coord1) != length(coord2))
        .log("INTERNAL ERROR: two MXE coord vectors must be of equal size")
    gr1 = CoordToGR(coord1)
    gr1$ID <- as.character(seq_len(length(gr1)))
    gr2 = CoordToGR(coord2)
    gr2$ID <- as.character(seq_len(length(gr2)))
    grbind <- c(gr1, gr2)
    return(unlist(
        .grlGaps(GenomicRanges::split(grbind, grbind$ID))
    ))
}