test_that("ELFsMap() is a categorical raster of the ELFs, its levels their names", {
  ## for the map of the ELFs around a study area (plotSAs(), the legend names the ELFs)
  poly <- toyELFsWithPoly()$poly
  r <- ELFsMap(poly)
  expect_s4_class(r, "SpatRaster")
  expect_identical(names(r), "ELFs")
  expect_true(terra::is.factor(r))
  expect_setequal(terra::cats(r)[[1]][[2]], unique(poly$ID))
  expect_equal(terra::res(r), c(5000, 5000))
})
