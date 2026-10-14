## The national ELF list is built once and then never rebuilt: the only thing that decides is the
## parameter `ELFversion`. Other parameters (here `minNaturalIgnitions`) and the module code are not
## part of the cache key. The builders are replaced by counting stand-ins on the toy ELF maps.

## Runs init (without clearing the cache) and returns how often the national maps were built
buildsOf <- function(counter, ...) {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(...))
  mockInitWorld()
  fakeBuilder(counter)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  suppressMessages(SpaDES.core::spades(sim, debug = FALSE, events = list(fireSense_ELFs = "init")))
  counter$n
}

## makeELFs() and fewFireELFs() count their calls, on top of the mocks of mockInitWorld()
fakeBuilder <- function(counter, env = parent.frame()) {
  local_mocked_bindings(
    makeELFs = function(x, ...) { counter$n <- counter$n + 1L; toyELFs() },
    nfdbPointUrl = function(...) "nfdb", latestNBACUrl = function(...) "nbac",
    sizeRuleLandCover = function(...) NULL,
    fewFireELFs = function(ELFs, ...) {
      plan <- data.frame(ELF = "3.1.2", action = "skip")
      plan$members <- list("3.1.2")
      list(ELFs = ELFs, excluded = character(0), status = data.frame(ELF = "3.1.2"), plan = plan)
    },
    .package = "fireSenseUtils", .env = env)
}

test_that("a different ELFversion rebuilds the ELF list; the same one does not, whatever else changed", {
  reproducible::clearCache(toyPaths()$cachePath, ask = FALSE, verbose = -2)
  counter <- new.env()
  counter$n <- 0L
  expect_identical(buildsOf(counter, ELFversion = "v1", fireYears = 1990:1992), 1L)
  ## same version, another parameter: the list is not built again
  expect_identical(buildsOf(counter, ELFversion = "v1", fireYears = 1990:1992, minNaturalIgnitions = 7), 1L)
  expect_identical(buildsOf(counter, ELFversion = "v1", fireYears = 1990:1993), 1L)
  ## another version: built again
  expect_identical(buildsOf(counter, ELFversion = "v2", fireYears = 1990:1992), 2L)
})

test_that("without fire counting, only a new ELFversion rebuilds the maps", {
  reproducible::clearCache(toyPaths()$cachePath, ask = FALSE, verbose = -2)
  counter <- new.env()
  counter$n <- 0L
  expect_identical(buildsOf(counter, ELFversion = "v1"), 1L)
  expect_identical(buildsOf(counter, ELFversion = "v1", minNaturalIgnitions = 7), 1L)
  expect_identical(buildsOf(counter, ELFversion = "v2"), 2L)
})

test_that("buildELFs() returns the list, with every raster in memory and the plan when counting fires", {
  counter <- new.env()
  counter$n <- 0L
  fakeBuilder(counter)
  local_mocked_bindings(ELFtemplateRaster = function(inputPath) toyGrid() + 1)
  args <- list(inputPath = tempdir(), fireYears = NULL, minNaturalIgnitions = 50, minFirePolygons = 50,
               escapeSizeHa = 50, minEscapes = 5, minRegionAreaKm2 = NA, maxLandCoverDist = 0.35, maxBurnRatio = 6)

  noFires <- do.call(buildELFs, args)
  expect_named(noFires, c("ELFs", "ELFsBeforeMerges", "excluded", "status", "plan"))
  expect_null(noFires$plan)
  expect_true(all(vapply(noFires$ELFs$rasWhole, terra::inMemory, logical(1))))

  args$fireYears <- 1990:1992
  counted <- do.call(buildELFs, args)
  expect_identical(counted$plan$ELF, "3.1.2")
  expect_identical(counted$excluded, character(0))
  expect_true(all(vapply(counted$ELFsBeforeMerges$rasCentered, terra::inMemory, logical(1))))
  expect_true(all(vapply(counted$ELFs$rasCentered, terra::inMemory, logical(1))))
})
