#' The study area's grid
#'
#' The template raster cropped and masked to the study area and trimmed: 1 inside, `NA` outside (never 0,
#' which is treated as `NA`). `rasterToMatch`, and the grid of `rasterToMatchLargeELF` for a study area
#' over several ELFs.
#'
#' @param rastTemplate the national template raster (`fireSenseUtils::ELFtemplateRaster()`).
#' @param studyArea a polygon `SpatVector`.
#' @return a `SpatRaster`.
studyAreaGrid <- function(rastTemplate, studyArea) {
  r <- terra::trim(postProcessTo(rastTemplate, maskTo = studyArea, cropTo = studyArea))
  terra::ifel(!is.na(r), 1, NA)
}
