## Toy ELF maps for the tests: nothing is downloaded.
##
## One common grid of 4 rows x 12 columns of 5 km cells (one cell = 2500 ha) in EPSG:3978.
## Each ELF's core (value 2) is three columns wide, with a one-column buffer (value 1) on each
## side that exists, and 0 elsewhere:
##
##   ELF     core cols   buffer cols
##   3.1.1   1-3         4
##   3.1.2   4-6         3, 7
##   5.1     7-9         6, 10
##   1.1     10-12       9          (ecozone 1: permanently left out of fireSense)

toyGrid <- function() {
  terra::rast(nrows = 4, ncols = 12, xmin = 0, xmax = 60000, ymin = 0, ymax = 20000,
              crs = "EPSG:3978", vals = 0)
}

toyELFraster <- function(name, coreCols) {
  r <- toyGrid()
  col <- terra::colFromCell(r, seq_len(terra::ncell(r)))
  r[col %in% c(min(coreCols) - 1, max(coreCols) + 1)] <- 1
  r[col %in% coreCols] <- 2
  names(r) <- name
  r
}

toyELFs <- function() {
  cores <- list("3.1.1" = 1:3, "3.1.2" = 4:6, "5.1" = 7:9, "1.1" = 10:12)
  rasWhole <- Map(toyELFraster, names(cores), cores)
  ## rasCentered is the ELF alone, 0 -> NA, trimmed (the real one is also reprojected)
  rasCentered <- lapply(rasWhole, function(r) terra::trim(terra::classify(r, cbind(0, NA))))
  list(rasWhole = rasWhole, rasCentered = rasCentered)
}

## Centre of the cell at (row, col) of the toy grid
toyXY <- function(row, col) terra::xyFromCell(toyGrid(), terra::cellFromRowCol(toyGrid(), row, col))

## SIZE_HA 5000 is above the 2500 ha toy pixel and the 50 ha escape size, so a point escapes by default.
toyPoints <- function(row, col, YEAR, CAUSE, SIZE_HA = 5000) {
  terra::vect(toyXY(row, col), type = "points", crs = "EPSG:3978",
              atts = data.frame(YEAR = YEAR, CAUSE = CAUSE, SIZE_HA = SIZE_HA))
}

## A rectangle covering whole cells: rows r1..r2, cols c1..c2
toyPoly <- function(r1, r2, c1, c2, YEAR) {
  g <- toyGrid()
  e <- terra::ext(terra::xFromCol(g, c1) - 2500, terra::xFromCol(g, c2) + 2500,
                  terra::yFromRow(g, r2) - 2500, terra::yFromRow(g, r1) + 2500)
  p <- terra::as.polygons(e, crs = "EPSG:3978")
  p$YEAR <- YEAR
  p
}

## --- simList helpers -----------------------------------------------------------------------
## Helpers are sourced before any setup file, so the module's location is worked out here:
## testthat runs in tests/testthat.
toyModuleRoot <- function() normalizePath(testthat::test_path("..", ".."), winslash = "/")

toyPaths <- function() {
  root <- file.path(tempdir(), "fireSenseELFsToy")
  paths <- list(cachePath = file.path(root, "cache"), inputPath = file.path(root, "inputs"),
                modulePath = dirname(toyModuleRoot()), outputPath = file.path(root, "outputs"))
  for (p in paths[c("cachePath", "inputPath", "outputPath")])
    dir.create(p, recursive = TRUE, showWarnings = FALSE)
  paths
}

## simInit() only: runs .inputObjects and nothing else. No caching, no Google Drive, no plots.
## `fireYears = NULL` keeps init from counting fires, which needs the national fire records; a
## test of the default (`params = list(fireYears = NULL)`) or of merging sets it back.
toySimInit <- function(objects = list(), params = list()) {
  withr::local_options(list(spades.moduleCodeChecks = FALSE, spades.useRequire = FALSE,
                            reproducible.verbose = -2, reproducible.useCloud = FALSE))
  p <- utils::modifyList(list(.useCache = FALSE, .useCloud = FALSE, .plots = NA, fireYears = NULL), params)
  suppressMessages(SpaDES.core::simInit(
    times = list(start = 1, end = 1), modules = "fireSense_ELFs", objects = objects,
    params = list(fireSense_ELFs = p), paths = toyPaths()
  ))
}

## An object a module keeps in `mod`; its home in the simList has moved between SpaDES.core versions
toyModObj <- function(sim, name, module = "fireSense_ELFs") {
  for (slot in c(".modObjs", ".mods")) {
    e <- sim@.xData[[slot]][[module]]
    if (is.null(e)) next
    if (exists(name, envir = e, inherits = FALSE)) return(get(name, envir = e))
    if (exists(".objects", envir = e, inherits = FALSE) &&
        exists(name, envir = e$.objects, inherits = FALSE)) return(get(name, envir = e$.objects))
  }
  stop("no `mod$", name, "` found in the simList")
}

## toyELFs() as makeELFs(singleSpatVector = TRUE) returns them: with `poly`, one polygon per ELF
## (core and buffer) with its name in field `ID`
toyELFsWithPoly <- function() {
  ELFs <- toyELFs()
  polys <- Map(function(r, nm) {
    p <- terra::as.polygons(r > 0)
    p <- p[p[[1]][, 1] == TRUE]
    p$ID <- nm
    p
  }, ELFs$rasWhole, names(ELFs$rasWhole))
  ELFs$poly <- Reduce(rbind, polys)
  ELFs
}

## A vertical border line across the toy grid (EPSG:3978), by default between columns 6 and 7
toyBorder <- function(x = 30000) {
  terra::vect(cbind(c(x, x), c(0, 20000)), type = "lines", crs = "EPSG:3978")
}

## Area of a polygon `SpatVector`, km2
km2 <- function(v) sum(terra::expanse(v, unit = "km", transform = FALSE))

## Toy fire records for the ELFs of toyELFs(), used where init counts fires
toyFirePoints <- function() {
  rbind(
    toyPoints(2, 2, 2001L, "L"),
    toyPoints(3, 2, 2001L, "H"),          # human-caused
    toyPoints(1, 5, 2001L, "N"),
    toyPoints(2, 5, 2002L, "L"),
    toyPoints(3, 5, 2003L, "L", SIZE_HA = 100),   # counted, but too small to escape
    toyPoints(4, 5, 1999L, "L"),          # outside fireYears
    toyPoints(2, 8, 2002L, "L"),
    toyPoints(2, 11, 2002L, "L")          # in arctic ELF 1.1
  )
}

toyFirePolys <- function() {
  half <- toyPoly(1, 1, 8, 8, 2002L)
  half <- terra::crop(half, terra::ext(terra::xmin(half), terra::xmin(half) + 2500,
                                       terra::ymin(half), terra::ymax(half))) # 2.5 x 5 km = 1250 ha
  rbind(toyPoly(1, 1, 1, 2, 2001L),      # 2 cells = 5000 ha, in 3.1.1
        toyPoly(3, 4, 5, 5, 2002L),      # 2 cells = 5000 ha, in 3.1.2 (col 5 is in no buffer)
        half)
}
