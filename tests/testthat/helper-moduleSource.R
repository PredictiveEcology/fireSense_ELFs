## The parsed module file, for tests that check what Init does without running it
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

## the parameters that only say where init looks (ledger suffix and files, queue); see test-cacheLabels.R
labelParams <- c("fitFileSuffix", "queue_path", "spreadFitFilename", "ignitionFitFilename")
