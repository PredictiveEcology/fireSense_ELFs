## Fire records are fetched and read as fireSense_dataPrepFit reads them for the fit
## (fireSense_dataPrepFit/R/fireRecords.R): archives through reproducible::preProcess(), shapefiles
## through fireregimetools, fires of every size. So the gate and the fit count the same fires.

#' Path to the shapefile in a fire-record archive
#'
#' Downloads the archive if needed. The shapefile's name carries the release, so
#' callers key their Cache on the name.
#'
#' @param url URL of the archive.
#' @param destinationPath Directory to download and extract into.
#' @param ... Passed to `reproducible::preProcess()`.
#'
#' @return Character path(s) of the `.shp` file(s) in the archive.
fireRecordShapefile <- function(url, destinationPath, ...) {
  files <- reproducible::preProcess(url = url, destinationPath = destinationPath, fun = NA, ...)$targetFilePath
  grep("\\.shp$", files, value = TRUE)
}

#' Count fires per ELF and merge ELFs with too few
#'
#' Merges each ELF with too few fires with a neighbour that shares its base
#' (`fireSenseUtils::ELFmergePlan()`). Arctic ELFs (`fireSenseUtils::ELFsArctic()`)
#' are neither counted nor merged.
#'
#' @param ELFs List from `fireSenseUtils::makeELFs()`.
#' @param fireYears Integer vector of years to count fires over.
#' @param pixelAreaHa Area of one pixel of the ELF rasters, in ha.
#' @param nfdbShp Path to the NFDB fire points shapefile.
#' @param nbacShp Path to the NBAC fire polygons shapefile.
#' @param minNaturalIgnitions Fewer natural-cause ignitions than this is too few.
#' @param minFirePolygons Fewer fire polygons than this is too few.
#'
#' @return List: `ELFs` (the merged maps), `status` (`fireSenseUtils::ELFfitStatus()`),
#'   `plan` (`fireSenseUtils::ELFmergePlan()`) and `excluded` (names of ELFs not fitted).
fewFireELFs <- function(ELFs, fireYears, pixelAreaHa, nfdbShp, nbacShp,
                        minNaturalIgnitions = 50, minFirePolygons = 50) {
  ## ecozones 1 and 2 are out permanently: not counted, not merged (fireSenseUtils::ELFsArctic())
  ids <- setdiff(names(ELFs$rasWhole), fireSenseUtils::ELFsArctic(names(ELFs$rasWhole)))
  rasWhole <- terra::rast(unname(ELFs$rasWhole[ids]))
  names(rasWhole) <- ids
  studyArea <- terra::as.polygons(terra::ext(rasWhole), crs = terra::crs(rasWhole))

  points <- fireregimetools::load_nfdb_points(nfdbShp, study_area = studyArea,
                                              fire_years = fireYears, min_size_ha = 0)
  polys <- fireregimetools::load_nbac_polys(nbacShp, study_area = studyArea,
                                            fire_years = fireYears, min_size_ha = 0)
  counts <- fireSenseUtils::ELFfireCounts(rasWhole, points, polys, fireYears, pixelAreaHa)
  status <- fireSenseUtils::ELFfitStatus(counts, minNaturalIgnitions = minNaturalIgnitions,
                                         minFirePolygons = minFirePolygons)
  plan <- fireSenseUtils::ELFmergePlan(status, fireSenseUtils::ELFneighbours(rasWhole),
                                       minNaturalIgnitions = minNaturalIgnitions,
                                       minFirePolygons = minFirePolygons)
  for (i in seq_len(nrow(plan))) {
    message("fireSense_ELFs: ", plan$action[i], " ", paste(plan$members[[i]], collapse = " + "),
            if (plan$action[i] == "merge") paste0(" -> ", plan$ELF[i]), " (", plan$reason[i], ")")
  }
  list(ELFs = fireSenseUtils::mergeELFs(ELFs, plan), status = status, plan = plan,
       excluded = fireSenseUtils::ELFsSkipped(plan))
}
