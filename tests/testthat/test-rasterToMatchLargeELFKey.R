## The single-ELF rasterToMatchLargeELF was cached on tags alone (`x` is omitted), so when the ELF
## raster it is built from changed under the same tags (a rebuilt national list), one key held two
## different rasters and event entries built on the old one stayed valid.
##
## Init needs a full simList, so this evaluates the Cache call's `.cacheExtra` from the parsed file.

rtmlCacheExtra <- function() {
  caches <- Filter(function(x) identical(x[[1]], quote(Cache)) &&
                     grepl("rasterToMatchLargeELF", paste(deparse(x$.functionName), collapse = ""), fixed = TRUE),
                   allCalls(initBody()))
  expect_length(caches, 1L)
  caches[[1]]$.cacheExtra
}

keyOf <- function(rtml) {
  env <- new.env(parent = globalenv())
  env$ELFs <- structure(list(), tags = "ELFs")
  env$rastTemplate <- structure(list(), tags = "template")
  env$ELF <- "11.3"
  env$borderCacheExtra <- list(borderBuffer = 0)
  env$rtml <- rtml
  reproducible::.robustDigest(eval(rtmlCacheExtra(), env))
}

test_that("two different ELF rasters under the same tags give different rasterToMatchLargeELF keys", {
  skip_if_not_installed("reproducible")
  a <- terra::rast(nrows = 4, ncols = 4, vals = 1)
  b <- a
  b[3] <- 2
  expect_identical(keyOf(a), keyOf(a + 0))
  expect_false(identical(keyOf(a), keyOf(b)))
})
