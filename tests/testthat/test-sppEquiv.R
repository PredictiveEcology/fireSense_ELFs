## Init takes its species table from LandR::speciesInStudyArea()$sppEquiv (LandR >= 1.2.0.9021),
## which builds it the way this module used to by hand: no `_Spp` genus entries, only species
## with LANDIS traits, Engelmann spruce merged into Pice_eng. The hand-built version returned
## NULL for every ELF without Engelmann spruce (fixed in #7); the table's logic is now tested in
## LandR. This checks the wiring: the Init statements, parsed from the module file, with the
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

## The no-tree-species announcement is a bare `if`, not an assignment, so it is collected
## separately from the statements above.
announceStatement <- function() {
  exprs <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = FALSE)
  found <- list()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1]], as.name("if")) &&
          grepl("NROW(sppEquiv)", paste(deparse(x[[2]]), collapse = " "), fixed = TRUE))
        found[[length(found) + 1L]] <<- x
      for (i in seq_along(x)[-1L]) if (is.call(x[[i]])) walk(x[[i]])
    }
  }
  for (e in exprs) walk(e)
  found
}

## Runs Init's species statements with `speciesInStudyArea()` stubbed to return `sppEquiv`,
## and reports what Init did with it (the table it kept, and the arguments it passed).
runInit <- function(sppEquiv, ELF = "13.1") {
  stmts <- initStatements()
  txt <- vapply(stmts, function(s) paste(deparse(s), collapse = " "), character(1))
  getSpecies <- stmts[grepl("^species <- .*speciesInStudyArea", txt)]
  takeTable <- stmts[txt == "sppEquiv <- species$sppEquiv"]
  announce <- announceStatement()
  expect_length(getSpecies, 1L)
  expect_length(takeTable, 1L)
  expect_length(announce, 1L)

  args <- NULL
  local_mocked_bindings(speciesInStudyArea = function(...) {
    args <<- list(...)
    list(speciesList = "ABIE_AMA", sppEquiv = sppEquiv)
  }, .package = "LandR", .env = parent.frame())
  local_mocked_bindings(Cache = function(FUN, ...) FUN, .package = "reproducible",
                        .env = parent.frame())

  env <- new.env(parent = globalenv())
  env$P <- function(sim) list(sppEquivCol = "LandR")
  env$sim <- NULL
  env$studyAreaELF <- structure(list(), tags = "studyAreaELF")
  env$inputPath <- tempdir()
  env$ELF <- ELF
  eval(getSpecies[[1]], env)
  eval(takeTable[[1]], env)
  eval(announce[[1]], env)
  list(sppEquiv = env$sppEquiv, args = args)
}

test_that("Init takes sppEquiv from LandR::speciesInStudyArea()", {
  sentinel <- data.frame(LandR = "Abie_ama")
  out <- runInit(sentinel)

  expect_identical(out$sppEquiv, sentinel)
  ## The naming convention has to reach LandR, or the returned table is keyed on the wrong column.
  expect_identical(out$args$sppEquivCol, "LandR")
})

## Four ELFs (3.2.1, 3.2.4, 3.2.5, 3.3.2) have no tree species at all. That is a valid state
## (the fit uses nonForest fuel classes only); it must be announced once, here, and yield a
## 0-row table rather than NULL. LandR returns the 0-row table; this module announces it.
test_that("an ELF with no tree species says so once and gets a 0-row table", {
  ## Subset the base way, never `DT[0]`: `[.data.table`'s NSE applies only to callers data.table
  ## considers aware (`cedta()`), and a testthat frame inside this module's package namespace is
  ## not one. There `DT[0]` is `[.data.frame`, which selects zero COLUMNS -- it passes when these
  ## tests run from the global environment and fails under R CMD check.
  empty <- LandR::sppEquivalencies_CA[integer(0), , drop = FALSE]
  out <- NULL
  msgs <- capture_messages(out <- runInit(empty, ELF = "3.2.1"))

  expect_equal(sum(grepl("no tree species", msgs)), 1L)
  expect_true(any(grepl("3.2.1", msgs)))
  expect_s3_class(out$sppEquiv, "data.table")
  expect_identical(nrow(out$sppEquiv), 0L)
  expect_identical(names(out$sppEquiv), names(LandR::sppEquivalencies_CA))
})

test_that("an ELF with tree species emits no such message", {
  ## `$` rather than `[.data.table`'s NSE, for the cedta() reason above.
  someSpecies <- LandR::sppEquivalencies_CA[
    LandR::sppEquivalencies_CA$LandR %in% c("Abie_ama", "Pseu_men"), , drop = FALSE]
  expect_gt(nrow(someSpecies), 0L)

  msgs <- capture_messages(runInit(someSpecies))
  expect_false(any(grepl("no tree species", msgs)))
})
