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
  mockInitWorld(ELFs = toyELFsWithPoly(), downloads = FALSE)
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
  mockInitWorld(ELFs = toyELFsWithPoly(), downloads = FALSE)
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
  asked <- NULL
  local_mocked_bindings(latestIgnitionFits = function(cloudFolderID, destinationPath, polygonIDs = NULL) {
    asked <<- polygonIDs
    rows <- data.frame(polygonID = c("3.1.1", "3.1.2"))
    cols <- fireSenseUtils::ignitionFitAdditionalColNamesTxt
    rows[[cols[1]]] <- lapply(rows$polygonID, toyFit, process = "ignition")
    rows[[cols[2]]] <- lapply(rows$polygonID, toyFit, process = "escape")
    rows
  }, .package = "fireSenseUtils")
  sim <- toySimInit(objects = list(studyAreaLarge = toyStudyAreaLarge()))
  mockInitWorld(ELFs = toyELFsWithPoly(), downloads = FALSE)
  mockSpreadFitsForAllELFs()
  out <- suppressMessages(runInit(sim))
  expect_setequal(asked, c("3.1.1", "3.1.2"))
  expect_setequal(names(out$fireSense_IgnitionFittedList), c("3.1.1", "3.1.2"))
})

test_that("with heldOutFold the ignition ledger is not read either", {
  sim <- toySimInit(objects = list(studyAreaLarge = toyStudyAreaLarge()), params = list(heldOutFold = 1L))
  mockInitWorld(ELFs = toyELFsWithPoly(), downloads = FALSE)
  mockNoLedger()
  out <- suppressMessages(runInit(sim))
  expect_null(out$fireSense_IgnitionFittedList)
})
