## init builds `sppEquiv` from LandR::sppEquivalencies_CA inside the function, so the table's
## contents were not part of the cache key. When LandR changed coastal Douglas-fir's FuelClass
## (LandR #220), ELFs 13.1 and 14.3 kept getting the old sppEquiv from the cache, and every
## downstream event keyed on that sppEquiv hit its stale entry too.
##
## The event needs a full simList, so this checks the parsed module file.

## the digest init puts in the key of the species-table Cache call
sppEquivDigest <- function() {
  caches <- Filter(function(x) identical(x[[1]], quote(reproducible::Cache)), allCalls(initBody()))
  species <- Filter(function(x) identical(as.list(x)[-1][[1]][[1]], quote(LandR::speciesInStudyArea)), caches)
  expect_length(species, 1L)
  if (!length(species)) return(NULL)
  Filter(function(x) identical(x[[1]], quote(reproducible::.robustDigest)), allCalls(species[[1]]$.cacheExtra))[[1]]
}

test_that("the species-table cache key includes a digest of LandR::sppEquivalencies_CA", {
  extra <- sppEquivDigest()
  expect_true(is.call(extra))
  expect_match(paste(deparse(extra), collapse = ""), "LandR::sppEquivalencies_CA", fixed = TRUE)
})

test_that("that digest is the table's, and changes when a FuelClass changes", {
  skip_if_not_installed("LandR")
  skip_if_not_installed("reproducible")
  extra <- sppEquivDigest()
  skip_if(is.null(extra))

  tbl <- data.table::as.data.table(LandR::sppEquivalencies_CA)
  expect_identical(eval(extra), reproducible::.robustDigest(tbl))

  changed <- data.table::copy(tbl)
  ## `set()` rather than `:=`: testthat's environment is not data.table-aware
  ## (cedta()), and `:=` errors there.
  data.table::set(changed, i = which(changed$LandR == "Pseu_men"),
                  j = "FuelClass", value = "SomethingElse")
  expect_false(identical(eval(extra), reproducible::.robustDigest(changed)))
})
