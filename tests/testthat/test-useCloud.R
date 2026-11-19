## The national ELF list's Cache is shared through its own Google Drive folder (`ELFsGoogleDriveFolder`,
## default fireSenseUtils::elfCacheFolder()), not the fitted-parameter ledger folder it used to share.
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

test_that("the national ELF list is cached to ELFsGoogleDriveFolder, not the ledger folder", {
  caches <- Filter(function(x) identical(x[[1]], as.name("Cache")), allCalls(initBody()))
  built <- Filter(function(cl) identical(as.list(cl)[-1][[1]][[1]], as.name("buildELFs")), caches)
  expect_length(built, 1L)
  expect_identical(built[[1]]$useCloud, quote(Par$.useCloud))
  expect_identical(built[[1]]$cloudFolderID, quote(Par$ELFsGoogleDriveFolder))
  expect_identical(paramDefault("ELFsGoogleDriveFolder"), quote(fireSenseUtils::elfCacheFolder()))
})
