## The `init` event, end to end, on the toy ELF maps of helper-toyELFs.R.
##
## Init needs the national template raster, the national ELF maps, Google Drive and LandR's
## species lookup. Those calls are replaced by toy stand-ins; all the
## module's own logic (picking the ELF, buffers, study areas, rasters to match, the outputs put
## in the simList) is the real code.
##
## Run for ELF 3.1.2: core cols 4-6, buffer cols 3 and 7, 4 rows of 5 km cells. So
##   rasterToMatchLargeELF : cols 3-7  = 5 x 4 = 20 cells, 500 km2
##   rasterToMatchELF      : cols 4-6  = 3 x 4 = 12 cells, 300 km2


test_that("init builds the single-ELF study areas and rasters with and without the buffer", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld()
  out <- suppressMessages(runInit(sim))

  large <- out$rasterToMatchLargeELF
  expect_identical(dim(large)[1:2], c(4, 5))                           # 4 rows, cols 3-7
  expect_equal(unname(as.vector(terra::ext(large))), c(10000, 35000, 0, 20000))
  expect_identical(as.vector(large[1, ])[[1]], c(1, 2, 2, 2, 1))       # buffer, core x 3, buffer

  core <- out$rasterToMatchELF
  expect_identical(dim(core)[1:2], c(4, 3))                            # cols 4-6
  expect_equal(unname(as.vector(terra::ext(core))), c(15000, 30000, 0, 20000))
  expect_identical(unique(as.vector(terra::values(core))), 2)

  expect_equal(km2(out$studyAreaLargeELF), 500)                        # 20 cells x 25 km2
  expect_equal(km2(out$studyAreaELF), 300)                             # 12 cells x 25 km2
  ## for a single ELF, studyAreaLarge is the buffered ELF, and studyArea defaults to it
  expect_equal(km2(out$studyAreaLarge), 500)
  expect_equal(km2(out$studyArea), 500)
})

test_that("init makes rasterToMatch 1 inside studyAreaLarge, on the template grid", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld()
  out <- suppressMessages(runInit(sim))
  rtm <- out$rasterToMatch
  expect_identical(dim(rtm)[1:2], c(4, 5))
  expect_identical(as.vector(terra::values(rtm)), rep(1, 20))          # never 0: 0 is treated as NA
  expect_equal(terra::res(rtm), c(5000, 5000))
})

test_that("init puts the species table and the ELF maps in the simList", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld()
  out <- suppressMessages(runInit(sim))
  expect_identical(out$sppEquiv, toySppEquiv())
  expect_identical(names(out$ELFs), c("rasWhole", "rasCentered"))
  expect_identical(names(out$ELFs$rasWhole), c("3.1.1", "3.1.2", "5.1", "1.1"))
  expect_true(all(vapply(out$ELFs$rasWhole, terra::inMemory, logical(1))))
  ## fireYears is NULL here (toySimInit's default): nothing is counted or merged
  expect_null(out$ELFsExcluded)
  expect_null(out$ELFfireStatus)
  expect_null(out$ELFmerges)
})

test_that("every declared output except the fire-count ones is created", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld()
  out <- suppressMessages(runInit(sim))
  declared <- SpaDES.core::moduleOutputs("fireSense_ELFs", toyPaths()$modulePath)$objectName
  isNull <- vapply(declared, function(n) is.null(out[[n]]), logical(1))
  ## NULL: the three fire-count outputs (toySimInit sets fireYears = NULL), spreadFitPreRun and the ignition/escape
  ## fit lists (no ledger yet)
  expect_setequal(declared[isNull], c("ELFsExcluded", "ELFfireStatus", "ELFmerges", "spreadFitPreRun",
                                      "fireSense_IgnitionFittedList", "fireSense_EscapeFittedList"))
})

