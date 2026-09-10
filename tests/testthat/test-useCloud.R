## The init event's Cache is shared through the canonical fireSense Google Drive folder,
## the one that also holds the fitted-parameter ledger (`spreadFitGoogleDriveFolder`).
## Before, cloud caching was off and pointed at a hard-coded folder ID that no other
## module or person used, so no ELF map was ever shared.
##
## The event needs a full simList, so this checks the parsed module file.
exprs <- parse(testthat::test_path("..", "..", "fireSense_ELFs.R"), keep.source = FALSE)

paramDefault <- function(name) {
  found <- list()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1]], as.name("defineParameter")) && identical(x[[2]], name))
        found[[length(found) + 1L]] <<- x
      for (i in seq_along(x)[-1L]) if (is.call(x[[i]])) walk(x[[i]])
    }
  }
  for (e in exprs) walk(e)
  expect_length(found, 1L)
  if (!length(found)) return(NULL)
  cl <- found[[1]]
  if (!is.null(cl$default)) cl$default else cl[[4]]
}

test_that(".useCloud is on by default", {
  expect_identical(paramDefault(".useCloud"), TRUE)
})

test_that("the init event caches to the spreadFitGoogleDriveFolder, not a hard-coded folder", {
  initArgs <- eval(paramDefault(".useCacheArgs"))$init
  expect_true(is.call(initArgs$useCloud))
  expect_match(paste(deparse(initArgs$useCloud), collapse = ""), ".useCloud", fixed = TRUE)
  expect_true(is.call(initArgs$cloudFolderID))
  expect_match(paste(deparse(initArgs$cloudFolderID), collapse = ""),
               "spreadFitGoogleDriveFolder", fixed = TRUE)
})
