## A raster file written where another job may be reading it is written to a temporary file and renamed,
## so the reader sees the old complete file or the new one. A rename replaces the inode; an overwrite
## in place keeps it. A second name for the old file (a hard link, as a cache entry has) shows which:
## it keeps the old bytes after a rename, and shows the new ones after an overwrite in place.

linkedOld <- function(target) {
  old <- paste0(target, ".old")
  skip_if_not(file.link(target, old), "no hard links")
  old
}

test_that("writeRasterAtomic replaces an existing file with a new one and leaves no temporary file", {
  d <- withr::local_tempdir()
  target <- file.path(d, "x.tif")
  terra::writeRaster(terra::rast(nrows = 2, ncols = 2, vals = 1), target)
  old <- linkedOld(target)
  r <- writeRasterAtomic(target, function(f) {
    expect_false(identical(f, target))
    terra::writeRaster(terra::rast(nrows = 2, ncols = 2, vals = 2), f)
  })
  expect_equal(as.vector(terra::values(terra::rast(old))), rep(1, 4))
  expect_identical(normalizePath(terra::sources(r)), normalizePath(target))
  expect_equal(as.vector(terra::values(r)), rep(2, 4))
  expect_identical(sort(list.files(d, all.files = TRUE, no.. = TRUE)), c("x.tif", "x.tif.old"))
})

test_that("writeRasterAtomic leaves the target and no temporary file when the write fails", {
  d <- withr::local_tempdir()
  target <- file.path(d, "x.tif")
  terra::writeRaster(terra::rast(nrows = 2, ncols = 2, vals = 1), target)
  expect_error(writeRasterAtomic(target, function(f) stop("no")), "no")
  expect_equal(as.vector(terra::values(terra::rast(target))), rep(1, 4))
  expect_identical(list.files(d, all.files = TRUE, no.. = TRUE), "x.tif")
})

test_that("studyAreaGrid with a filename never writes the target itself", {
  d <- withr::local_tempdir()
  target <- file.path(d, "rtm.tif")
  written <- character()
  realIfel <- terra::ifel
  local_mocked_bindings(ifel = function(..., filename) { written <<- c(written, filename); realIfel(..., filename = filename) },
                        .package = "terra")
  r <- studyAreaGrid(toyGrid() + 1, terra::vect(terra::ext(0, 30000, 0, 20000), crs = "EPSG:3978"),
                     filename = target)
  expect_length(written, 1L)
  expect_false(identical(normalizePath(written, mustWork = FALSE), normalizePath(target, mustWork = FALSE)))
  expect_identical(dirname(written), dirname(target))      # same folder, or the rename would copy
  expect_identical(normalizePath(terra::sources(r)), normalizePath(target))
  expect_true(all(terra::values(r) == 1, na.rm = TRUE))
})
