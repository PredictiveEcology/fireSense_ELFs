## The module's metadata is its public contract: users' scripts set these parameters and other
## modules bind to these objects. Any removal, rename or retype must fail here.
##
## A parameter or output ADDED on purpose: add it here in the same commit.

md <- SpaDES.core::moduleMetadata(module = "fireSense_ELFs", path = dirname(toyModuleRoot()))

test_that("the module is named fireSense_ELFs and runs before the other fireSense modules", {
  expect_identical(md$name, "fireSense_ELFs")
  expect_identical(md$timeunit, "year")
  ## moduleMetadata() does not return `loadOrder`; the parsed module in a simList has it
  loadOrder <- SpaDES.core::depends(toySimInit())@dependencies$fireSense_ELFs@loadOrder
  expect_true(all(c("fireSense", "fireSense_dataPrepFit", "fireSense_IgnitionFit", "fireSense_EscapeFit",
                    "fireSense_SpreadFit", "fireSense_dataPrepPredict", "fireSense_IgnitionPredict",
                    "fireSense_EscapePredict", "fireSense_SpreadPredict", "fireSense_summary")
                  %in% loadOrder$before))
  expect_null(loadOrder$after)
})

test_that("inputs are the expected names and classes", {
  inputs <- stats::setNames(md$inputObjects$objectClass, md$inputObjects$objectName)
  expect_identical(inputs[order(names(inputs))],
                   c(.ELFind = "character", studyAreaLarge = "SpatVector"))
})

test_that("outputs are the expected names and classes", {
  outputs <- stats::setNames(md$outputObjects$objectClass, md$outputObjects$objectName)
  expected <- c(ELFfireStatus = "data.table", ELFmerges = "data.table", ELFs = "SpatRaster",
                ELFsExcluded = "character",
                rasterToMatch = "SpatRaster", rasterToMatchELF = "SpatRaster",
                rasterToMatchLargeELF = "SpatRaster", sppEquiv = "data.table",
                spreadFitPreRun = "data.frame", studyArea = "SpatVector",
                studyAreaELF = "SpatVector", studyAreaLarge = "SpatVector",
                studyAreaLargeELF = "SpatVector")
  expect_identical(outputs[order(names(outputs))], expected[order(names(expected))])
})

test_that("no parameter has been removed or retyped", {
  classes <- vapply(md$parameters$paramClass, paste, "", collapse = "|")
  names(classes) <- unlist(md$parameters$paramName)
  expected <- c(sppEquivCol = "character", spreadFitFilename = "character",
                spreadFitGoogleDriveFolder = "character", queue_path = "character",
                fireYears = "integer", minNaturalIgnitions = "numeric", minFirePolygons = "numeric",
                .plots = "character", .plotInitialTime = "numeric", .studyAreaName = "character",
                .useCache = "logical", .useCloud = "logical|character", .useCacheArgs = "list")
  ## `%in%`, not identical: work in progress adds parameters, and an addition breaks no caller
  expect_true(all(names(expected) %in% names(classes)))
  expect_identical(classes[names(expected)], expected)
  ## removed on purpose (declared but never read); they must not come back unused
  expect_false(any(c(".plotInterval", ".saveInitialTime", ".saveInterval") %in% names(classes)))
})

test_that("parameter defaults are unchanged", {
  p <- SpaDES.core::params(toySimInit(params = list(.useCache = NULL, .useCloud = NULL, .plots = NULL)))$fireSense_ELFs
  expect_identical(p$sppEquivCol, "LandR")
  expect_identical(p$spreadFitFilename, "fireSenseParams.rds")
  expect_identical(p$spreadFitGoogleDriveFolder,
                   "https://drive.google.com/drive/folders/1X9-mRjyLMNpgkP_cfqhbr_AQEPOsVCHf")
  expect_null(p$queue_path)
  expect_null(p$fireYears)
  expect_identical(p$minNaturalIgnitions, 50)
  expect_identical(p$minFirePolygons, 50)
  expect_identical(p$.plots, "screen")
  expect_identical(as.numeric(p$.plotInitialTime), 1) # start(sim)
  expect_identical(p$.studyAreaName, NA)
  expect_identical(p$.useCache, "init")
  expect_identical(p$.useCloud, TRUE)
  expect_identical(names(p$.useCacheArgs), "init")
  expect_identical(names(p$.useCacheArgs$init), c("useCloud", "cloudFolderID", ".cacheExtra"))
})

test_that("every parameter, input and output has a description", {
  expect_true(all(nzchar(unlist(md$parameters$paramDesc))))
  expect_false(any(unlist(md$parameters$paramDesc) %in% c("NA", NA)))
  for (desc in list(md$inputObjects$desc, md$outputObjects$desc)) {
    expect_true(all(nzchar(desc)))
    expect_false(any(desc %in% c("NA", NA)))
  }
})

test_that("reqdPkgs still names the packages the module calls with `::`", {
  ## a package used but not installable from reqdPkgs would break the module on a clean machine
  reqd <- sub("^.*/", "", sub("[ @(].*$", "", unlist(md$reqdPkgs)))
  expect_true(all(c("terra", "reproducible", "SpaDES.core", "LandR", "withr",
                    "fireregimetools", "fireSenseUtils", "SpaDES.project") %in% reqd))
})
