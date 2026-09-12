## Init takes its species table from LandR::speciesInStudyArea()$sppEquiv (LandR >= 1.2.0.9012),
## which builds it the way this module used to by hand: no `_Spp` genus entries, only species
## with LANDIS traits, Engelmann spruce merged into Pice_eng. The hand-built version returned
## NULL for every ELF without Engelmann spruce (fixed in #7); the table's logic is now tested in
## LandR. This checks the wiring: the two Init statements, parsed from the module file, with the
## LandR call stubbed.

initStatements <- function() {
  exprs <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = FALSE)
  found <- list()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1]], as.name("<-")) && is.name(x[[2]]) &&
          as.character(x[[2]]) %in% c("species", "sppEquiv"))
        found[[length(found) + 1L]] <<- x
      for (i in seq_along(x)[-1L]) if (is.call(x[[i]])) walk(x[[i]])
    }
  }
  for (e in exprs) walk(e)
  found
}

test_that("Init takes sppEquiv from LandR::speciesInStudyArea()", {
  stmts <- initStatements()
  txt <- vapply(stmts, function(s) paste(deparse(s), collapse = " "), character(1))
  getSpecies <- stmts[grepl("^species <- .*speciesInStudyArea", txt)]
  takeTable <- stmts[txt == "sppEquiv <- species$sppEquiv"]
  expect_length(getSpecies, 1L)
  expect_length(takeTable, 1L)
  skip_if(length(getSpecies) != 1L || length(takeTable) != 1L)

  sentinel <- data.frame(LandR = "Abie_ama")
  args <- NULL
  local_mocked_bindings(speciesInStudyArea = function(...) {
    args <<- list(...)
    list(speciesList = "ABIE_AMA", sppEquiv = sentinel)
  }, .package = "LandR")
  local_mocked_bindings(Cache = function(FUN, ...) FUN, .package = "reproducible")

  env <- new.env(parent = globalenv())
  env$P <- function(sim) list(sppEquivCol = "LandR")
  env$sim <- NULL
  env$studyAreaELF <- structure(list(), tags = "studyAreaELF")
  env$inputPath <- tempdir()
  eval(getSpecies[[1]], env)
  eval(takeTable[[1]], env)

  expect_identical(env$sppEquiv, sentinel)
  expect_identical(args$sppEquivCol, "LandR")
})
