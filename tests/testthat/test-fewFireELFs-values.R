## fewFireELFs() on the toy ELF maps of helper-toyELFs.R. The two fireregimetools loaders read
## national shapefiles, so they are replaced by toy fire records; everything else is the real
## code (the module's function and fireSenseUtils' counting, status, plan and merge).
##
## Fire records, 2001-2003, thresholds minNaturalIgnitions = 3 and minFirePolygons = 1:
##
##   ELF     natural ignitions counted                 polygons counted     status
##   3.1.1   1  (col 2, 2001)                          1 (cols 1-2, 2001)   few (1 < 3)
##   3.1.2   3  (col 5: 2001, 2002, 2003)              1 (col 5, 2002)      ok
##   5.1     1  (col 8, 2002)                          0                    zero (no polygon)
##   1.1     not counted: ecozone 1
##
## Not counted: a human-caused point (col 2), a point from 1999 (col 5), a point in 1.1 (col 11),
## and a polygon of half a cell in 5.1 (1250 ha, not above one 2500 ha pixel).
## So 3.1.1 merges with 3.1.2, its only neighbour with the same base "3.1" (1 + 3 = 4 >= 3
## ignitions, 1 + 1 = 2 >= 1 polygons), and 5.1 has no neighbour sharing base "5": skipped.

toyFirePoints <- function() {
  rbind(
    toyPoints(2, 2, 2001L, "L"),
    toyPoints(3, 2, 2001L, "H"),          # human-caused
    toyPoints(1, 5, 2001L, "N"),
    toyPoints(2, 5, 2002L, "L"),
    toyPoints(3, 5, 2003L, "L"),
    toyPoints(4, 5, 1999L, "L"),          # outside fireYears
    toyPoints(2, 8, 2002L, "L"),
    toyPoints(2, 11, 2002L, "L")          # in arctic ELF 1.1
  )
}

toyFirePolys <- function() {
  half <- toyPoly(1, 1, 8, 8, 2002L)
  half <- terra::crop(half, terra::ext(terra::xmin(half), terra::xmin(half) + 2500,
                                       terra::ymin(half), terra::ymax(half))) # 2.5 x 5 km = 1250 ha
  rbind(toyPoly(1, 1, 1, 2, 2001L),      # 2 cells = 5000 ha, in 3.1.1
        toyPoly(3, 4, 5, 5, 2002L),      # 2 cells = 5000 ha, in 3.1.2 (col 5 is in no buffer)
        half)
}

runFewFire <- function(..., loaderArgs = NULL) {
  local_mocked_bindings(
    load_nfdb_points = function(nfdb_shp, study_area, fire_years = NULL, min_size_ha = 1) {
      if (!is.null(loaderArgs)) loaderArgs$points <- list(nfdb_shp = nfdb_shp, study_area = study_area,
                                                          fire_years = fire_years, min_size_ha = min_size_ha)
      toyFirePoints()
    },
    load_nbac_polys = function(nbac_shp, study_area, fire_years = NULL, min_size_ha = 1) {
      if (!is.null(loaderArgs)) loaderArgs$polys <- list(nbac_shp = nbac_shp, study_area = study_area,
                                                         fire_years = fire_years, min_size_ha = min_size_ha)
      toyFirePolys()
    },
    .package = "fireregimetools"
  )
  fewFireELFs(toyELFs(), fireYears = 2001:2003, pixelAreaHa = 2500,
              nfdbShp = "points.shp", nbacShp = "polys.shp", ...)
}

test_that("fire counts and status are those of the toy fire records", {
  out <- suppressMessages(runFewFire(minNaturalIgnitions = 3, minFirePolygons = 1))
  st <- as.data.frame(out$status)
  st <- st[order(st$ELF), ]
  expect_identical(st$ELF, c("3.1.1", "3.1.2", "5.1"))        # 1.1 is arctic: not counted
  expect_identical(st$naturalIgnitions, c(1L, 3L, 1L))
  expect_identical(st$firePolygons, c(1L, 1L, 0L))
  expect_identical(st$status, c("few", "ok", "zero"))
})

