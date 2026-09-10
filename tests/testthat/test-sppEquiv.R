## Init builds `sppEquiv` in a `sppEquiv <- { ... }` block. 64867e4 appended an Engelmann
## spruce merge as the block's last expression -- an `if` with no `else` -- so the block
## evaluated to NULL for every ELF without Engelmann spruce, and the LANDIS_traits filter
## above it, no longer the last expression, was computed and thrown away. The NULL reached
## Biomass_speciesData through fireSense_dataPrepFit's nested simInit, and LandR's SCANFI
## loader stopped with "object 'LandR' not found": on 2026-09-10 that failed most ELFs
## about 25 minutes into each fit.
##
## The block is inline in Init, so this evaluates the block itself, parsed from the module
## file, with the species lookup stubbed.

sppEquivBlock <- function() {
  exprs <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = FALSE)
  found <- NULL
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name("sppEquiv")) &&
          is.call(x[[3]]) && identical(x[[3]][[1]], as.name("{")))
        found <<- x[[3]]
      for (i in seq_along(x)[-1L]) if (is.call(x[[i]])) walk(x[[i]])
    }
  }
  for (e in exprs) walk(e)
  found
}

runBlock <- function(speciesList) {
  local_mocked_bindings(speciesInStudyArea = function(...) list(speciesList = speciesList),
                        .package = "LandR", .env = parent.frame())
  local_mocked_bindings(Cache = function(FUN, ...) FUN, .package = "reproducible",
                        .env = parent.frame())
  env <- new.env(parent = globalenv())
  env$P <- function(sim) list(sppEquivCol = "LandR")
  env$sim <- NULL
  env$studyAreaELF <- structure(list(), tags = "studyAreaELF")
  env$inputPath <- tempdir()
  eval(sppEquivBlock(), env)
}

test_that("the sppEquiv block is found in Init", {
  expect_false(is.null(sppEquivBlock()))
})

test_that("an ELF without Engelmann spruce gets a species table, not NULL", {
  withr::local_package("data.table")
  ## Vancouver Island (13.1)-like species, plus POPU_GRA, which has no LANDIS traits
  spp <- c("ABIE_AMA", "ALNU_RUB", "PSEU_MEN", "THUJ_PLI", "TSUG_HET", "POPU_GRA")
  out <- runBlock(spp)

  expect_s3_class(out, "data.table")
  expect_true(all(c("Abie_ama", "Tsug_het", "Thuj_pli") %in% out$LandR))
  ## the LANDIS_traits filter is applied
  expect_true(all(out$LANDIS_traits != ""))
  expect_false("Popu_gra" %in% out$LandR)
})

test_that("an ELF with Engelmann spruce gets the merged Pice_eng row and the filter", {
  withr::local_package("data.table")
  spp <- c("PICE_ENG", "PICE_ENG_GLA", "PSEU_MEN", "POPU_GRA")
  out <- runBlock(spp)

  expect_s3_class(out, "data.table")
  expect_true("Pice_eng" %in% out$LandR)
  expect_false("Pice_eng_gla" %in% out$LandR)
  expect_true(all(out$LANDIS_traits != ""))
  expect_false("Popu_gra" %in% out$LandR)
})
