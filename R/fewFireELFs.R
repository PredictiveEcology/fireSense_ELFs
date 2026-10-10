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

#' Path to the land-cover map the size rule uses
#'
#' SCANFI v2 land cover for 2020 in Canada LCC class codes, the same map and source as
#' `LandR::prepInputs_SCANFI_LCC_FAO()` starts from. The file's name carries its release, so a copy in
#' `destinationPath` or `getOption("reproducible.inputPaths")` is used as it is, with no call to Google Drive;
#' otherwise it is downloaded.
#'
#' @param destinationPath Directory to download into.
#'
#' @return Character path of the `.tif`.
sizeRuleLandCover <- function(destinationPath) {
  source <- LandR:::.scanfiLCCFAOSource(2020, "V2")
  local <- file.path(c(destinationPath, getOption("reproducible.inputPaths")), source$targetFile)
  local <- local[file.exists(local)]
  if (length(local)) return(local[1])
  reproducible::preProcess(url = source$url, targetFile = source$targetFile,
                           destinationPath = destinationPath, fun = NA)$targetFilePath
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
#' @param escapeSizeHa Size (ha) a fire must reach to count as escaped.
#' @param minEscapes Fewer escaped natural fires than this is too few.
#' @param landCoverFile Path to a land-cover map in class codes (SCANFI's), or `NULL`. With
#'   `minRegionAreaKm2` it switches on the size rule.
#' @param minRegionAreaKm2 After the fire-count plan, regions with a core smaller than this (km2) are merged
#'   with a similar neighbour (`fireSenseUtils::ELFsizePlan()`). `NULL` or `NA` turns the rule off.
#' @param maxLandCoverDist,maxBurnRatio How similar a neighbour must be for the size rule: largest land-cover
#'   (Bray-Curtis) distance and largest burn-rate ratio.
#'
#' @return List: `ELFs` (the merged maps), `status` (`fireSenseUtils::ELFfitStatus()`),
#'   `plan` (`fireSenseUtils::ELFmergePlan()`) and `excluded` (names of ELFs not fitted).
fewFireELFs <- function(ELFs, fireYears, pixelAreaHa, nfdbShp, nbacShp,
                        minNaturalIgnitions = 50, minFirePolygons = 50,
                        escapeSizeHa = 50, minEscapes = 5, landCoverFile = NULL,
                        minRegionAreaKm2 = 35000, maxLandCoverDist = 0.35, maxBurnRatio = 6) {
  ## ecozones 1 and 2 are out permanently: not counted, not merged (fireSenseUtils::ELFsArctic())
  ids <- setdiff(names(ELFs$rasWhole), fireSenseUtils::ELFsArctic(names(ELFs$rasWhole)))
  rasWhole <- terra::rast(unname(ELFs$rasWhole[ids]))
  names(rasWhole) <- ids
  studyArea <- terra::as.polygons(terra::ext(rasWhole), crs = terra::crs(rasWhole))

  points <- fireregimetools::load_nfdb_points(nfdbShp, study_area = studyArea,
                                              fire_years = fireYears, min_size_ha = 0)
  polys <- fireregimetools::load_nbac_polys(nbacShp, study_area = studyArea,
                                            fire_years = fireYears, min_size_ha = 0)
  counts <- fireSenseUtils::ELFfireCounts(rasWhole, points, polys, fireYears, pixelAreaHa,
                                          escapeSizeHa = escapeSizeHa)
  status <- fireSenseUtils::ELFfitStatus(counts, minNaturalIgnitions = minNaturalIgnitions,
                                         minFirePolygons = minFirePolygons, minEscapes = minEscapes)
  plan <- fireSenseUtils::ELFmergePlan(status, fireSenseUtils::ELFneighbours(rasWhole),
                                       minNaturalIgnitions = minNaturalIgnitions,
                                       minFirePolygons = minFirePolygons, minEscapes = minEscapes)
  if (!is.null(landCoverFile) && length(minRegionAreaKm2) == 1L && !is.na(minRegionAreaKm2)) {
    ## the size rule sees the regions that remain: fire-count merges applied, skipped ELFs left out
    remaining <- fireSenseUtils::mergeELFs(ELFs, plan)$rasWhole
    keep <- setdiff(names(remaining), c(fireSenseUtils::ELFsSkipped(plan), fireSenseUtils::ELFsArctic(names(remaining))))
    remaining <- terra::rast(unname(remaining[keep]))
    names(remaining) <- keep
    stats <- fireSenseUtils::ELFregionStats(remaining, terra::rast(landCoverFile), firePolys = polys,
                                            fireYears = fireYears)
    merges <- plan[plan$action == "merge", ]
    stats$members <- lapply(stats$ELF, function(id) {
      hit <- match(id, merges$ELF)
      if (is.na(hit)) id else merges$members[[hit]]
    })
    sizePlan <- fireSenseUtils::ELFsizePlan(stats, fireSenseUtils::ELFneighbours(remaining),
                                            minAreaKm2 = minRegionAreaKm2,
                                            maxLandCoverDist = maxLandCoverDist, maxBurnRatio = maxBurnRatio)
    plan <- combinePlans(plan, sizePlan, status)
  }
  for (i in seq_len(nrow(plan))) {
    message("fireSense_ELFs: ", plan$action[i], " ", paste(plan$members[[i]], collapse = " + "),
            if (plan$action[i] == "merge") paste0(" -> ", plan$ELF[i]), " (", plan$reason[i], ")")
  }
  list(ELFs = fireSenseUtils::mergeELFs(ELFs, plan), status = status, plan = plan,
       excluded = fireSenseUtils::ELFsSkipped(plan))
}

#' Add the size merges to the fire-count plan
#'
#' A size merge covers every ELF in its `members`, so a fire-count merge whose members are all in one is
#' replaced by it. Skips stay. The size merges get the fire counts of their members from `status`.
#'
#' @param firePlan Plan from `fireSenseUtils::ELFmergePlan()`.
#' @param sizePlan Plan from `fireSenseUtils::ELFsizePlan()`.
#' @param status `fireSenseUtils::ELFfitStatus()` of the original ELFs.
#'
#' @return A `data.table` in `ELFmergePlan()`'s format.
combinePlans <- function(firePlan, sizePlan, status) {
  if (!nrow(sizePlan)) return(firePlan)
  covered <- vapply(seq_len(nrow(firePlan)), function(i) {
    firePlan$action[i] == "merge" &&
      any(vapply(sizePlan$members, function(m) all(firePlan$members[[i]] %in% m), logical(1)))
  }, logical(1))
  total <- function(col) vapply(sizePlan$members, function(m) sum(status[[col]][match(m, status$ELF)]), status[[col]][1])
  sizeRows <- data.table::data.table(
    action = sizePlan$action, ELF = sizePlan$ELF, members = sizePlan$members,
    naturalIgnitions = total("naturalIgnitions"), escapes = total("escapes"), firePolygons = total("firePolygons"),
    reason = sizePlan$reason)
  data.table::rbindlist(list(firePlan[!covered, ], sizeRows))
}