test_that("the thin ELF is merged with the neighbour sharing its base; the other is skipped", {
  out <- suppressMessages(runFewFire(minNaturalIgnitions = 3, minFirePolygons = 1))
  plan <- out$plan
  expect_identical(plan$action, c("merge", "skip"))
  expect_identical(plan$ELF, c("3.1.1_2", NA))
  expect_identical(plan$members, list(c("3.1.1", "3.1.2"), "5.1"))
  expect_identical(plan$naturalIgnitions, c(4L, 1L))           # 1 + 3; 1
  expect_identical(plan$firePolygons, c(2L, 0L))               # 1 + 1; 0
  expect_identical(out$excluded, "5.1")
})

test_that("the returned maps hold the merged ELF in place of its members", {
  out <- suppressMessages(runFewFire(minNaturalIgnitions = 3, minFirePolygons = 1))
  expect_setequal(names(out$ELFs$rasWhole), c("5.1", "1.1", "3.1.1_2"))
  expect_setequal(names(out$ELFs$rasCentered), c("5.1", "1.1", "3.1.1_2"))
  merged <- out$ELFs$rasWhole[["3.1.1_2"]]
  expect_identical(names(merged), "3.1.1_2")
  ## row 1 of the merged map: core over cols 1-6, the 3.1.2 buffer at col 7, 0 beyond
  expect_identical(as.vector(merged[1, ])[[1]], c(2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0))
  ## the untouched ELFs are returned as they came in
  expect_identical(terra::values(out$ELFs$rasWhole[["5.1"]]), terra::values(toyELFs()$rasWhole[["5.1"]]))
})

test_that("each decision is announced once", {
  msgs <- capture_messages(runFewFire(minNaturalIgnitions = 3, minFirePolygons = 1))
  msgs <- grep("^fireSense_ELFs: ", msgs, value = TRUE)
  expect_identical(
    trimws(msgs),
    c("fireSense_ELFs: merge 3.1.1 + 3.1.2 -> 3.1.1_2 (too few fires; merged with 3.1.2, the longest shared border)",
      "fireSense_ELFs: skip 5.1 (too few fires; no neighbour shares its base)"))
})

test_that("the thresholds given are the ones used, for the status and for the plan", {
  ## with 5 ignitions needed, 3.1.2 (3) is thin too, and 3.1.1 + 3.1.2 = 4 is still too few
  out <- suppressMessages(runFewFire(minNaturalIgnitions = 5, minFirePolygons = 1))
  st <- as.data.frame(out$status)
  expect_identical(st$status[order(st$ELF)], c("few", "few", "zero"))
  expect_identical(out$plan$action, c("skip", "skip"))
  expect_identical(sort(out$excluded), c("3.1.1", "3.1.2", "5.1"))
  expect_setequal(names(out$ELFs$rasWhole), c("3.1.1", "3.1.2", "5.1", "1.1")) # nothing merged

  ## with 1 ignition and 0 polygons needed only 5.1 is left out, because a "zero" ELF is thin
  ## whatever the thresholds
  lax <- suppressMessages(runFewFire(minNaturalIgnitions = 1, minFirePolygons = 0))
  expect_identical(lax$excluded, "5.1")
  expect_identical(lax$plan$action, "skip")
})

test_that("the defaults are 50 ignitions and 50 polygons", {
  out <- suppressMessages(runFewFire())
  ## nothing in the toy records reaches 50, so every counted ELF is thin and none can be merged
  expect_identical(sort(out$excluded), c("3.1.1", "3.1.2", "5.1"))
  expect_identical(formals(fewFireELFs)$minNaturalIgnitions, 50)
  expect_identical(formals(fewFireELFs)$minFirePolygons, 50)
})

test_that("the fire records are asked for over the whole map, every size, the years given", {
  seen <- new.env()
  suppressMessages(runFewFire(minNaturalIgnitions = 3, minFirePolygons = 1, loaderArgs = seen))
  expect_identical(seen$points$nfdb_shp, "points.shp")
  expect_identical(seen$polys$nbac_shp, "polys.shp")
  expect_identical(seen$points$fire_years, 2001:2003)
  expect_identical(seen$polys$fire_years, 2001:2003)
  expect_identical(seen$points$min_size_ha, 0)   # fires of every size, as the fit reads them
  expect_identical(seen$polys$min_size_ha, 0)
  expect_equal(unname(as.vector(terra::ext(seen$points$study_area))), c(0, 60000, 0, 20000))
  expect_equal(unname(as.vector(terra::ext(seen$polys$study_area))), c(0, 60000, 0, 20000))
})
