#' The study area's grid
#'
#' The template raster cropped and masked to the study area and trimmed: 1 inside, `NA` outside (never 0,
#' which is treated as `NA`). `rasterToMatch`, and the grid of `rasterToMatchLargeELF` for a study area
#' over several ELFs.
#'
#' @param rastTemplate the national template raster (`fireSenseUtils::ELFtemplateRaster()`).
#' @param studyArea a polygon `SpatVector`.
#' @param filename optional file to write the grid to. A result kept in terra's temporary folder
#'   (as with `todisk = TRUE`) is lost once that folder is cleared, and a cache hit restores it
#'   into the cache folder; a named file is restored to where it was written. It is written to a
#'   temporary file and renamed, so a reader never sees it half-written.
#' @return a `SpatRaster`.
studyAreaGrid <- function(rastTemplate, studyArea, filename = "") {
  r <- terra::trim(postProcessTo(rastTemplate, maskTo = studyArea, cropTo = studyArea))
  grid <- function(f) terra::ifel(!is.na(r), 1, NA, filename = f, overwrite = nzchar(f), datatype = "INT1U")
  if (nzchar(filename)) writeRasterAtomic(filename, grid) else grid("")
}
