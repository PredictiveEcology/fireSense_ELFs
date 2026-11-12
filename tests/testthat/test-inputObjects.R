## .inputObjects(): a study area must be given (`.ELFind` or `studyArea_fireSense`), and whether the user
## supplied `.ELFind` is recorded -- which is what lets Init tell a request from one it set (see
## .assertOneStudyArea()).

test_that("with neither .ELFind nor studyArea_fireSense, simInit stops and says what to pass", {
  err <- tryCatch(toySimInit(), error = function(e) conditionMessage(e))
  expect_match(err, "studyArea_fireSense")
  expect_match(err, "studyArea_fireSense = studyArea", fixed = TRUE)   # the already-buffered case
  expect_match(err, ".ELFind", fixed = TRUE)
})

test_that("a supplied .ELFind is kept and recorded as supplied", {
  sim <- toySimInit(objects = list(.ELFind = "12.3"))
  expect_identical(sim$.ELFind, "12.3")
  expect_identical(toyModObj(sim, "ELFindSupplied"), TRUE)
})

test_that("supplying only studyArea_fireSense leaves .ELFind unset (init sets it to the ELFs covered)", {
  saFS <- terra::as.polygons(terra::ext(toyGrid()), crs = "EPSG:3978")
  sim <- toySimInit(objects = list(studyArea_fireSense = saFS))
  expect_identical(toyModObj(sim, "ELFindSupplied"), FALSE)
  expect_null(sim$.ELFind)
  ## and the polygon is passed through untouched
  expect_equal(terra::expanse(sim$studyArea_fireSense, unit = "km", transform = FALSE), 60 * 20)
})

test_that("the old name studyAreaLarge still counts as a study area", {
  sal <- terra::as.polygons(terra::ext(toyGrid()), crs = "EPSG:3978")
  sim <- toySimInit(objects = list(studyAreaLarge = sal))
  expect_null(sim$.ELFind)
})

test_that("simInit schedules init and nothing else for this module", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))
  ev <- SpaDES.core::events(sim)
  ev <- ev[ev$moduleName == "fireSense_ELFs", ]
  expect_identical(ev$eventType, "init")
  expect_identical(as.numeric(ev$eventTime), 1)
})
