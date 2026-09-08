## fireSense_ELFs takes its study area either from `.ELFind` (fitting) or from
## `studyAreaLarge` (prediction). Given both, it used to use `studyAreaLarge`
## and ignore `.ELFind`, while the folders were still named from `.ELFind`:
## on 2026-09-07/08 that yielded five "different" ELF fits of one study area.

source(testthat::test_path("..", "..", "R", "assertOneStudyArea.R"))

test_that("a defaulted .ELFind cannot conflict with anything", {
  expect_null(.assertOneStudyArea("4.3", elfIndSupplied = FALSE,
                                  elfsInStudyAreaLarge = c("5.2", "6.1")))
})

test_that("no error when the polygon resolves to exactly the ELF that was asked for", {
  expect_null(.assertOneStudyArea("12.3", TRUE, "12.3"))
  expect_null(.assertOneStudyArea("12.3", TRUE, c("12.3", "12.3")))
})

test_that("the real case errors, naming both study areas", {
  # 2026-09-08: .ELFind = 12.3 while studyAreaLarge was the Mountain Caribou area.
  expect_error(.assertOneStudyArea("12.3", TRUE, c("5.2", "6.1")),
               "different study areas")
  expect_error(.assertOneStudyArea("12.3", TRUE, c("5.2", "6.1")), "12\\.3")
  expect_error(.assertOneStudyArea("12.3", TRUE, c("5.2", "6.1")), "5\\.2, 6\\.1")
})

test_that("a studyAreaLarge covering the requested ELF plus others is still a conflict", {
  # Ambiguous: the run would fit several ELFs but be labelled with one.
  expect_error(.assertOneStudyArea("12.3", TRUE, c("12.3", "12.4")), "different study areas")
})

test_that("a studyAreaLarge covering no ELF is a conflict, and says so", {
  expect_error(.assertOneStudyArea("12.3", TRUE, character(0)), "covers ELF\\(s\\): none")
})

test_that("an empty .ELFind with a real studyAreaLarge is reported, not silently accepted", {
  expect_error(.assertOneStudyArea("", TRUE, "6.1"), "<empty>")
})

## The other half of the fix: this module must be scheduled before the modules
## that work in the study area it defines. Without it, callers forced the order by
## passing a `studyAreaLarge` they did not want -- the cause of the incident above.
test_that("the module declares itself before the other fireSense modules", {
  md <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = TRUE)
  dm <- Filter(function(e) grepl("^defineModule", paste(deparse(e), collapse = "")), as.list(md))
  lo <- eval(dm[[1]][[3]]$loadOrder)
  expect_type(lo, "list")
  expect_true(all(c("fireSense_dataPrepFit", "fireSense_SpreadFit",
                    "fireSense_SpreadPredict", "fireSense_dataPrepPredict") %in% lo$before))
  expect_null(lo$after)
})
