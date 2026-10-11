## The toy ELF maps and fire records are defined once, in fireSenseUtils.
source(system.file("testhelpers", "toyELFs.R", package = "fireSenseUtils"), local = TRUE)

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

