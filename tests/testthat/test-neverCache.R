## `.neverCache` (read by SpaDES.core >= 3.2.1.9037) wins over every form of `.useCache`, including a
## `.globals$.useCache` that lists the event. `init` reads the spread-fit and ignition-fit ledgers on Google Drive, which are not part of the event's cache key.
test_that(".neverCache is declared and SpaDES.core refuses to cache those events whatever .useCache says", {
  md <- SpaDES.core::moduleMetadata(module = "fireSense_ELFs", path = dirname(toyModuleRoot()))
  declared <- md$parameters$default[[which(md$parameters$paramName == ".neverCache")]]
  expect_setequal(declared, c("init"))
  eventIsCached <- utils::getFromNamespace(".eventIsCached", "SpaDES.core")
  for (useCache in list(c(".inputObjects", declared), TRUE)) {
    for (ev in declared)
      expect_false(eventIsCached(list(.useCache = useCache, .neverCache = declared), ev)$cache)
  }
  ## and the helper still caches what `.useCache` names that `.neverCache` does not list
  expect_true(eventIsCached(list(.useCache = ".inputObjects", .neverCache = declared), ".inputObjects")$cache)
})
