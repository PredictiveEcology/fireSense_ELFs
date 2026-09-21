## plotAllELFsFn() draws every ELF's core, overlays the fitted ELFs in green and the running
## ones in yellow, and labels each ELF. terra's plot() and text() are replaced by recorders,
## so the test sees exactly what would be drawn.

recordPlots <- function(env = parent.frame()) {
  calls <- new.env()
  calls$plot <- list()
  calls$text <- list()
  local_mocked_bindings(
    plot = function(x, ...) {
      calls$plot[[length(calls$plot) + 1L]] <- c(list(x = x), list(...))
      invisible(NULL)
    },
    text = function(x, ...) {
      calls$text[[length(calls$text) + 1L]] <- c(list(x = x), list(...))
      invisible(NULL)
    },
    .package = "terra", .env = env
  )
  calls
}

test_that("with nothing fitted or running, only the ELF cores and their labels are drawn", {
  calls <- recordPlots()
  plotAllELFsFn(toyELFs()$rasCentered, crsToUse = "EPSG:3978", alreadyRun = NULL, runningELFs = NULL)

  expect_length(calls$plot, 1L)
  all4 <- calls$plot[[1]]$x
  expect_equal(nrow(all4), 4)
  ## each core is 3 cols x 4 rows of 5 km cells = 12 * 25 km2 = 300 km2; buffers are not drawn
  expect_equal(terra::expanse(all4, unit = "km", transform = FALSE), rep(300, 4))

  expect_length(calls$text, 1L)
  ## as.polygons() can make the layer names syntactic ("X3.1.1"); the labels drop the X again
  expect_identical(calls$text[[1]]$label, c("3.1.1", "3.1.2", "5.1", "1.1"))
  ## labels sit at the core centroids: x = middle of cols 1-3, 4-6, 7-9, 10-12
  expect_equal(terra::crds(calls$text[[1]]$x)[, "x"], c(7500, 22500, 37500, 52500))
})

test_that("fitted ELFs are overlaid in green", {
  calls <- recordPlots()
  fitted <- sf::st_as_sf(terra::as.polygons(terra::ext(0, 15000, 0, 20000), crs = "EPSG:3978"))
  fitted$polygonID <- "3.1.1"
  plotAllELFsFn(toyELFs()$rasCentered, crsToUse = "EPSG:3978",
                alreadyRun = as.data.frame(fitted), runningELFs = NULL)

  expect_length(calls$plot, 2L)
  green <- calls$plot[[2]]
  expect_identical(green$col, "green")
  expect_true(green$add)
  expect_identical(green$alpha, 0.5)
  expect_identical(green$x$polygonID, "3.1.1")
})

test_that("running ELFs are overlaid in yellow, matched by name", {
  calls <- recordPlots()
  plotAllELFsFn(toyELFs()$rasCentered, crsToUse = "EPSG:3978",
                alreadyRun = NULL, runningELFs = c("5.1", "3.1.2"))

  expect_length(calls$plot, 2L)
  yellow <- calls$plot[[2]]
  expect_identical(yellow$col, "yellow")
  expect_true(yellow$add)
  ## rows 3 (5.1) then 2 (3.1.2) of the ELF polygons, in the order asked for
  expect_equal(terra::crds(terra::centroids(yellow$x))[, "x"], c(37500, 22500))
})

test_that("an empty table of fitted ELFs and no running ELFs add no overlay", {
  calls <- recordPlots()
  plotAllELFsFn(toyELFs()$rasCentered, crsToUse = "EPSG:3978",
                alreadyRun = data.frame(), runningELFs = character(0))
  expect_length(calls$plot, 1L)
})

test_that("the ELFs are drawn in the CRS asked for", {
  calls <- recordPlots()
  plotAllELFsFn(toyELFs()$rasCentered, crsToUse = "EPSG:4326", alreadyRun = NULL, runningELFs = NULL)
  expect_true(terra::is.lonlat(calls$plot[[1]]$x))
})
