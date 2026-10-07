## Cells within `borderBuffer` metres of the Canada-US land border are removed from the ELFs.
## Toy grid of helper-toyELFs.R: 5 km cells, columns 1-12. A vertical border at x = 30000 lies
## between columns 6 and 7, so with a 5 km buffer columns 6 and 7 (centres 2.5 km away) go and
## column 5 (7.5 km away) stays.

test_that("selectCanadaUSBorder keeps Canada-US land segments, in either order, and drops the rest", {
  lines <- terra::vect(lapply(1:4, function(i) terra::vect(cbind(c(0, 1), c(i, i)), type = "lines",
                                                           crs = "EPSG:4326")))
  lines$ADM0_A3_L <- c("CAN", "USA", "MEX", "CAN")
  lines$ADM0_A3_R <- c("USA", "CAN", "USA", "RUS")
  expect_equal(nrow(selectCanadaUSBorder(lines)), 2)
})

test_that("maskOutBorder sets raster cells within the buffer to NA and keeps the others", {
  r <- toyGrid() + 1
  border <- bufferBorder(toyBorder(), width = 5000)
  out <- maskOutBorder(r, border)
  col <- terra::colFromCell(out, seq_len(terra::ncell(out)))
  expect_true(all(is.na(terra::values(out, mat = FALSE)[col %in% 6:7])))
  expect_false(anyNA(terra::values(out, mat = FALSE)[!col %in% 6:7]))
})

test_that("bufferBorder is NULL, and maskOutBorder a no-op, when borderBuffer is 0 or NA", {
  expect_null(bufferBorder(toyBorder(), width = 0))
  expect_null(bufferBorder(toyBorder(), width = NA))
  r <- toyGrid() + 1
  expect_identical(maskOutBorder(r, NULL), r)
})

test_that("maskOutBorder removes the buffer from polygons", {
  p <- toyPoly(1, 4, 1, 12, YEAR = 1)
  out <- maskOutBorder(p, bufferBorder(toyBorder(), width = 5000))
  ## 12 columns of 4 rows of 25 km2 = 1200 km2, minus a 10 km wide strip 20 km tall = 200 km2
  expect_equal(km2(out), 1000)
})

test_that("init removes the border cells from the single-ELF rasters and study areas", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"))     # core cols 4-6, buffer cols 3 and 7
  mockInitWorld(border = toyBorder())
  out <- suppressMessages(runInit(sim))
  ## large: cols 3-7 lose cols 6-7; core: cols 4-6 lose col 6
  expect_equal(km2(out$studyAreaLargeELF), 3 * 4 * 25)
  expect_equal(km2(out$studyAreaELF), 2 * 4 * 25)
  expect_equal(unname(as.vector(terra::ext(out$rasterToMatchLargeELF))), c(10000, 30000 - 5000, 0, 20000))
})

test_that("init with borderBuffer 0 leaves the ELFs as they were", {
  sim <- toySimInit(objects = list(.ELFind = "3.1.2"), params = list(borderBuffer = 0))
  mockInitWorld(border = toyBorder())
  out <- suppressMessages(runInit(sim))
  expect_equal(km2(out$studyAreaLargeELF), 500)
})
