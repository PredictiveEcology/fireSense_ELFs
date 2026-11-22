#' The `fitDates` event: the dates of each ELF's latest production fits
#'
#' Writes `ELFfitDates.csv` (`fireSenseUtils::elfFitDates()`: per ELF, the date and ledger file of its latest
#' production spread fit and ignition fit) and the figure `ELFfitDates` (two maps, [plotFitDates()]) to
#' `outputPath(sim)`. The ledgers are the production folders of `fireSenseUtils::spreadFitLedgerFolder()` and
#' `fireSenseUtils::ignitionFitLedgerFolder()`, never an experiment's `testing` folder or an `archived` one,
#' whatever this run's `spreadFitGoogleDriveFolder` says. The ELFs are those of `sim$ELFs` (after the merges).
#'
#' @param sim A `simList` after `init`.
#'
#' @return The `simList`, invisibly.
fitDates <- function(sim) {
  ELFs <- sim$ELFs
  allELFs <- names(ELFs$rasWhole)
  dates <- fireSenseUtils::elfFitDates(destinationPath = inputPath(sim), ELFs = allELFs)
  ## a ledger row of an ELF that has since been merged names an ELF that is no longer on the map
  gone <- setdiff(dates$ELF, allELFs)
  if (length(gone))
    message("fireSense_ELFs: fits of ELFs no longer on the map are left out: ", paste(gone, collapse = ", "))
  dates <- dates[dates$ELF %in% allELFs, ]
  dir.create(outputPath(sim), recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(dates, file.path(outputPath(sim), "ELFfitDates.csv"))

  ## `ELFs` is already merged; the plan then holds only the ELFs left out for too few fires
  plan <- sim$ELFmerges
  plan <- if (is.null(plan)) data.table::data.table(action = character(0), ELF = character(0), members = list())
          else plan[plan$action != "merge", ]
  Plots(fn = plotFitDates, dates = dates, ELFs = ELFs, plan = plan,
        path = outputPath(sim), deviceArgs = list(width = 16, height = 7, units = "in", res = 200),
        filename = "ELFfitDates")
  invisible(sim)
}

#' Two maps of the ELFs: the date of the latest spread fit and of the latest ignition fit
#'
#' [fireSenseUtils::plotELFs()] twice, side by side, on one colour scale: the oldest date red, the newest green;
#' an ELF with no fit is grey.
#'
#' @param dates `fireSenseUtils::elfFitDates()`.
#' @param ELFs,plan As in [fireSenseUtils::plotELFs()].
#'
#' @return Called for its plot.
plotFitDates <- function(dates, ELFs, plan) {
  old <- graphics::par(mfrow = c(1, 2))
  on.exit(graphics::par(old))
  ## one scale for both panels, so a colour means the same date in each
  range <- range(as.numeric(as.Date(c(dates$spreadFitDate, dates$ignitionFitDate))), na.rm = TRUE)
  for (what in c("spread", "ignition")) {
    col <- paste0(what, "FitDate")
    graphics::par(mar = c(1, 1, 3, 1))
    fireSenseUtils::plotELFs(ELFs = ELFs, plan = plan, buffers = FALSE, axes = "none",
                             metrics = dates, metric = col, metricRange = range,
                             metricTitle = paste("latest", what, "fit"),
                             which = dates$ELF[is.na(dates[[col]])], fill = "grey70", whichLabel = "no production fit")
    graphics::title(paste("Latest production", what, "fit"))
  }
}
