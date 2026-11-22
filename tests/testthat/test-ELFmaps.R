## ELFmaps = TRUE: after init, the files for a map of the ELFs: the table of features, the outlines, the fit dates and
## their figure. Google Drive and the fire records are not read: fireSenseUtils::elfFitDates(), latestSpreadFits() and
## ELFfireRates() are replaced by small tables, the rest (elfFeatures(), elfOutlines()) is real. The colours are
## fireSenseUtils::plotELFs()'; its date metric is tested there, here only that the module hands it dates.

fitDatesTable <- function() {
  data.frame(ELF = c("3.1.1", "3.1.2", "5.1", "1.1"),
             spreadFitDate = as.POSIXct(c("2026-09-01 10:00:00", "2026-11-10 09:30:00", NA, NA), tz = "UTC"),
             spreadLedger = c("a.rds", "b.rds", NA, NA),
             ignitionFitDate = as.POSIXct(c("2026-10-05 12:00:00", NA, NA, NA), tz = "UTC"),
             ignitionLedger = c("c.rds", NA, NA, NA))
}

## two ELFs' ledger rows, as latestSpreadFits() returns them
spreadRows <- function() {
  one <- function(id, y) {
    row <- data.frame(polygonID = id, spreadLink = "powerLawSmooth", fuelScale = "linear")
    row$params <- list(data.table::data.table(maxAsymptote = c(0.2, 0.3), `(Intercept)` = y, youngAge = -2,
                                              nfLCC_100_40 = -1, yearSpreadSD = 1.5))
    row
  }
  rbind(one("3.1.1", 4), one("5.1", 6))
}

runFitDates <- function(params = list(), env = parent.frame()) {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = c(list(ELFmaps = TRUE), params))
  mockInitWorld(env = env)
  seen <- new.env()
  local_mocked_bindings(
    elfFitDates = function(spreadFolder, ignitionFolder, destinationPath, ELFs = NULL) {
      seen$args <- list(spreadFolder = if (!missing(spreadFolder)) spreadFolder, destinationPath = destinationPath, ELFs = ELFs)
      fitDatesTable()
    },
    ELFfireRates = function(ELFs, plan, fireYears, pixelAreaHa, destinationPath, ...) {
      seen$rates <- list(ELFs = names(ELFs$rasWhole), fireYears = fireYears, pixelAreaHa = pixelAreaHa)
      data.table::data.table(ELF = c("3.1.1", "3.1.2", "5.1"), naturalFiresPerYear = c(1, 2, 3),
                             naturalFiresPer100km2PerYear = 0.1, haBurnedPerYear = c(10, 20, 30), proportionBurnedPerYear = 0.01)
    },
    latestSpreadFits = function(...) spreadRows(),
    .package = "fireSenseUtils", .env = env)
  reproducible::clearCache(SpaDES.core::cachePath(sim), ask = FALSE, verbose = -2)
  unlink(list.files(SpaDES.core::outputPath(sim), full.names = TRUE))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ## init's own figures are not what is tested here (they need the national ELF numbers): run it with no plots,
  ## then turn them on for the ELFmaps event, which init scheduled
  plots <- sim@params$fireSense_ELFs$.plots
  sim@params$fireSense_ELFs$.plots <- NA
  out <- suppressMessages(SpaDES.core::spades(sim, debug = FALSE, events = list(fireSense_ELFs = "init")))
  out@params$fireSense_ELFs$.plots <- plots
  out <- suppressMessages(SpaDES.core::spades(out, debug = FALSE, events = list(fireSense_ELFs = "ELFmaps")))
  list(sim = out, seen = seen)
}

test_that("ELFmaps is FALSE by default: init schedules no ELFmaps event", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  expect_false(SpaDES.core::params(sim)$fireSense_ELFs$ELFmaps)
  mockInitWorld()
  out <- suppressMessages(runInit(sim))
  done <- SpaDES.core::completed(out)
  expect_false("ELFmaps" %in% done$eventType)
  expect_false(file.exists(file.path(SpaDES.core::outputPath(out), "ELFfitDates.csv")))
  expect_false(file.exists(file.path(SpaDES.core::outputPath(out), "ELFfeatures.csv")))
})

