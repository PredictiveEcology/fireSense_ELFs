## .inputObjects(): the default `.ELFind`, and whether the user supplied one -- which is what
## lets Init tell a request from a default (see .assertOneStudyArea()).

test_that(".ELFind defaults to 4.3 and is recorded as not supplied", {
  sim <- toySimInit()
  expect_identical(sim$.ELFind, "4.3")
  expect_identical(toyModObj(sim, "ELFindSupplied"), FALSE)
})

test_that("a supplied .ELFind is kept and recorded as supplied", {
  sim <- toySimInit(objects = list(.ELFind = "12.3"))
  expect_identical(sim$.ELFind, "12.3")
  expect_identical(toyModObj(sim, "ELFindSupplied"), TRUE)
})

test_that("supplying only studyAreaLarge leaves .ELFind a default, so it cannot conflict", {
  sal <- terra::as.polygons(terra::ext(toyGrid()), crs = "EPSG:3978")
  sim <- toySimInit(objects = list(studyAreaLarge = sal))
  expect_identical(toyModObj(sim, "ELFindSupplied"), FALSE)
  expect_identical(sim$.ELFind, "4.3")
  ## and the polygon is passed through untouched
  expect_equal(terra::expanse(sim$studyAreaLarge, unit = "km", transform = FALSE), 60 * 20)
})

test_that("simInit schedules init and nothing else for this module", {
  sim <- toySimInit()
  ev <- SpaDES.core::events(sim)
  ev <- ev[ev$moduleName == "fireSense_ELFs", ]
  expect_identical(ev$eventType, "init")
  expect_identical(as.numeric(ev$eventTime), 1)
})
