#' A map of the ELFs, one level per ELF
#'
#' The ELF polygons as a categorical raster named `"ELFs"`, its levels the ELF names, for
#' `SpaDES.project::plotSAs()`: drawn with a study area, the legend names the ELFs in the map's window.
#'
#' @param poly `SpatVector` (or `sf`) of the ELFs with their names in column `ID` (`ELFs$poly`).
#' @param res Cell size, in the units of `poly`'s CRS; default 5000, the ELF maps' (`ELFs$rasWhole`).
#'
#' @return A categorical `SpatRaster`, one layer named `"ELFs"`.
ELFsMap <- function(poly, res = 5000) {
  if (!inherits(poly, "SpatVector")) poly <- terra::vect(poly)
  r <- terra::rasterize(poly, terra::rast(poly, resolution = res), field = "ID")
  names(r) <- "ELFs"
  r
}
