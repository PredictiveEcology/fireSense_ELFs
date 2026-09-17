## init merges ELFs with too few fires, or leaves them out (fireSenseUtils::ELFmergePlan(); the
## decisions themselves are tested in fireSenseUtils). init needs a full simList, the national ELF map
## and the national fire records, so these check the parsed module file.

exprs <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = FALSE)

initBody <- function() {
  def <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
                  identical(x[[2]], as.name("Init")), exprs)
  stopifnot(length(def) == 1L)
  body(eval(def[[1]][[3]]))
}

## every call to `fun` in the module file; the metadata cannot be evaluated whole here, since a
## parameter default refers to `sim`
metadataCalls <- function(fun) {
  found <- list()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1]], as.name(fun))) found[[length(found) + 1L]] <<- x
      for (i in seq_along(x)[-1L]) if (is.call(x[[i]])) walk(x[[i]])
    }
  }
  for (e in exprs) walk(e)
  found
}

allCalls <- function(expr) {
  if (!is.call(expr)) return(list())
  args <- as.list(expr)[-1]
  args <- args[!vapply(args, function(a) missing(a), logical(1))]
  c(list(expr), unlist(lapply(args, allCalls), recursive = FALSE))
}

test_that("init merges thin ELFs before it picks this run's ELF out of the map", {
  code <- deparse(initBody(), width.cutoff = 500L)
  gate <- grep("fewFireELFs(", code, fixed = TRUE)[1]
  pick <- grep("ELFs$rasWhole[[ELF]]", code, fixed = TRUE)[1]
  expect_false(is.na(gate))
  expect_false(is.na(pick))
  expect_lt(gate, pick)
  ## a member's id (e.g. the default .ELFind) is resolved to its merged ELF
  expect_true(any(grepl("ELFrunName(ELF", code, fixed = TRUE)))
})

test_that("the fire counts and the ELF map are cached even when only events are cached", {
  caches <- Filter(function(x) identical(x[[1]], as.name("Cache")), allCalls(initBody()))
  first <- function(cl, fun) {
    a <- as.list(cl)[-1][[1]]
    is.call(a) && (identical(a[[1]], as.name(fun)) ||
                     (is.call(a[[1]]) && identical(a[[1]][[3]], as.name(fun))))
  }
  fewFire <- Filter(function(cl) first(cl, "fewFireELFs"), caches)
  maps <- Filter(function(cl) first(cl, "makeELFs"), caches)
  expect_length(fewFire, 1L)
  expect_length(maps, 1L)
  expect_true(isTRUE(fewFire[[1]]$useCache))
  expect_true(isTRUE(maps[[1]]$useCache))
  ## the shapefiles' local paths differ per job; their names key the result
  expect_setequal(eval(fewFire[[1]]$omitArgs), c("nfdbShp", "nbacShp"))
})

test_that("fireYears and the thresholds are parameters, and the results are outputs", {
  params <- metadataCalls("defineParameter")
  params <- stats::setNames(params, vapply(params, function(cl) as.character(cl[[2]]), ""))
  expect_true(all(c("fireYears", "minNaturalIgnitions", "minFirePolygons") %in% names(params)))
  expect_null(eval(params$fireYears[[4]]))
  expect_identical(eval(params$minNaturalIgnitions[[4]]), 50)
  expect_identical(eval(params$minFirePolygons[[4]]), 50)
  ## runELFs() reads sim$ELFsExcluded by this name
  outputs <- vapply(metadataCalls("createsOutput"), function(cl) as.character(cl[[2]]), "")
  expect_true(all(c("ELFsExcluded", "ELFfireStatus", "ELFmerges") %in% outputs))
})
