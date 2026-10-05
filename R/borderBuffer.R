#' Natural Earth 10 m land boundary lines
#'
#' @param destinationPath Folder the zip is downloaded and unzipped into.
#'
#' @return A `SpatVector` of lines (EPSG:4326): the Canada-United States segments of Natural Earth's
#'   `admin_0_boundary_lines_land`, see `selectCanadaUSBorder()`. Coastlines are not in this data set.
#' @keywords internal
canadaUSBorder <- function(destinationPath) {
  lines <- reproducible::prepInputs(
    url = "https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_0_boundary_lines_land.zip",
    targetFile = "ne_10m_admin_0_boundary_lines_land.shp", destinationPath = destinationPath,
    fun = terra::vect)
  selectCanadaUSBorder(lines)
}

#' The Canada-United States segments of a boundary-lines `SpatVector`
#'
#' @param lines `SpatVector` with Natural Earth's `ADM0_A3_L` and `ADM0_A3_R` (the country on each
#'   side of a segment). Segments with Canada on one side and the United States on the other are
#'   the 49th parallel, the Great Lakes and St Lawrence segments, and the Alaska-Yukon/BC border.
#'
#' @return The selected segments.
#' @keywords internal
selectCanadaUSBorder <- function(lines) {
  sides <- paste(lines$ADM0_A3_L, lines$ADM0_A3_R)
  lines[sides %in% c("CAN USA", "USA CAN"), ]
}

#' Buffer the border once
#'
#' @param line `SpatVector` of lines, or `NULL`.
#' @param width Buffer width in metres. `0`, `NA` or no `line` return `NULL` (no masking).
#' @param crs The CRS to buffer in, so that `width` is in metres; the ELF template's.
#'
#' @return A `SpatVector` of polygons in `crs`, or `NULL`.
#' @keywords internal
bufferBorder <- function(line, width, crs = terra::crs(line)) {
  if (is.null(line) || NROW(line) == 0L || is.na(width) || width <= 0) return(NULL)
  terra::buffer(terra::project(line, crs), width = width) |> terra::aggregate()
}

#' Remove what lies within the buffered border
#'
#' @param x A `SpatRaster` (cells within `border` become `NA`) or a polygon `SpatVector` (`border` is erased).
#' @param border Output of `bufferBorder()`; `NULL` returns `x` unchanged.
#'
#' @return `x` without the border zone.
#' @keywords internal
maskOutBorder <- function(x, border) {
  if (is.null(border)) return(x)
  if (inherits(x, "SpatRaster")) terra::mask(x, border, inverse = TRUE) else terra::erase(x, border)
}
