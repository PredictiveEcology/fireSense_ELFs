## The ignition/escape fits of the ELFs a run touches, read from the ledger of fireSense_ignitionFit.
## Local ledger only: `ignitionFitGoogleDriveFolder = NULL` and a named file, so no Google Drive.
## Rows are the shape fireSense_ignitionFit writes: geometry, polygonID, crs and the two fit list-columns.

ledgerFile <- "fireSenseIgnitionParams_toy_xgboost.rds"

## A stand-in for a fitted model: its content says which ELF and process it is
toyFit <- function(ELF, process) list(modelList = list(model = list(Fold1 = paste(ELF, process))),
                                      scaleData = list())

## Write a ledger holding the ELFs in `ELFinds`; the geometry is each ELF's own polygon
writeToyLedger <- function(ELFinds, path = toyPaths()$inputPath, file = ledgerFile) {
  polys <- sf::st_as_sf(toyELFsWithPoly()$poly)
  polys <- polys[polys$ID %in% ELFinds, ]
  rows <- sf::st_sf(polygonID = polys$ID, geometry = sf::st_geometry(polys))
  cols <- fireSenseUtils::ignitionFitAdditionalColNamesTxt
  rows[[cols[1]]] <- lapply(rows$polygonID, toyFit, process = "ignition")
  rows[[cols[2]]] <- lapply(rows$polygonID, toyFit, process = "escape")
  rows$crs <- I(rep(sf::st_crs(rows)$wkt, nrow(rows)))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  saveRDS(as.data.frame(rows), file.path(path, file))
}

## No Drive folder: a NULL parameter is dropped by toySimInit(), so it is set after simInit()
toySimInitLocalLedger <- function(objects, ...) {
  sim <- toySimInit(objects = objects, params = list(ignitionFitFilename = ledgerFile, ...))
  sim@params$fireSense_ELFs["ignitionFitGoogleDriveFolder"] <- list(NULL)
  sim
}

## prediction over ELFs 3.1.1 and 3.1.2: their core columns 1-6 of the toy grid
toyStudyAreaLarge <- function() {
  terra::vect(terra::ext(0, 30000, 0, 20000), crs = "EPSG:3978")
}

## Every toy ELF has a SpreadFit, so only the ignition ledger decides what is stopped
mockSpreadFitsForAllELFs <- function(env = parent.frame()) {
  local_mocked_bindings(latestSpreadFits = function(...) data.frame(polygonID = c("3.1.1", "3.1.2", "5.1")),
                        .package = "fireSenseUtils", .env = env)
}

initMultiELF <- function(ELFinds, ...) {
  unlink(toyPaths()$inputPath, recursive = TRUE)
  writeToyLedger(ELFinds)
  sim <- toySimInitLocalLedger(list(studyAreaLarge = toyStudyAreaLarge()), ...)
  mockInitWorld(ELFs = toyELFsWithPoly())
  mockSpreadFitsForAllELFs()
  runInit(sim)
}

test_that("a study area over several ELFs gets one fitted ignition and escape model per ELF, named by ELF", {
  out <- suppressMessages(initMultiELF(c("3.1.1", "3.1.2", "5.1")))
  expect_setequal(names(out$fireSense_IgnitionFittedList), c("3.1.1", "3.1.2"))
  expect_identical(names(out$fireSense_EscapeFittedList), names(out$fireSense_IgnitionFittedList))
  for (id in names(out$fireSense_IgnitionFittedList)) {
    expect_identical(out$fireSense_IgnitionFittedList[[id]], toyFit(id, "ignition"))
    expect_identical(out$fireSense_EscapeFittedList[[id]], toyFit(id, "escape"))
  }
})

test_that("an ELF the study area touches that has no fit stops the run and is named", {
  expect_error(suppressMessages(initMultiELF("3.1.1")), "3\\.1\\.2")
})

initSingleELF <- function(ELF) {
  unlink(toyPaths()$inputPath, recursive = TRUE)
  writeToyLedger("3.1.2")
  sim <- toySimInitLocalLedger(list(.ELFind = ELF))
  mockInitWorld(ELFs = toyELFsWithPoly())
  suppressMessages(runInit(sim))
}

test_that("a single ELF with a fit gets its own entry", {
  out <- initSingleELF("3.1.2")
  expect_identical(names(out$fireSense_IgnitionFittedList), "3.1.2")
  expect_identical(out$fireSense_EscapeFittedList[["3.1.2"]], toyFit("3.1.2", "escape"))
})

test_that("a single ELF with no fit gets NULL, because this run is about to fit it", {
  out <- initSingleELF("3.1.1")
  expect_null(out$fireSense_IgnitionFittedList)
  expect_null(out$fireSense_EscapeFittedList)
})

test_that("\"latest\" reads each touched ELF's row from the newest ledger files, by polygonID", {
  asked <- askedSuffix <- NULL
  local_mocked_bindings(latestIgnitionFits = function(cloudFolderID, destinationPath, polygonIDs = NULL, suffix = "") {
    asked <<- polygonIDs
    askedSuffix <<- suffix
    rows <- data.frame(polygonID = c("3.1.1", "3.1.2"))
    cols <- fireSenseUtils::ignitionFitAdditionalColNamesTxt
    rows[[cols[1]]] <- lapply(rows$polygonID, toyFit, process = "ignition")
    rows[[cols[2]]] <- lapply(rows$polygonID, toyFit, process = "escape")
    rows
  }, .package = "fireSenseUtils")
  sim <- toySimInit(objects = list(studyAreaLarge = toyStudyAreaLarge()))
  mockInitWorld(ELFs = toyELFsWithPoly())
  mockSpreadFitsForAllELFs()
  out <- suppressMessages(runInit(sim))
  expect_setequal(asked, c("3.1.1", "3.1.2"))
  expect_identical(askedSuffix, "")                      # the production ledger
  expect_setequal(names(out$fireSense_IgnitionFittedList), c("3.1.1", "3.1.2"))
})

