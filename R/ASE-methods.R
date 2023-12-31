#' Use Limma, DESeq2 or DoubleExpSeq to test for differential Alternative
#' Splice Events
#'
#' @details
#'
#' Using **limma**, NxtIRF models included and excluded counts as log-normal
#' distributed, whereas
#' using **DESeq2**, NxtIRF models included and excluded counts as negative
#' binomial distributed with dispersion shrinkage according to their mean count
#' expressions.
#' For **limma** and **DESeq2**, differential ASE are considered as the
#' "interaction" between included and excluded splice counts for each sample.
#'  See [this vignette](https://rpubs.com/mikelove/ase) for an explanation of
#' how this is done.
#'
#' Using **DoubleExpSeq**, included and excluded counts are modelled using
#' the generalized beta prime distribution, using empirical Bayes shrinkage
#' to estimate dispersion.
#'
#' **EventType** are as follow:
#' * `IR` = (novel) intron retention
#' * `MXE` = mutually exclusive exons
#' * `SE` = skipped exons
#' * `AFE` = alternate first exon
#' * `ALE` = alternate last exon
#' * `A5SS` = alternate 5'-splice site
#' * `A3SS` = alternate 3'-splice site
#' * `RI` = (known / annotated) intron retention.
#'
#' NB: NxtIRF separately considers known "RI" and novel "IR" events separately:
#' * **IR** novel events are calculated using the IRFinder method, whereby
#' spliced transcripts are **all** isoforms that do not retain the intron, as
#' estimated via the `SpliceMax` and `SpliceOverMax` methods
#' - see [CollateData].
#' * **RI** known retained introns are those that lie completely within a
#' single exon of another transcript.
#' (NB: in NxtIRFcore v1.1.1 and later, this encompasses exons from any
#' transcript, including `retained_intron` and `sense_intronic` transcripts).
#' RI's are calculated by considering the specific
#' spliced intron as a binary event paired with its retention. The spliced
#' abundance is calculated exclusively by splice reads mapped to the
#' specific intron boundaries. Known retained introns are those where the
#' intron retaining transcript is an **annotated** transcript.
#' In NxtIRFcore `version < 1.1.1`, 
#' the IR-transcript's `transcript_biotype` must not be
#' an `retained_intron` or `sense_intronic`.
#'
#' NxtIRF considers "included" counts as those that represent abundance of the
#' "included" isoform, whereas "excluded" counts represent the abundance of the
#' "excluded" isoform.
#' For consistency, it applies a convention whereby
#' the "included" transcript is one where its splice junctions
#' are by definition shorter than those of "excluded" transcripts.
#' Specifically, this means the included / excluded isoforms are as follows:
#'
#' | EventType | Included | Excluded |
#' | :---: | :---: | :---: |
#' | IR or RI | Intron Retention | Spliced Intron |
#' | MXE | Upstream exon inclusion | Downstream exon inclusion |
#' | SE | Exon inclusion | Exon skipping |
#' | AFE | Downstream exon usage | Upstream exon usage |
#' | ALE | Upstream exon usage | Downstream exon usage |
#' | A5SS | Downstream 5'-SS | Upstream 5'-SS |
#' | A3SS | Upstream 3'-SS | Downstream 3'-SS |
#'
#'
#' @param se The \linkS4class{NxtSE} object created by `MakeSE()`. To reduce
#'   runtime and avoid excessive multiple testing, consider filtering
#'   the object using [apply_filters]
#' @param test_factor The condition type which contains the
#'   contrasting variable
#' @param test_nom The nominator condition to test for differential ASE. Usually
#'   the "treatment" condition
#' @param test_denom The denominator condition to test against for differential
#'   ASE. Usually the "control" condition
#' @param batch1,batch2 (Optional, limma and DESeq2 only) One or two condition
#'   types containing batch information to account for.
#' @param filter_antiover,filter_antinear Whether to remove novel IR events that
#'   overlap over or near anti-sense genes. Default will exclude antiover but
#'   not antinear introns. These are ignored if stranded RNA-seq protocols are
#'   used.
#' @param n_threads (DESeq2 only) How many threads to use for DESeq2
#'   based analysis.
#' @return A data table containing the following:
#'   * EventName: The name of the ASE event. This identifies each ASE
#'     in downstream functions including [make_diagonal], [make_matrix],
#'     and [Plot_Coverage]
#'   * EventType: The type of event. See details section above.
#'   * EventRegion: The genomic coordinates the event occupies. This spans the
#'     most upstream and most downstream splice junction involved in the ASE,
#'     and is use to guide the [Plot_Coverage] function.
#'   * NMD_direction: Indicates whether one isoform is a NMD substrate. +1 means
#'     included isoform is NMD, -1 means the excluded isoform is NMD, and 0
#'     means there is no change in NMD status (i.e. both / neither are NMD)
#'   * AvgPSI_nom, Avg_PSI_denom: the average percent spliced in / percent
#'     IR levels for the two conditions being contrasted. `nom` and `denom` in
#'     column names are replaced with the condition names
#'
#'   **limma specific output**
#'   * logFC, AveExpr, t, P.Value, adj.P.Val, B: limma topTable columns of
#'     differential ASE. See [limma::topTable] for details.
#'   * inc/exc_(logFC, AveExpr, t, P.Value, adj.P.Val, B): limma results
#'     for differential testing for raw included / excluded counts only
#'
#'   **DESeq2 specific output**
#'   * baseMean, log2FoldChange, lfcSE, stat, pvalue, padj:
#'     DESeq2 results columns for differential ASE; see [DESeq2::results] for
#'     details.
#'   * inc/exc_(baseMean, log2FoldChange, lfcSE, stat, pvalue, padj):
#'     DESeq2 results for differential testing for
#'     raw included / excluded counts only
#'
#'   **DoubleExp specific output**
#'   * MLE_nom, MLE_denom: Expectation values for the two groups. `nom` and
#'     `denom` in column names are replaced with the condition names
#'   * MLE_LFC: Log2-fold change of the MLE
#'   * P.Value, adj.P.Val: Nominal and BH-adjusted P values
#'   * n_eff: Number of effective samples (i.e. non-zero or non-unity PSI)
#'   * mDepth: Mean Depth of splice coverage in each of the two groups.
#'   * Dispersion_Reduced, Dispersion_Full: Dispersion values for reduced and
#'     full models. See [DoubleExpSeq::DBGLM1] for details.
#' @examples
#' # see ?MakeSE on example code of generating this NxtSE object
#' se <- NxtIRF_example_NxtSE()
#'
#' colData(se)$treatment <- rep(c("A", "B"), each = 3)
#'
#' require("limma")
#' res_limma <- limma_ASE(se, "treatment", "A", "B")
#'
#' require("DoubleExpSeq")
#' res_DES <- DoubleExpSeq_ASE(se, "treatment", "A", "B")
#' \dontrun{
#'
#' require("DESeq2")
#' res_DESeq <- DESeq_ASE(se, "treatment", "A", "B")
#' }
#' @name ASE-methods
#' @references
#' Ritchie ME, Phipson B, Wu D, Hu Y, Law CW, Shi W, Smyth GK (2015).
#' 'limma powers differential expression analyses for RNA-sequencing and
#' microarray studies.' Nucleic Acids Research, 43(7), e47.
#' \url{https://doi.org/10.1093/nar/gkv007}
#'
#' Love MI, Huber W, Anders S (2014). 'Moderated estimation of fold change and
#' dispersion for RNA-seq data with DESeq2.' Genome Biology, 15, 550.
#' \url{https://doi.org/10.1186/s13059-014-0550-8}
#'
#' Ruddy S, Johnson M, Purdom E (2016). 'Shrinkage of dispersion parameters in
#' the binomial family, with application to differential exon skipping.'
#' Ann. Appl. Stat. 10(2): 690-725.
#' \url{https://doi.org/10.1214/15-AOAS871}
#' @md
NULL

