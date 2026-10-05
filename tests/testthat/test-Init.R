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
  ## fireYears is NULL by default: nothing is counted or merged
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
  ## NULL: the three fire-count outputs (fireYears is NULL), spreadFitPreRun and the ignition/escape
  ## fit lists (no ledger yet)
  expect_setequal(declared[isNull], c("ELFsExcluded", "ELFfireStatus", "ELFmerges", "spreadFitPreRun",
                                      "fireSense_IgnitionFittedList", "fireSense_EscapeFittedList"))
})

test_that("a missing fitted-parameter file means nothing has been fitted yet, and says so", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "fireSenseParams.rds"))
  mockInitWorld()
  msgs <- capture_messages(out <- runInit(sim))
  expect_null(out$spreadFitPreRun)
  expect_true(any(grepl("no 'fireSenseParams.rds' in .* treating this as no pre-run SpreadFit results yet",
                        msgs)))
})

test_that("the fitted-parameter file is read from the folder when it is there", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "fireSenseParams.rds"))
  files <- data.frame(name = c("other.rds", "fireSenseParams.rds"))
  files$id <- c("id_other", "id_params")
  files$drive_resource <- list(list(md5Checksum = "aaa"), list(md5Checksum = "bbb"))
  drive <- mockInitWorld(driveFiles = files)
  unlink(file.path(toyPaths()$inputPath, "fireSenseParams.rds"))
  out <- suppressMessages(runInit(sim))
  expect_identical(out$spreadFitPreRun,
                   data.frame(polygonID = c("3.1.2", "5.1"), objFunVal = c(0.25, 0.5)))
  expect_true(file.exists(file.path(toyPaths()$inputPath, "fireSenseParams.rds")))
  ## fetched with reproducible, into inputPath, by the file's Drive id
  expect_length(drive$calls, 1L)
  expect_identical(drive$calls[[1]]$targetFile, "fireSenseParams.rds")
  expect_identical(normalizePath(drive$calls[[1]]$destinationPath), normalizePath(toyPaths()$inputPath))
  expect_match(drive$calls[[1]]$url, "id_params", fixed = TRUE)
  expect_false(isTRUE(drive$calls[[1]]$purge == 7))                # no local copy yet
})

test_that("a local copy that differs from Drive's md5 is fetched again", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "fireSenseParams.rds"))
  files <- data.frame(name = "fireSenseParams.rds", id = "id_params")
  files$drive_resource <- list(list(md5Checksum = "bbb"))
  drive <- mockInitWorld(driveFiles = files)
  writeBin(as.raw(1:3), file.path(toyPaths()$inputPath, "fireSenseParams.rds"))
  out <- suppressMessages(runInit(sim))
  expect_identical(drive$calls[[1]]$purge, 7)
  expect_identical(out$spreadFitPreRun$polygonID, c("3.1.2", "5.1"))
})

test_that("spreadFitFilename chooses which file in the folder is read", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(spreadFitFilename = "mine.rds"))
  files <- data.frame(name = "fireSenseParams.rds")
  files$drive_resource <- list(list(md5Checksum = "bbb"))
  mockInitWorld(driveFiles = files)
  msgs <- capture_messages(out <- runInit(sim))
  expect_null(out$spreadFitPreRun)
  expect_true(any(grepl("no 'mine.rds' in ", msgs, fixed = TRUE)))
})

test_that("by default (\"latest\") the fits come from the newest current-model file, not a named one", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  ## the current model's file name carries fireSenseUtils::spreadFitFileTag, which changes with the model
  current <- fireSenseUtils::spreadFitFilenameFor(1985:2024)
  files <- data.frame(name = c("fireSenseParams.rds", current))
  files$drive_resource <- list(list(md5Checksum = "bbb", modifiedTime = "2026-09-25T00:00:00Z"),
                               list(md5Checksum = "ccc", modifiedTime = "2026-09-20T00:00:00Z"))
  mockInitWorld(driveFiles = files)
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