test_that("with heldOutFold the ignition ledger is not read either", {
  sim <- toySimInit(objects = list(studyAreaLarge = toyStudyAreaLarge()), params = list(heldOutFold = 1L))
  mockInitWorld(ELFs = toyELFsWithPoly())
  mockNoLedger()
  out <- suppressMessages(runInit(sim))
  expect_null(out$fireSense_IgnitionFittedList)
})

test_that("with a fitFileSuffix, \"latest\" reads the ignition files with that suffix and no others", {
  askedSuffix <- NULL
  local_mocked_bindings(latestIgnitionFits = function(cloudFolderID, destinationPath, polygonIDs = NULL, suffix = "") {
    askedSuffix <<- suffix
    NULL
  }, .package = "fireSenseUtils")
  readIgnitionFitRows(toyELFsWithPoly(), "folder", "latest", tempdir(), fitFileSuffix = "_boundfix_rep81")
  expect_identical(askedSuffix, "_boundfix_rep81")
})

## `.ELFind` of a study area over several ELFs. It used to stay "4.3" (the default for no study area at
## all); the fit modules, finding no stored fit for that "ELF", stopped with doFit = FALSE (2026-11-02, a
## predict-only run over ELFs 6.6.1 and 6.6.2). (It reaches the other modules when init runs during
## simInit() only with SpaDES.core's fix for objects whose name starts with ".".)
test_that("a study area over several ELFs makes .ELFind those ELFs, not the default", {
  out <- suppressMessages(initMultiELF(c("3.1.1", "3.1.2", "5.1")))
  expect_identical(out$.ELFind, c("3.1.1", "3.1.2"))
})

test_that("an ELF of the study area without a SpreadFit is left out of .ELFind, as of the study area", {
  unlink(toyPaths()$inputPath, recursive = TRUE)
  writeToyLedger(c("3.1.1", "3.1.2"))
  sim <- toySimInitLocalLedger(list(studyAreaLarge = toyStudyAreaLarge()))
  mockInitWorld(ELFs = toyELFsWithPoly())
  local_mocked_bindings(latestSpreadFits = function(...) data.frame(polygonID = "3.1.1"),
                        .package = "fireSenseUtils")
  out <- suppressMessages(suppressWarnings(runInit(sim)))
  expect_identical(out$.ELFind, "3.1.1")
})

## With both inputs supplied SpaDES skips .inputObjects, which recorded whether `.ELFind` was supplied;
## Init then took it as not supplied, so .assertOneStudyArea() never checked it.
test_that("a .ELFind the user gives with the study area is checked and kept (.inputObjects does not run then)", {
  unlink(toyPaths()$inputPath, recursive = TRUE)
  writeToyLedger(c("3.1.1", "3.1.2", "5.1"))
  initWith <- function(elf) {
    sim <- toySimInitLocalLedger(list(studyAreaLarge = toyStudyAreaLarge(), .ELFind = elf))
    mockInitWorld(ELFs = toyELFsWithPoly())
    mockSpreadFitsForAllELFs()
    suppressMessages(runInit(sim))
  }
  ## the study area touches 3.1.1, 3.1.2 and 5.1
  expect_identical(initWith(c("5.1", "3.1.2", "3.1.1"))$.ELFind, c("5.1", "3.1.2", "3.1.1"))
  expect_error(initWith("3.1.2"), "describe different study areas")
})

## fireSense_spreadPredict blends neighbour ELFs on the grid of flammableRTM (rasterToMatch's), and
## stopped with "rasterToMatchLargeELF is not on the grid of sim$flammableRTM": over several ELFs it was
## made on the 5 km grid of the ELF maps, not the template's (2026-11-02).
test_that("over several ELFs, rasterToMatchLargeELF is on the grid of rasterToMatch, not of the ELF maps", {
  unlink(toyPaths()$inputPath, recursive = TRUE)
  writeToyLedger(c("3.1.1", "3.1.2", "5.1"))
  sim <- toySimInitLocalLedger(list(studyAreaLarge = toyStudyAreaLarge()))
  mockInitWorld(ELFs = toyELFsWithPoly())
  fine <- function(inputPath) terra::disagg(toyGrid(), 5) + 1     # a 1 km template; the ELF maps are 5 km
  local_mocked_bindings(ELFtemplateRaster = fine)
  local_mocked_bindings(ELFtemplateRaster = fine, .package = "fireSenseUtils")
  mockSpreadFitsForAllELFs()
  out <- suppressMessages(runInit(sim))
  expect_true(terra::compareGeom(out$rasterToMatchLargeELF, out$rasterToMatch, stopOnError = FALSE))
  expect_equal(terra::res(out$rasterToMatchLargeELF), c(1000, 1000))
  lv <- terra::levels(out$rasterToMatchLargeELF)[[1]]
  expect_setequal(as.character(lv[[2]][lv[[1]] %in% terra::values(out$rasterToMatchLargeELF, mat = FALSE)]),
                  c("3.1.1", "3.1.2"))
})