#' @describeIn ASE-methods Use limma to perform differential ASE analysis of
#'   a filtered NxtSE object
#' @export
limma_ASE <- function(se, test_factor, test_nom, test_denom,
        batch1 = "", batch2 = "",
        filter_antiover = TRUE, filter_antinear = FALSE) {

    .check_package_installed("limma", "3.44.0")
    .ASE_check_args(colData(se), test_factor,
        test_nom, test_denom, batch1, batch2)
    se_use <- .ASE_filter(
        se, filter_antiover, filter_antinear)

    .log("Performing limma contrast for included / excluded counts separately",
        "message")
    res.limma2 <- .ASE_limma_contrast(se_use,
        test_factor, test_nom, test_denom,
        batch1, batch2)
    res.inc <- res.limma2[grepl(".Included", get("EventName"))]
    res.inc[, c("EventName") :=
        sub(".Included","",get("EventName"), fixed=TRUE)]
    res.inc <- res.inc[get("AveExpr") > 1]   # Filter as 0/5 is not diff to 0/10
    res.exc <- res.limma2[grepl(".Excluded", get("EventName"))]
    res.exc[, c("EventName") :=
        sub(".Excluded","",get("EventName"), fixed=TRUE)]
    res.exc <- res.exc[get("AveExpr") > 1]

    .log("Performing limma contrast for included / excluded counts together",
        "message")
    rowData <- as.data.frame(rowData(se_use))
    se_use <- se_use[rowData$EventName %in% res.inc$EventName &
        rowData$EventName %in% res.exc$EventName,]
    res.ASE <- .ASE_limma_contrast_ASE(se_use,
        test_factor, test_nom, test_denom,
        batch1, batch2)
    res.ASE[res.inc, on = "EventName",
        paste("Inc", colnames(res.inc)[seq_len(6)], sep=".") :=
        list(get("i.logFC"), get("i.AveExpr"), get("i.t"),
            get("i.P.Value"), get("i.adj.P.Val"), get("i.B"))]
    res.ASE[res.exc, on = "EventName",
        paste("Exc", colnames(res.exc)[seq_len(6)], sep=".") :=
        list(get("i.logFC"), get("i.AveExpr"), get("i.t"),
            get("i.P.Value"), get("i.adj.P.Val"), get("i.B"))]
    setorderv(res.ASE, "B", order = -1)
    res.ASE <- .ASE_add_diag(res.ASE, se_use, test_factor, test_nom, test_denom)
    return(res.ASE)
}

