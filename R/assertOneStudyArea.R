#' Refuse to run when `studyAreaLarge` and `.ELFind` describe different study areas
#'
#' @description
#' This module can take its study area from either end. `.ELFind` names one
#' ecologically like fire regime, which is what the fitting workflow wants;
#' `studyAreaLarge` is a polygon whose intersecting ELFs are used, which is what
#' the prediction workflow wants. Supplying both is ambiguous, and the module
#' resolved it silently: `studyAreaLarge` won, `.ELFind` was never read on that
#' path, yet `.studyAreaName` -- and therefore every input and output folder --
#' was still named from `.ELFind`.
#'
#' On 2026-09-07/08 that produced five "different" ELF fits which were in fact
#' the same study area under five names. Nothing in the logs said so; it was
#' caught only because the five DEoptim objective values came out nearly
#' identical when the areas differ four-fold in size. Failing loudly here costs
#' one run; failing silently costs a week of compute and the trust in its
#' output.
#'
#' @param elfInd character; `sim$.ELFind`.
#' @param elfIndSupplied logical(1); was `.ELFind` supplied by the user, rather
#'   than defaulted by this module's `.inputObjects`? A default carries no
#'   request, so it cannot conflict with anything.
#' @param elfsInStudyAreaLarge character; the ELFs that `studyAreaLarge` covers.
#'
#' @return `invisible(NULL)` when there is no conflict; otherwise an error
#'   naming both study areas.
#' @keywords internal
.assertOneStudyArea <- function(elfInd, elfIndSupplied, elfsInStudyAreaLarge) {
  if (!isTRUE(elfIndSupplied)) return(invisible(NULL))

  elfInd <- as.character(elfInd)
  elfInd <- elfInd[!is.na(elfInd) & nzchar(elfInd)]
  covered <- unique(as.character(elfsInStudyAreaLarge))
  covered <- covered[!is.na(covered) & nzchar(covered)]

  ## The one harmless case: the polygon resolves to exactly the ELF that was
  ## asked for, so both descriptions agree and either could be used.
  if (length(elfInd) && length(covered) && setequal(elfInd, covered))
    return(invisible(NULL))

  stop("fireSense_ELFs was given both `studyAreaLarge` and `.ELFind`, and they describe ",
       "different study areas:\n",
       "  .ELFind:                      ",
       if (length(elfInd)) paste(elfInd, collapse = ", ") else "<empty>", "\n",
       "  studyAreaLarge covers ELF(s): ",
       if (length(covered)) paste(covered, collapse = ", ") else "none", "\n",
       "Supply one or the other: `.ELFind` alone to fit a single ELF, or ",
       "`studyAreaLarge` alone to run whatever ELFs it covers. Supplying both is not a ",
       "way to select an ELF within a larger area -- `studyAreaLarge` decides the area ",
       "while `.ELFind` still names the input and output folders, so the run would be ",
       "labelled with an ELF it did not use.",
       call. = FALSE)
}