test_that("the ELFmaps event writes the fit dates, the features table, the outlines and the figure to outputPath", {
  r <- runFitDates(params = list(.plots = "png"))
  out <- r$sim
  expect_true("ELFmaps" %in% SpaDES.core::completed(out)$eventType)
  csv <- file.path(SpaDES.core::outputPath(out), "ELFfitDates.csv")
  expect_true(file.exists(csv))
  tab <- data.table::fread(csv, colClasses = list(character = "ELF"))
  expect_identical(names(tab), c("ELF", "spreadFitDate", "spreadLedger", "ignitionFitDate", "ignitionLedger"))
  expect_identical(tab$ELF, c("3.1.1", "3.1.2", "5.1", "1.1"))
  expect_identical(tab$spreadLedger[1:2], c("a.rds", "b.rds"))
  expect_true(all(is.na(tab$spreadFitDate[3:4])))
  ## all of the map's ELFs are asked for, from the default (production) folders, over this run's inputPath
  expect_identical(r$seen$args$ELFs, names(out$ELFs$rasWhole))
  expect_null(r$seen$args$spreadFolder)
  expect_identical(r$seen$args$destinationPath, SpaDES.core::inputPath(out))
  expect_true(file.exists(file.path(SpaDES.core::outputPath(out), "ELFfitDates.png")))

  ## the features: one long table, no row for a value that is missing, per-class non-forest coefficients
  feat <- data.table::fread(file.path(SpaDES.core::outputPath(out), "ELFfeatures.csv"), colClasses = list(character = "ELF"))
  expect_identical(names(feat), c("ELF", "group", "feature", "label", "units", "type", "value"))
  expect_setequal(feat$group, c("Observed", "Fit", "Spread coefficients"))
  expect_false(anyNA(feat$value))
  expect_equal(feat$value[feat$ELF == "3.1.2" & feat$feature == "haBurnedPerYear"], 20)
  expect_equal(feat$value[feat$ELF == "5.1" & feat$feature == "spread_maxAsymptote"], 0.25)
  expect_true(all(c("spread_nfLCC_100", "spread_nfLCC_40") %in% feat$feature[feat$ELF == "3.1.1"]))
  expect_equal(feat$value[feat$ELF == "3.1.2" & feat$feature == "spreadFitDate"], as.numeric(as.Date("2026-11-10")))
  ## the rates are counted on the ELFs, over this run's fire years and cell area
  expect_identical(r$seen$rates$ELFs, names(out$ELFs$rasWhole))
  expect_equal(r$seen$rates$pixelAreaHa, 2500)

  ## the outlines: one core per ELF of the map, in longitude and latitude
  geo <- terra::vect(file.path(SpaDES.core::outputPath(out), "ELFs.geojson"))
  expect_setequal(geo$ELF, names(out$ELFs$rasWhole))
  expect_true(terra::is.lonlat(geo))
  expect_true("name" %in% names(geo))
})

test_that("with .plots off the table is still written and no figure is", {
  r <- runFitDates(params = list(.plots = NA))
  expect_true(file.exists(file.path(SpaDES.core::outputPath(r$sim), "ELFfitDates.csv")))
  expect_length(list.files(SpaDES.core::outputPath(r$sim), pattern = "ELFfitDates\\.(png|pdf)$"), 0L)
})

test_that("plotFitDates() draws one panel per ledger on one date scale, with no-fit ELFs grey", {
  drawn <- list()
  local_mocked_bindings(
    plotELFs = function(...) drawn[[length(drawn) + 1L]] <<- list(...),
    .package = "fireSenseUtils")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot.new()
  plotFitDates(fitDatesTable(), ELFs = toyELFs(), plan = NULL)
  expect_length(drawn, 2L)
  expect_identical(vapply(drawn, `[[`, "", "metric"), c("spreadFitDate", "ignitionFitDate"))
  ## one scale: the oldest date over both ledgers to the newest
  expect_identical(drawn[[1]]$metricRange, drawn[[2]]$metricRange)
  expect_equal(drawn[[1]]$metricRange, as.numeric(as.Date(c("2026-09-01", "2026-11-10"))))
  expect_identical(drawn[[1]]$which, c("5.1", "1.1"))
  expect_identical(drawn[[2]]$which, c("3.1.2", "5.1", "1.1"))
  expect_identical(drawn[[1]]$fill, "grey70")
})

test_that("ELFmaps is FALSE and ELFmaps is never cached, by default", {
  md <- SpaDES.core::moduleMetadata(module = "fireSense_ELFs", path = dirname(toyModuleRoot()))
  p <- md$parameters
  expect_identical(p$paramClass[p$paramName == "ELFmaps"][[1]], "logical")
  p <- SpaDES.core::params(toySimInit(objects = list(.ELFind = "3.1.2")))$fireSense_ELFs
  expect_identical(p$.neverCache, "ELFmaps")
  expect_false(p$ELFmaps)
})