#' @describeIn ASE-methods Use DESeq2 to perform differential ASE analysis of
#'   a filtered NxtSE object
#' @export
DESeq_ASE <- function(se, test_factor, test_nom, test_denom,
        batch1 = "", batch2 = "",
        n_threads = 1,
        filter_antiover = TRUE, filter_antinear = FALSE) {
    .check_package_installed("DESeq2", "1.30.0")
    .ASE_check_args(colData(se), test_factor,
        test_nom, test_denom, batch1, batch2)
    BPPARAM_mod <- .validate_threads(n_threads)
    se_use <- .ASE_filter(
        se, filter_antiover, filter_antinear)

    .log("Performing DESeq2 contrast for included / excluded counts separately",
        "message")
    res.IncExc <- .ASE_DESeq2_contrast(se_use,
        test_factor, test_nom, test_denom,
        batch1, batch2, BPPARAM_mod)
    res.inc <- res.IncExc[grepl(".Included", get("EventName"))]
    res.inc[, c("EventName") :=
        sub(".Included","",get("EventName"), fixed=TRUE)]
    res.exc <- res.IncExc[grepl(".Excluded", get("EventName"))]
    res.exc[, c("EventName") :=
        sub(".Excluded","",get("EventName"), fixed=TRUE)]

    .log("Performing DESeq2 contrast for included / excluded counts separately",
        "message")
    rowData <- as.data.frame(rowData(se_use))
    se_use <- se_use[rowData$EventName %in% res.inc$EventName &
        rowData$EventName %in% res.exc$EventName,]
    res.ASE <- .ASE_DESeq2_contrast_ASE(se_use,
        test_factor, test_nom, test_denom,
        batch1, batch2, BPPARAM_mod)
    res.ASE[res.inc, on = "EventName",
        paste("Inc", colnames(res.inc)[seq_len(6)], sep=".") :=
        list(get("i.baseMean"), get("i.log2FoldChange"), get("i.lfcSE"),
            get("i.stat"), get("i.pvalue"), get("i.padj"))]
    res.ASE[res.exc, on = "EventName",
        paste("Exc", colnames(res.exc)[seq_len(6)], sep=".") :=
        list(get("i.baseMean"), get("i.log2FoldChange"), get("i.lfcSE"),
            get("i.stat"), get("i.pvalue"), get("i.padj"))]
    res.ASE <- res.ASE[!is.na(get("pvalue"))]
    setorder(res.ASE, "pvalue")
    res.ASE <- .ASE_add_diag(res.ASE, se_use, test_factor, test_nom, test_denom)
    return(res.ASE)
}

