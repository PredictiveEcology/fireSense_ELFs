## init builds `sppEquiv` from LandR::sppEquivalencies_CA inside the function, so the table's
## contents were not part of the init event's cache key. When LandR changed coastal
## Douglas-fir's FuelClass (LandR #220), ELFs 13.1 and 14.3 kept getting the old sppEquiv
## from the cache -- locally, and from the shared Drive folder once `.useCloud` was on --
## and every downstream event keyed on that sppEquiv hit its stale entry too.
##
## The event needs a full simList, so this checks the parsed module file.
exprs <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = FALSE)

initCacheArgs <- function() {
  found <- list()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1]], as.name("defineParameter")) && identical(x[[2]], ".useCacheArgs"))
        found[[length(found) + 1L]] <<- x
      for (i in seq_along(x)[-1L]) if (is.call(x[[i]])) walk(x[[i]])
    }
  }
  for (e in exprs) walk(e)
  expect_length(found, 1L)
  if (!length(found)) return(NULL)
  cl <- found[[1]]
  eval(if (!is.null(cl$default)) cl$default else cl[[4]])$init
}

test_that("the init cache key includes a digest of LandR::sppEquivalencies_CA", {
  extra <- initCacheArgs()$.cacheExtra
  expect_true(is.call(extra))
  expect_match(paste(deparse(extra), collapse = ""), "LandR::sppEquivalencies_CA", fixed = TRUE)
})

test_that("that digest is the table's, and changes when a FuelClass changes", {
  skip_if_not_installed("LandR")
  skip_if_not_installed("reproducible")
  extra <- initCacheArgs()$.cacheExtra
  skip_if(is.null(extra))

  tbl <- data.table::as.data.table(LandR::sppEquivalencies_CA)
  expect_identical(eval(extra), reproducible::.robustDigest(tbl))

  changed <- data.table::copy(tbl)
  changed[LandR == "Pseu_men", FuelClass := "SomethingElse"]
  expect_false(identical(eval(extra), reproducible::.robustDigest(changed)))
})