test_that("the ledger is read through CacheGeoRead from inputPath, never listing Google Drive", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "fireSenseParams.rds"))
  mockInitWorld()
  ledgerSeen <- mockLedgerRead()
  ledgerFolder <- sim@params$fireSense_ELFs$spreadFitGoogleDriveFolder
  ## reproducible lists that folder for the shared ELF maps; only a listing made by Init itself is the defect
  local_mocked_bindings(
    drive_ls = function(path = NULL, ...) {
      if (identical(sys.call(-1)[[1]], quote(Init))) stop("Init must not list the ledger folder with googledrive::drive_ls()")
      data.frame(name = character(0))
    },
    .package = "googledrive")
  out <- suppressMessages(runInit(sim))
  expect_identical(out$spreadFitPreRun$polygonID, c("3.1.2", "5.1"))
  expect_identical(ledgerSeen$ledger$file, "fireSenseParams.rds")
  expect_identical(ledgerSeen$ledger$key, "polygonID")
  expect_identical(normalizePath(ledgerSeen$ledger$destinationPath), normalizePath(toyPaths()$inputPath))
  expect_identical(ledgerSeen$ledger$remote, ledgerFolder)
  expect_null(ledgerSeen$area)                                    # the whole ledger
})

test_that("a ledger with no rows means nothing has been fitted yet, and says so", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "fireSenseParams.rds"))
  mockInitWorld()
  mockLedgerRead(toyLedgerRows()[integer(0), , drop = FALSE])
  msgs <- capture_messages(out <- runInit(sim))
  expect_null(out$spreadFitPreRun)
  expect_true(any(grepl("no 'fireSenseParams.rds' in .* treating this as no pre-run SpreadFit results yet",
                        msgs)))
})

test_that("spreadFitFilename chooses which ledger file is read", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "mine.rds"))
  mockInitWorld()
  ledgerSeen <- mockLedgerRead()
  suppressMessages(runInit(sim))
  expect_identical(ledgerSeen$ledger$file, "mine.rds")
})

test_that("by default (\"latest\") the fits come from the newest current-model file, not a named one", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  ## the current model's file name carries fireSenseUtils::spreadFitFileTag, which changes with the model
  current <- fireSenseUtils::spreadFitFilenameFor(1985:2024)
  files <- data.frame(name = c("fireSenseParams.rds", current))
  files$drive_resource <- list(list(md5Checksum = "bbb", modifiedTime = "2026-09-25T00:00:00Z"),
                               list(md5Checksum = "ccc", modifiedTime = "2026-09-20T00:00:00Z"))
  mockInitWorld(driveFiles = files)
  ## reproducible::CacheGeoRead() downloads the ledger into a temporary file beside it, then renames it
  ## (reproducible >= 3.2.1.9081), so a job reading the ledger never sees it half-written
  local_mocked_bindings(
    drive_download = function(file, path, ...) {
      if (basename(path) %in% c("fireSenseParams.rds", current)) stop("downloaded over the ledger itself")
      saveRDS(data.frame(polygonID = c("3.1.2", "5.1"), objFunVal = c(0.25, 0.5)), path)
      invisible(NULL)
    },
    .package = "googledrive")
  unlink(file.path(toyPaths()$inputPath, c("fireSenseParams.rds", current)))
  out <- suppressMessages(runInit(sim))
  expect_identical(out$spreadFitPreRun$polygonID, c("3.1.2", "5.1"))
  expect_true(file.exists(file.path(toyPaths()$inputPath, current)))
  expect_false(file.exists(file.path(toyPaths()$inputPath, "fireSenseParams.rds")))
})

test_that("an ELF with no cells stops with 'This ELF has no data'", {
  ELFs <- toyELFs()
  terra::values(ELFs$rasWhole[["3.1.2"]]) <- NA
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld(ELFs = ELFs)
  expect_error(suppressMessages(runInit(sim)), "This ELF has no data")
})

test_that("an ELF without tree species is announced and gets a 0-row sppEquiv", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld()
  local_mocked_bindings(speciesInStudyArea = function(...) list(sppEquiv = toySppEquiv()[0, ]),
                        .package = "LandR")
  msgs <- capture_messages(out <- runInit(sim))
  expect_identical(nrow(out$sppEquiv), 0L)
  expect_identical(sum(grepl("ELF 3.1.2: no tree species found", msgs, fixed = TRUE)), 1L)
})

test_that("init completes and schedules nothing further", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  mockInitWorld()
  out <- suppressMessages(runInit(sim))
  done <- SpaDES.core::completed(out)
  expect_identical(done$eventType[done$moduleName == "fireSense_ELFs"], c(".inputObjects", "init"))
  ev <- SpaDES.core::events(out)
  expect_identical(sum(ev$moduleName == "fireSense_ELFs"), 0L)
})

