## init merges ELFs with too few fires, or leaves them out (fireSenseUtils::ELFmergePlan(); the
## decisions themselves are tested in fireSenseUtils). init needs a full simList, the national ELF map
## and the national fire records, so these check the parsed module file.

test_that("init merges thin ELFs before it picks this run's ELF out of the map", {
  code <- deparse(initBody(), width.cutoff = 500L)
  gate <- grep("buildELFs(", code, fixed = TRUE)[1]
  pick <- grep("ELFs$rasWhole[[ELF]]", code, fixed = TRUE)[1]
  expect_false(is.na(gate))
  expect_false(is.na(pick))
  expect_lt(gate, pick)
  ## a member's id (e.g. the default .ELFind) is resolved to its merged ELF
  expect_true(any(grepl("ELFrunName(ELF", code, fixed = TRUE)))
})

test_that("the national ELF list is one Cache call, keyed on ELFversion alone", {
  caches <- Filter(function(x) identical(x[[1]], as.name("Cache")), allCalls(initBody()))
  built <- Filter(function(cl) identical(as.list(cl)[-1][[1]][[1]], as.name("buildELFs")), caches)
  expect_length(built, 1L)
  cl <- built[[1]]
  ## cached even when only events are cached
  expect_true(isTRUE(cl$useCache))
  expect_identical(cl$.cacheExtra, quote(list(ELFversion = Par$ELFversion)))
  ## no argument and not the function body is in the key: only the version is
  expect_identical(cl$omitArgs, quote(c("FUN", names(formals(buildELFs)))))
  ## the pieces buildELFs() replaces are no longer cached separately
  expect_false(any(vapply(caches, function(x) {
    a <- as.list(x)[-1][[1]]
    is.call(a) && any(vapply(allCalls(a), function(y) any(grepl("makeELFs|fewFireELFs", format(y[[1]]))), logical(1)))
  }, logical(1))))
})

test_that("fireYears and the thresholds are parameters, and the results are outputs", {
  params <- metadataCalls("defineParameter")
  params <- stats::setNames(params, vapply(params, function(cl) as.character(cl[[2]]), ""))
  expect_true(all(c("fireYears", "minNaturalIgnitions", "minFirePolygons", "escapeSizeHa", "minEscapes") %in% names(params)))
  expect_identical(eval(params$fireYears[[4]]), fireSenseUtils::defaultFireYears())
  expect_identical(eval(params$minNaturalIgnitions[[4]]), 50)
  expect_identical(eval(params$minFirePolygons[[4]]), 50)
  expect_identical(eval(params$escapeSizeHa[[4]]), 50)
  expect_identical(eval(params$minEscapes[[4]]), 5)
  ## runELFs() reads sim$ELFsExcluded by this name
  outputs <- vapply(metadataCalls("createsOutput"), function(cl) as.character(cl[[2]]), "")
  expect_true(all(c("ELFsExcluded", "ELFfireStatus", "ELFmerges") %in% outputs))
})

test_that("init flags other modules' different fireYears with a warning, only when counting", {
  gated <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("if")) &&
                    identical(x[[2]], quote(!is.null(Par$fireYears))), allCalls(initBody()))
  expect_length(gated, 1L)
  checks <- Filter(function(x) identical(x[[1]], quote(SpaDES.core::paramCheckOtherMods)) &&
                     identical(x[[3]], "fireYears"), allCalls(gated[[1]]))
  expect_length(checks, 1L)
  expect_identical(checks[[1]]$ifSetButDifferent, "warning")
  ## escapeSizeHa is checked the same way against fireSense_dataPrepFit's
  checks <- Filter(function(x) identical(x[[1]], quote(SpaDES.core::paramCheckOtherMods)) &&
                     identical(x[[3]], "escapeSizeHa"), allCalls(gated[[1]]))
  expect_length(checks, 1L)
  expect_identical(checks[[1]]$ifSetButDifferent, "warning")
})

test_that("init draws the ELFs after the merges through Plots(), whose .plots decides the file type", {
  calls <- Filter(function(x) identical(x[[1]], quote(Plots)) &&
                    identical(x$fn, quote(fireSenseUtils::plotELFs)), allCalls(initBody()))
  expect_length(calls, 1L)
  expect_identical(calls[[1]]$plan, quote(ELFmerges))
  expect_identical(calls[[1]]$filename, "ELFs_postMerge")        # no extension: not a file type of ours
  expect_true(is.null(calls[[1]]$types))
})
