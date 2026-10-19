## Run labels (the ledger suffix and file names, the queue path) are part of an event's cache key
## but change nothing the event returns, so a new label recomputed `.inputObjects` and `init`
## (40 and 44 reruns, 2026-10-14 to 2026-10-19). `init` also reads the Google Drive ledgers and the
## tmux queue, so a cached `init` replays a stale answer: it is never cached.

test_that(".neverCache keeps init out of the cache whatever .useCache says", {
  md <- SpaDES.core::moduleMetadata(module = "fireSense_ELFs", path = dirname(toyModuleRoot()))
  declared <- md$parameters$default[[which(md$parameters$paramName == ".neverCache")]]
  expect_identical(declared, "init")
  eventIsCached <- utils::getFromNamespace(".eventIsCached", "SpaDES.core")
  for (useCache in list(c(".inputObjects", "init"), TRUE))
    expect_false(eventIsCached(list(.useCache = useCache, .neverCache = declared), "init")$cache)
})

test_that("a new run label hits the cached .inputObjects and keeps its own value", {
  nEntries <- function(sim) {
    sc <- reproducible::showCache(SpaDES.core::cachePath(sim), verbose = -2)
    length(unique(sc$cacheId[sc$tagKey == "function" & sc$tagValue == ".inputObjects_fireSense_ELFs"]))
  }
  paths <- toyPaths()
  reproducible::clearCache(paths$cachePath, ask = FALSE, verbose = -2)
  sim1 <- toySimInit(params = list(.useCache = ".inputObjects", fitFileSuffix = "a", queue_path = "q1",
                                   spreadFitFilename = "s1.rds", ignitionFitFilename = "i1.rds"))
  expect_identical(nEntries(sim1), 1L)
  sim2 <- toySimInit(params = list(.useCache = ".inputObjects", fitFileSuffix = "b", queue_path = "q2",
                                   spreadFitFilename = "s2.rds", ignitionFitFilename = "i2.rds"))
  expect_identical(nEntries(sim2), 1L)
  p <- SpaDES.core::params(sim2)$fireSense_ELFs
  expect_identical(p$fitFileSuffix, "b")
  expect_identical(p$queue_path, "q2")
  expect_identical(p$spreadFitFilename, "s2.rds")
  expect_identical(p$ignitionFitFilename, "i2.rds")
  ## a parameter that is not a label still changes the key
  toySimInit(params = list(.useCache = ".inputObjects", minEscapes = 6))
  expect_identical(nEntries(sim2), 2L)
})

test_that("the .inputObjects omitParams name only parameters .inputObjects does not read", {
  md <- SpaDES.core::moduleMetadata(module = "fireSense_ELFs", path = dirname(toyModuleRoot()))
  args <- md$parameters$default[[which(md$parameters$paramName == ".useCacheArgs")]]
  expect_setequal(args$.inputObjects$omitParams, labelParams)
  body <- paste(deparse(body(eval(Filter(function(x) is.call(x) && identical(x[[2]], as.name(".inputObjects")),
                                          exprs)[[1]][[3]]))), collapse = "\n")
  for (p in labelParams) expect_false(grepl(p, body, fixed = TRUE))
})

test_that("the species table is cached without its download folder", {
  caches <- Filter(function(x) identical(x[[1]], quote(reproducible::Cache)), allCalls(initBody()))
  species <- Filter(function(x) identical(as.list(x)[-1][[1]][[1]], quote(LandR::speciesInStudyArea)), caches)
  expect_length(species, 1L)
  expect_true(all(c("studyArea", "dPath") %in% eval(species[[1]]$omitArgs)))
})
