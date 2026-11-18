#' Ledger rows of the ELFs a run touches
#'
#' The one place this module reads the ignition/escape fit ledger written by `fireSense_ignitionFit`,
#' so moving the ledger to another reproducible API changes this function only. With
#' `ignitionFitFilename = "latest"` each ELF's row comes from the newest ledger file that has it
#' (`fireSenseUtils::latestIgnitionFits()`, which needs a Drive folder). A named file is read with
#' `CacheGeo()`, one query per ELF polygon: `CacheGeo()` returns nothing for an area that overlaps an
#' ELF without a row, so a query over the whole area would hide the ELFs that do have one.
#'
#' @param ELFpolys `SpatVector` with one polygon per ELF and its name in field `ELFind`.
#' @param folder The Google Drive folder (url or id) of the ledger; `NULL` keeps a named ledger
#'   local, in `destinationPath`.
#' @param filename `"latest"`, or the name of the ledger file.
#' @param escapeDefinition With `"latest"`, the run's `fireSenseUtils::escapeDefinition()`: fits made under another are
#'   skipped. `NULL`: not checked.
#' @param destinationPath Local folder for the ledger file.
#' @return A `data.frame` with a `polygonID` column and the list-columns
#'   `fireSenseUtils::ignitionFitAdditionalColNamesTxt`, or `NULL` if there is none.
readIgnitionFitRows <- function(ELFpolys, folder, filename, destinationPath, escapeDefinition = NULL) {
  ELFinds <- as.character(ELFpolys$ELFind)
  if (identical(filename, "latest")) {
    return(fireSenseUtils::latestIgnitionFits(folder, destinationPath = destinationPath,
                                              polygonIDs = ELFinds, escapeDefinition = escapeDefinition))
  }
  rows <- lapply(seq_along(ELFinds), function(i) {
    r <- CacheGeo(cloudFolderID = folder, targetFile = filename, destinationPath = destinationPath,
                  domain = sf::st_as_sf(ELFpolys[i]), action = "nothing", useCache = FALSE,
                  bufferOK = TRUE,
                  ## `purge` re-downloads from the cloud copy; a local-only ledger has none, and
                  ## `prepInputs()` then cannot find the local file it just set aside.
                  purge = if (is.null(folder)) FALSE else 7)
    if (is.data.frame(r)) r[as.character(r$polygonID) == ELFinds[i], , drop = FALSE]
  })
  rows <- rows[lengths(rows) > 0L]
  if (length(rows)) do.call(rbind, rows)
}

#' One fitted ignition model and one fitted escape model per ELF
#'
#' @param rows Ledger rows, from [readIgnitionFitRows()].
#' @param ELFinds The ELFs the run touches.
#' @param required If `TRUE`, an ELF without a row is an error naming it. If `FALSE`, ELFs without
#'   a row are left out: a single-ELF run that is about to fit its ELF has none yet.
#' @return `list(ignition =, escape =)`, each a list named by `ELFind`, or both `NULL` when no ELF has
#'   a row and none is required. With `"latest"` rows, each list has attribute `ignitionFitFiles`: the ledger
#'   file of each ELF's fit, named by `ELFind`; and, when the rows are stamped, `ignitionFitWrittenAt`: when each
#'   was written.
ignitionFitLists <- function(rows, ELFinds, required) {
  ELFinds <- as.character(ELFinds)
  idx <- match(ELFinds, as.character(rows$polygonID))
  if (required && anyNA(idx))
    stop("fireSense_ELFs: no ignition/escape fit in the ledger for ELF ",
         paste(ELFinds[is.na(idx)], collapse = ", "),
         ". Fit each with fireSense_ignitionFit before predicting for them.")
  ELFinds <- ELFinds[!is.na(idx)]
  idx <- idx[!is.na(idx)]
  if (!length(idx))
    return(list(ignition = NULL, escape = NULL))
  cols <- fireSenseUtils::ignitionFitAdditionalColNamesTxt
  out <- list(ignition = stats::setNames(rows[[cols[1]]][idx], ELFinds),
              escape = stats::setNames(rows[[cols[2]]][idx], ELFinds))
  ## the ledger file each ELF's fit came from (`latestIgnitionFits()`), for the run's metrics (fireSense_summary)
  files <- attr(rows, "ignitionFitFiles")
  if (!is.null(files)) for (n in names(out)) attr(out[[n]], "ignitionFitFiles") <- files[ELFinds]
  ## and when each was written (reproducible::CacheGeoWrite()'s stamp), so the metrics can tell newer fits from older
  if ("writtenAt" %in% names(rows))
    for (n in names(out)) attr(out[[n]], "ignitionFitWrittenAt") <- stats::setNames(rows$writtenAt[idx], ELFinds)
  out
}