#' @describeIn ASE-methods Use DoubleExpSeq to perform differential ASE analysis
#'   of a filtered NxtSE object (uses double exponential beta-binomial model)
#'   to estimate group dispersions, followed by LRT
#' @export
DoubleExpSeq_ASE <- function(se, test_factor, test_nom, test_denom,
        # batch1 = "", batch2 = "",
        filter_antiover = TRUE, filter_antinear = FALSE) {

    .check_package_installed("DoubleExpSeq", "1.1")
    .ASE_check_args(colData(se), test_factor,
        test_nom, test_denom, "", "")
    se_use <- .ASE_filter(
        se, filter_antiover, filter_antinear)

    .log("Running DoubleExpSeq::DBGLM1() on given data", "message")
    res.ASE <- .ASE_DoubleExpSeq_contrast_ASE(se_use,
        test_factor, test_nom, test_denom)

    res.cols <- c(
        paste("MLE", test_nom, sep="_"), paste("MLE", test_denom, sep="_"),
        "P.Value", "adj.P.Val", "n_eff",
        paste("mDepth", test_nom, sep="_"),
        paste("mDepth", test_denom, sep="_"),
        "Dispersion_Reduced", "Dispersion_Full"
    )
    colnames(res.ASE)[-1] <- res.cols

    res.ASE[, c("MLE_LFC") := (
        qlogis(res.ASE[,get(paste("MLE", test_nom, sep="_"))]) -
        qlogis(res.ASE[,get(paste("MLE", test_denom, sep="_"))])
    ) / log(2)]

    res.ASE <- res.ASE[, c("EventName", res.cols[c(1,2)], "MLE_LFC",
        res.cols[seq(3,9)]), with = FALSE]

    res.ASE <- res.ASE[!is.na(get("P.Value"))]
    setorderv(res.ASE, "P.Value")
    res.ASE <- .ASE_add_diag(res.ASE, se_use, test_factor, test_nom, test_denom)
    return(res.ASE)
}

############################## INTERNALS #######################################
# helper functions:

# Check arguments are valid
.ASE_check_args <- function(colData, test_factor,
        test_nom, test_denom, batch1, batch2, n_threads) {
    if(!is_valid(test_factor) | !is_valid(test_nom) | !is_valid(test_denom)) {
        .log("test_factor, test_nom, test_denom must be defined")
    }
    if(!(test_factor %in% colnames(colData))) {
        .log("test_factor is not a condition in colData")
    }
    if(!any(colData[, test_factor] == test_nom)) {
        .log("test_nom is not found in any samples")
    }
    if(!any(colData[, test_factor] == test_denom)) {
        .log("test_denom is not found in any samples")
    }
    if(batch1 != "") {
        if(!(batch1 %in% colnames(colData))) {
            .log("batch1 is not a condition in colData")
        }
        if(test_factor == batch1) {
            .log("batch1 and test_factor are the same")
        }
    }
    if(batch2 != "") {
        if(!(batch2 %in% colnames(colData))) {
            .log("batch2 is not a condition in colData")
        }
        if(test_factor == batch2) {
            .log("batch2 and test_factor are the same")
        }
    }
    if(batch1 != "" & batch2 != "") {
        if(batch1 == batch2) {
            .log("batch1 and batch2 are the same")
        }
    }
    return(TRUE)
}

# Filter antiover and antinear
.ASE_filter <- function(se, filter_antiover, filter_antinear) {
    se_use <- se
    if(filter_antiover) {
        se_use <- se_use[
            !grepl("anti-over", rowData(se_use)$EventName),]
    }
    if(filter_antinear) {
        se_use <- se_use[
            !grepl("anti-near", rowData(se_use)$EventName),]
    }
    se_use <- se_use[
        !grepl("known-exon", rowData(se_use)$EventName),]
    return(se_use)
}

