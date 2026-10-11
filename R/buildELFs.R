#' Build the national ELF list
#'
#' Everything that produces the national list of ELFs, in one function so `Init()` can cache it as
#' one object: the template raster, the ELF maps (`fireSenseUtils::makeELFs()`), and, unless
#' `fireYears` is `NULL`, the merging of ELFs with too few fires (`fireSenseUtils::fewFireELFs()`).
#' Every raster is brought into memory, so the result holds no file-backed rasters and can be shared
#' through the cloud cache. The seed is set here, so the result does not depend on the caller's RNG state.
#'
#' @param inputPath Where downloads go.
#' @param fireYears,minNaturalIgnitions,minFirePolygons,escapeSizeHa,minEscapes,minRegionAreaKm2,maxLandCoverDist,maxBurnRatio
#'   The module parameters of the same names.
#'
#' @return A list: `ELFs` (after the merges), `ELFsBeforeMerges` (`NULL` when `fireYears` is `NULL`),
#'   `excluded`, `status` and `plan` (the last three `NULL` when `fireYears` is `NULL`).
buildELFs <- function(inputPath, fireYears, minNaturalIgnitions, minFirePolygons, escapeSizeHa,
                      minEscapes, minRegionAreaKm2, maxLandCoverDist, maxBurnRatio) {
  ## The generation of the ELFs has a tiny bit of randomness; we don't actually want this;
  ## the result should be identical every time
  withr::local_seed(123)

  rastTemplate <- ELFtemplateRaster(inputPath)
  ELFs <- fireSenseUtils::makeELFs(rastTemplate, desiredBuffer = 20000, destinationPath = inputPath)

  out <- list(ELFs = ELFs, ELFsBeforeMerges = NULL, excluded = NULL, status = NULL, plan = NULL)
  ## ELFs with too few fires over `fireYears` are merged with a neighbour that shares their base, or
  ## not fitted (fireSenseUtils::ELFmergePlan())
  if (!is.null(fireYears)) {
    landCoverFile <- if (!is.null(minRegionAreaKm2) && !is.na(minRegionAreaKm2))
      fireSenseUtils::sizeRuleLandCover(inputPath)
    fewFire <- fireSenseUtils::fewFireELFs(
      ELFs, fireYears = fireYears, pixelAreaHa = prod(terra::res(rastTemplate)) / 1e4,
      destinationPath = inputPath, nfdbUrl = fireSenseUtils::nfdbPointUrl(),
      nbacUrl = fireSenseUtils::latestNBACUrl(),
      minNaturalIgnitions = minNaturalIgnitions, minFirePolygons = minFirePolygons,
      escapeSizeHa = escapeSizeHa, minEscapes = minEscapes,
      landCoverFile = landCoverFile, minRegionAreaKm2 = minRegionAreaKm2,
      maxLandCoverDist = maxLandCoverDist, maxBurnRatio = maxBurnRatio)
    out <- list(ELFs = fewFire$ELFs, ELFsBeforeMerges = ELFs, excluded = fewFire$excluded,
                status = fewFire$status, plan = fewFire$plan)
  }
  out[c("ELFs", "ELFsBeforeMerges")] <- lapply(out[c("ELFs", "ELFsBeforeMerges")], .elfsToMemory)
  out
}

#' Bring the rasters of an ELF list into memory
#'
#' @param ELFs A list from `fireSenseUtils::makeELFs()`: `rasWhole` and `rasCentered` (one `SpatRaster`
#'   per ELF), and `poly`. `NULL` is returned as is.
#'
#' @return `ELFs`, with the rasters in memory.
.elfsToMemory <- function(ELFs) {
  if (is.null(ELFs)) return(NULL)
  for (j in c("rasWhole", "rasCentered"))
    ELFs[[j]] <- lapply(ELFs[[j]], terra::toMemory)
  ELFs
}
