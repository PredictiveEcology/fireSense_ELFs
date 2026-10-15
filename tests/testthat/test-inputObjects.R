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

test_that("the fallback ELF is announced once, with how to choose another", {
  msgs <- testthat::capture_messages(toySimInit(quiet = FALSE))
  hit <- grep("4\\.3", msgs, value = TRUE)
  expect_length(hit, 1L)
  expect_match(hit, "\\.ELFind")
  expect_match(hit, "studyAreaLarge")
})

test_that("no fallback message when .ELFind or studyAreaLarge is supplied", {
  expect_no_match(testthat::capture_messages(toySimInit(objects = list(.ELFind = "12.3"), quiet = FALSE)), "4\\.3")
  sal <- terra::as.polygons(terra::ext(toyGrid()), crs = "EPSG:3978")
  expect_no_match(testthat::capture_messages(toySimInit(objects = list(studyAreaLarge = sal), quiet = FALSE)), "4\\.3")
})