## `heldOutFold` (the same parameter as fireSense_spreadFit's): a held-out fold is fitted without the
## SpreadFit ledger, so `init` must not read it, and must proceed as for an ELF nothing has been fitted for.

test_that("with heldOutFold 1 the ledger is not read, whichever spreadFitFilename, and nothing is fitted", {
  for (filename in list("latest", "fireSenseParams.rds")) {
    sim <- toySimInit(objects = list(.ELFind = "3.1.2"),
                      params = list(heldOutFold = 1L, spreadFitFilename = filename))
    mockInitWorld()
    mockNoLedger()
    out <- suppressMessages(runInit(sim))
    expect_null(out$spreadFitPreRun)
    expect_identical(dim(out$rasterToMatchELF)[1:2], c(4, 3))       # init still ran to the end
  }
})

test_that("with heldOutFold NA the ledger is read as before", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(heldOutFold = NA))
  mockInitWorld()
  called <- FALSE
  local_mocked_bindings(latestSpreadFits = function(...) {
    called <<- TRUE
    NULL
  }, .package = "fireSenseUtils")
  suppressMessages(runInit(sim))
  expect_true(called)
})

test_that("a heldOutFold that is not NA, 1 or 2 is an error", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(heldOutFold = 3L))
  mockInitWorld()
  mockNoLedger()
  expect_error(suppressMessages(runInit(sim)), "heldOutFold")
})

test_that("stops when fireSense_spreadFit has a different heldOutFold", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(heldOutFold = NA))
  sim@params$fireSense_spreadFit <- list(heldOutFold = 1L)
  mockInitWorld()
  mockNoLedger()
  expect_error(suppressMessages(runInit(sim)), "multiple values for heldOutFold")
})

test_that("agrees when fireSense_spreadFit has the same heldOutFold", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(heldOutFold = 2L))
  sim@params$fireSense_spreadFit <- list(heldOutFold = 2L)
  mockInitWorld()
  mockNoLedger()
  expect_no_error(suppressMessages(runInit(sim)))
})

test_that("by default init counts fires over the fit's years and merges the thin ELFs", {
  ## no fireYears set: the module's default, which fireSense_dataPrepFit shares
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"),
                    params = list(fireYears = NULL, minNaturalIgnitions = 3, minFirePolygons = 1,
                                  minEscapes = 1, minRegionAreaKm2 = NA)) # the size rule has its own tests
  expect_identical(SpaDES.core::params(sim)$fireSense_ELFs$fireYears, fireSenseUtils::defaultFireYears())
  mockInitWorld()
  seen <- new.env()
  ## the fire-record archives are not downloaded; any other preProcess() call is mockInitWorld()'s
  mockedPreProcess <- reproducible::preProcess
  local_mocked_bindings(
    preProcess = function(url = NULL, ...) {
      if (isTRUE(grepl("nfdb|nbac", url, ignore.case = TRUE)))
        return(list(targetFilePath = file.path(tempdir(), paste0(basename(url), ".shp"))))
      mockedPreProcess(url = url, ...)
    },
    .package = "reproducible")
  ## the fire records are loaded by prepInputs() with a loader call on the shapefile
  mockedPrepInputs <- reproducible::prepInputs
  local_mocked_bindings(
    prepInputs = function(url = NULL, targetFile = NULL, fun = NULL, ...) {
      if (isTRUE(grepl("nfdb|nbac", url, ignore.case = TRUE))) return(eval(fun, list(targetFile = targetFile)))
      mockedPrepInputs(url = url, targetFile = targetFile, fun = fun, ...)
    },
    .package = "reproducible")
  local_mocked_bindings(
    load_nfdb_points = function(nfdb_shp, study_area, fire_years = NULL, min_size_ha = 1) {
      seen$years <- fire_years
      toyFirePoints()
    },
    load_nbac_polys = function(nbac_shp, study_area, fire_years = NULL, min_size_ha = 1) toyFirePolys(),
    .package = "fireregimetools")
  out <- suppressMessages(runInit(sim))
  expect_identical(as.integer(seen$years), fireSenseUtils::defaultFireYears())
  expect_false(is.null(out$ELFmerges))
  expect_identical(out$ELFsExcluded, "5.1")
})
