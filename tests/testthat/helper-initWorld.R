## Stand-ins for what `init` needs from outside the module (national maps, Google Drive, LandR),
## shared by the tests that run `init` on the toy ELF maps of helper-toyELFs.R.

toySppEquiv <- function() data.frame(LandR = c("Pice_gla", "Popu_tre"), FuelClass = c("class2", "class1"))

## Mocks are set after simInit(): in the package rendition simInit() reloads the module's namespace.
## ELFtemplateRaster() is fireSenseUtils'. Init is sourced into the simList and finds it on the
## search path, so it is replaced there; the package rendition also imports it, so there too.
## `border`: lines standing in for
## the Natural Earth download of the Canada-US border (`NULL`: no border in the study area).
mockInitWorld <- function(ELFs = toyELFs(), driveFiles = NULL, border = NULL, env = parent.frame()) {
  local_mocked_bindings(ELFtemplateRaster = function(inputPath) toyGrid() + 1, .env = env)
  local_mocked_bindings(ELFtemplateRaster = function(inputPath) toyGrid() + 1,
                        .package = "fireSenseUtils", .env = env)
  local_mocked_bindings(makeELFs = function(x, ...) ELFs, .package = "fireSenseUtils", .env = env)
  local_mocked_bindings(
    drive_ls = function(...) {
      if (is.null(driveFiles)) data.frame(name = character(0)) else driveFiles
    },
    ## a direct download writes the file in place, where a job reading it meanwhile can see it half-written
    drive_download = function(...) stop("googledrive::drive_download() must not be called"),
    .package = "googledrive", .env = env)
  realPrepInputs <- reproducible::prepInputs
  local_mocked_bindings(
    prepInputs = function(url = NULL, ...) {
      if (!isTRUE(grepl("naturalearth", url))) return(realPrepInputs(url = url, ...))
      lines <- if (is.null(border)) toyBorder(-1e6) else border
      lines$ADM0_A3_L <- "CAN"
      lines$ADM0_A3_R <- if (is.null(border)) "MEX" else "USA"   # MEX: not a Canada-US segment
      lines
    },
    .package = "reproducible", .env = env)
  local_mocked_bindings(speciesInStudyArea = function(...) list(sppEquiv = toySppEquiv()),
                        .package = "LandR", .env = env)
  invisible(NULL)
}

runInit <- function(sim) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ## Init caches the ELF maps whatever `.useCache` says, keyed on tags the toy maps do not have:
  ## without this a test would get the maps of the test before it
  reproducible::clearCache(SpaDES.core::cachePath(sim), ask = FALSE, verbose = -2)
  SpaDES.core::spades(sim, debug = FALSE, events = list(fireSense_ELFs = "init"))
}

## Any read of the ledger is an error
mockNoLedger <- function(env = parent.frame()) {
  local_mocked_bindings(
    drive_ls = function(...) stop("ledger read: drive_ls"),
    drive_download = function(...) stop("ledger read: drive_download"),
    .package = "googledrive", .env = env)
  local_mocked_bindings(latestSpreadFits = function(...) stop("ledger read: latestSpreadFits"),
                        latestIgnitionFits = function(...) stop("ledger read: latestIgnitionFits"),
                        .package = "fireSenseUtils", .env = env)
}

## Rows as fireSense_spreadFit's CacheGeo writes them: an sf object keyed on polygonID
toyLedgerRows <- function() {
  sf::st_sf(polygonID = c("3.1.2", "5.1"), objFunVal = c(0.25, 0.5),
            geometry = sf::st_sfc(sf::st_point(c(0, 0)), sf::st_point(c(1, 1)), crs = 3978))
}

## The module reads the SpreadFit ledger with reproducible::CacheGeoRead(); `rows` is what it gets back.
## The returned environment holds the `ledger` and `area` it was called with.
mockLedgerRead <- function(rows = toyLedgerRows(), env = parent.frame()) {
  seen <- new.env()
  local_mocked_bindings(
    CacheGeoRead = function(ledger, area, ...) {
      seen$ledger <- ledger
      seen$area <- area
      rows
    },
    .package = "reproducible", .env = env)
  seen
}
