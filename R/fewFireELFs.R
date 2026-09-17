## ELFs with too few fires: count the fires in every ELF, merge each thin ELF with a neighbour that
## shares its base, and list the ones that still cannot be fitted (fireSenseUtils::ELFmergePlan()).
## Eliot, 2026-09-14: "The ELFs that have too few fires need to have the possibility of being merged
## with a neighbor."
##
## Fire records are fetched and read as fireSense_dataPrepFit reads them for the fit
## (fireSense_dataPrepFit/R/fireRecords.R): archives through reproducible::preProcess(), shapefiles
## through fireregimetools, fires of every size. So the gate and the fit count the same fires.

## The shapefile in the fire-record archive at `url`, downloaded into `destinationPath` if needed. Its
## name carries the release, so callers key their Cache on the name.
fireRecordShapefile <- function(url, destinationPath, ...) {
  files <- reproducible::preProcess(url = url, destinationPath = destinationPath, fun = NA, ...)$targetFilePath
  grep("\\.shp$", files, value = TRUE)
}

## Fire status of every ELF, the merge plan, the merged maps and the ELFs not fitted.
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
