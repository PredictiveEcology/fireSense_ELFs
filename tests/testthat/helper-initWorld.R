## Stand-ins for what `init` needs from outside the module (national maps, Google Drive, LandR),
## shared by the tests that run `init` on the toy ELF maps of helper-toyELFs.R.

toySppEquiv <- function() data.frame(LandR = c("Pice_gla", "Popu_tre"), FuelClass = c("class2", "class1"))

## Mocks are set after simInit(): in the package rendition simInit() reloads the module's namespace.
## ELFtemplateRaster() is fireSenseUtils'. Init is sourced into the simList and finds it on the
## search path, so it is replaced there; the package rendition also imports it, so there too.
## `downloads = FALSE` leaves reproducible's downloader alone, for a test that reads a local ledger
## file with CacheGeo(), which uses it too. `border`: lines standing in for
## the Natural Earth download of the Canada-US border (`NULL`: no border in the study area).
mockInitWorld <- function(ELFs = toyELFs(), driveFiles = NULL, downloads = TRUE, border = NULL, env = parent.frame()) {
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
  ## the ledger is fetched with reproducible's downloader; the mock records its arguments in `driveCalls`
  driveCalls <- new.env()
  driveCalls$calls <- list()
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
  if (downloads) local_mocked_bindings(
    preProcess = function(targetFile = NULL, url = NULL, destinationPath = ".", purge = FALSE, ...) {
      driveCalls$calls[[length(driveCalls$calls) + 1L]] <- list(
        targetFile = targetFile, url = url, destinationPath = destinationPath, purge = purge)
      path <- file.path(destinationPath, targetFile)
      saveRDS(data.frame(polygonID = c("3.1.2", "5.1"), objFunVal = c(0.25, 0.5)), path)
      list(targetFilePath = path)
    },
    .package = "reproducible", .env = env)
  local_mocked_bindings(speciesInStudyArea = function(...) list(sppEquiv = toySppEquiv()),
                        .package = "LandR", .env = env)
  invisible(driveCalls)
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