.ASE_limma_contrast <- function(se, test_factor, test_nom, test_denom,
        batch1, batch2) {
    countData <- rbind(assay(se, "Included"),
        assay(se, "Excluded"))
    rowData <- as.data.frame(rowData(se))
    colData <- colData(se)
    rownames(colData) <- colnames(se)
    colnames(countData) <- rownames(colData)
    rownames(countData) <- c(
        paste(rowData$EventName, "Included", sep="."),
        paste(rowData$EventName, "Excluded", sep=".")
    )

    condition_factor <- factor(colData[, test_factor])
    if(batch2 != "") {
        batch2_factor <- colData[, batch2]
        batch1_factor <- colData[, batch1]
        design1 <- model.matrix(~0 + batch1_factor + batch2_factor +
            condition_factor)
    } else if(batch1 != "") {
        batch1_factor <- colData[, batch1]
        design1 <- model.matrix(~0 + batch1_factor + condition_factor)
    } else {
        design1 <- model.matrix(~0 + condition_factor)
    }
    contrast <- rep(0, ncol(design1))
    contrast_a <- paste0("condition_factor", test_nom)
    contrast_b <- paste0("condition_factor", test_denom)
    contrast[which(colnames(design1) == contrast_b)] <- -1
    contrast[which(colnames(design1) == contrast_a)] <- 1

    countData_use <- limma::voom(countData, design1)
    fit <- limma::lmFit(countData_use$E, design = design1)
    fit <- limma::contrasts.fit(fit, contrast)
    fit <- limma::eBayes(fit)

    res <- limma::topTable(fit, number = nrow(countData_use$E))
    res$EventName <- rownames(res)

    res$AveExpr <- res$AveExpr - min(res$AveExpr)
    res <- as.data.table(res)
    return(res)
}

.ASE_limma_contrast_ASE <- function(se, test_factor, test_nom, test_denom,
        batch1, batch2) {
    countData <- cbind(assay(se, "Included"),
        assay(se, "Excluded"))

    rowData <- as.data.frame(rowData(se))
    colData <- as.data.frame(colData(se))
    colData <- rbind(colData, colData)
    rownames(colData) <- c(
        paste(colnames(se), "Included", sep="."),
        paste(colnames(se), "Excluded", sep=".")
    )
    colData$ASE <- rep(c("Included", "Excluded"), each = ncol(se))
    colnames(countData) <- rownames(colData)
    rownames(countData) <- rowData$EventName

    condition_factor <- factor(colData[, test_factor])
    ASE <- colData[, "ASE"]
    if(batch2 != "") {
        batch2_factor <- colData[, batch2]
        batch1_factor <- colData[, batch1]
        design1 <- model.matrix(~0 + batch1_factor + batch2_factor +
            condition_factor + condition_factor:ASE)
    } else if(batch1 != "") {
        batch1_factor <- colData[, batch1]
        design1 <- model.matrix(~0 + batch1_factor + condition_factor +
            condition_factor:ASE)
    } else {
        design1 <- model.matrix(~0 + condition_factor + condition_factor:ASE)
    }
    colnames(design1) <- sub(":",".",colnames(design1))
    contrast <- rep(0, ncol(design1))
    contrast_a <- paste0("condition_factor", test_nom, ".ASEIncluded")
    contrast_b <- paste0("condition_factor", test_denom, ".ASEIncluded")
    contrast[which(colnames(design1) == contrast_b)] <- -1
    contrast[which(colnames(design1) == contrast_a)] <- 1

    countData_use <- limma::voom(countData, design1, lib.size = 1)

    fit <- limma::lmFit(countData_use$E, design = design1)

    fit <- limma::contrasts.fit(fit, contrast)
    fit <- limma::eBayes(fit)

    res <- limma::topTable(fit, number = nrow(countData_use$E))
    res$EventName <- rownames(res)
    res$AveExpr <- res$AveExpr - min(res$AveExpr)
    res <- as.data.table(res)
    return(res)
}

.ASE_DESeq2_contrast <- function(se, test_factor, test_nom, test_denom,
        batch1, batch2, BPPARAM) {
    countData <- rbind(assay(se, "Included"),
        assay(se, "Excluded"))
    rowData <- as.data.frame(rowData(se))
    colData <- colData(se)
    rownames(colData) <- colnames(se)
    colnames(countData) <- rownames(colData)
    rownames(countData) <- c(
        paste(rowData$EventName, "Included", sep="."),
        paste(rowData$EventName, "Excluded", sep=".")
    )
    if(batch2 != "") {
        dds_formula <- paste0("~", paste(
            batch1, batch2, test_factor,
            sep="+"))

    } else if(batch1 != "") {
        dds_formula <- paste0("~", paste(
            batch1, test_factor,
            sep="+"))
    } else {
        dds_formula <- paste0("~", test_factor)
    }

    countData <- as.matrix(countData)
    mode(countData) <- "integer"
    dds <- DESeq2::DESeqDataSetFromMatrix(
        countData = round(countData),
        colData = .DESeq_colData_sanitise(colData),
        design = as.formula(dds_formula)
    )
    message("DESeq_ASE: Profiling expression of Included and Excluded counts")

    dds <- DESeq2::DESeq(dds, parallel = TRUE, BPPARAM = BPPARAM)
    res <- as.data.frame(DESeq2::results(dds,
        contrast = c(test_factor, test_nom, test_denom),
        parallel = TRUE, BPPARAM = BPPARAM)
    )
    res$EventName <- rownames(res)
    return(as.data.table(res))
}

