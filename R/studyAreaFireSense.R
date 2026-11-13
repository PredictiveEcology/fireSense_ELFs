#' Can this run fit an ELF that has no stored SpreadFit?
#'
#' Only when some module in the run has a `doFit` that is not `FALSE` (after its deprecated aliases,
#' `fireSenseUtils::resolveDoFit()`). A run with no fit module (prediction only) cannot fit.
#'
#' @param sim A `simList`.
#' @return logical(1).
#' @keywords internal
.fitsAllowed <- function(sim) {
  orNA <- function(x) if (is.null(x)) NA else x
  doFit <- lapply(SpaDES.core::params(sim), function(p) {
    if (!"doFit" %in% names(p)) return(NULL)
    fireSenseUtils::resolveDoFit(p$doFit, orNA(p$refitExisting), orNA(p$stopIfNoPreRunFit), message = FALSE)
  })
  doFit <- unlist(doFit)
  length(doFit) > 0L && !all(doFit %in% FALSE)
}

#' Stop when a supplied `studyArea` leaves out part of `studyArea_fireSense`
#'
#' Every module simulates over `studyArea`, so a `studyArea` smaller than `studyArea_fireSense` (often the
#' unbuffered area of interest) would simulate fire without its buffer.
#'
#' @param studyArea,studyArea_fireSense `SpatVector` or `sf` polygons.
#' @param tolerance Share of `studyArea_fireSense` that may lie outside `studyArea` (edge slivers).
#' @return `invisible(NULL)`, or an error.
#' @keywords internal
.assertStudyAreaCovers <- function(studyArea, studyArea_fireSense, tolerance = 0.001) {
  asVect <- function(x) if (inherits(x, "SpatVector")) x else terra::vect(x)
  sa <- terra::aggregate(asVect(studyArea))
  saFS <- terra::aggregate(terra::project(asVect(studyArea_fireSense), sa))
  outside <- terra::erase(saFS, sa)
  share <- if (length(outside)) sum(terra::expanse(outside)) / sum(terra::expanse(saFS)) else 0
  if (share > tolerance)
    stop("fireSense_ELFs: `studyArea` does not cover `studyArea_fireSense` (", round(100 * share, 1),
         "% of it is outside). Every module simulates over `studyArea`, so fire would have no buffer. ",
         "Make `studyArea` the buffered area, e.g. `studyArea = studyArea_fireSense`.", call. = FALSE)
  invisible(NULL)
}

#' The error for ELFs in `studyArea_fireSense` that have no stored SpreadFit and cannot be fitted
#'
#' @param missing character; the ELFs without a fit.
#' @param fitted character; the ELFs of the study area that have one.
#' @return An error, always.
#' @keywords internal
.stopNoFits <- function(missing, fitted) {
  stop("fireSense_ELFs: no stored SpreadFit for ELF(s) ", paste(missing, collapse = ", "),
       " in `studyArea_fireSense`, and `doFit` is FALSE, so they cannot be fitted.",
       if (length(fitted))
         paste0(" ELF(s) ", paste(fitted, collapse = ", "), " have fits. To run only over those, rerun with ",
                "`params = list(fireSense_ELFs = list(maskToELFsWithFits = TRUE))`: `studyArea` and ",
                "`rasterToMatch` are then cropped and masked to them.")
       else " None of its ELFs has a fit.",
       call. = FALSE)
}