.ASE_DESeq2_contrast_ASE <- function(se, test_factor, test_nom, test_denom,
        batch1, batch2, BPPARAM) {
    countData <- cbind(assay(se, "Included"),
        assay(se, "Excluded"))
    rowData <- as.data.frame(rowData(se))
    colData <- as.data.frame(colData(se))
    colData <- rbind(colData, colData)
    rownames(colData) <- c(
        paste(colnames(se), "Included", sep="."),
        paste(colnames(se), "Excluded", sep=".")
    )
    colData$ASE <- rep(c("Included", "Excluded"), each = ncol(se))
    colnames(countData) <- rownames(colData)
    rownames(countData) <- rowData$EventName

    if(batch2 != "") {
        dds_formula <- paste0("~", paste(
            batch1, batch2, test_factor,
                paste0(test_factor, ":ASE"),
            sep="+"))
    } else if(batch1 != "") {
        dds_formula <- paste0("~", paste(
            batch1, test_factor,
            paste0(test_factor, ":ASE"),
            sep="+"))
    } else {
        dds_formula <- paste0("~", paste(
            test_factor,
            paste0(test_factor, ":ASE"),
            sep="+"))
    }
    countData <- as.matrix(countData)
    mode(countData) <- "integer"
    dds <- DESeq2::DESeqDataSetFromMatrix(
        countData = countData,
        colData = .DESeq_colData_sanitise(colData),
        design = as.formula(dds_formula)
    )
    message("DESeq_ASE: Profiling differential ASE")

    dds <- DESeq2::DESeq(dds, parallel = TRUE, BPPARAM = BPPARAM)
    res <- as.data.frame(DESeq2::results(dds,
        list(
            paste0(test_factor, test_nom, ".ASEIncluded"),
            paste0(test_factor, test_denom, ".ASEIncluded")
        ),
        parallel = TRUE, BPPARAM = BPPARAM)
    )
    res$EventName <- rownames(res)
    return(as.data.table(res))
}

.ASE_DoubleExpSeq_contrast_ASE <- function(se, test_factor,
    test_nom, test_denom) {

    # NB add pseudocounts
    pseudocount <- 1
    y <- assay(se, "Included") + pseudocount
    m <- assay(se, "Included") + assay(se, "Excluded") + 2 * pseudocount

    colData <- as.data.frame(colData(se))
    groups <- factor(colData[, test_factor])
    shrink.method <- "WEB"

    contrast.first <- which(levels(groups) == test_nom)
    contrast.second <- which(levels(groups) == test_denom)

    res <- DoubleExpSeq::DBGLM1(
        as.matrix(y), as.matrix(m), groups, shrink.method,
        contrast=c(contrast.first,contrast.second),
        fdr.level=0.05, use.all.groups=TRUE)

    return(cbind(data.table(EventName = rownames(res$All)),
        as.data.table(res$All)))
}

.ASE_add_diag <- function(res, se, test_factor, test_nom, test_denom) {
    rowData <- as.data.frame(rowData(se))
    rowData.DT <- as.data.table(rowData[,
        c("EventName","EventType","EventRegion", "NMD_direction")])
    diag <- make_diagonal(se, res$EventName,
        test_factor, test_nom, test_denom)
    colnames(diag)[2:3] <- c(paste0("AvgPSI_", test_nom),
        paste0("AvgPSI_", test_denom))
    res <- cbind(
        res[,c("EventName")],
        as.data.table(diag[,2:3]),
        res[,-c("EventName")]
    )
    res <- rowData.DT[res, on = "EventName"]
    return(res)
}

.DESeq_colData_sanitise <- function(colData) {
    for(i in seq_len(ncol(colData))) {
        if(is(colData[,i], "character")) {
            colData[, i] <- factor(colData[, i])
        }
    }
    colData
}
