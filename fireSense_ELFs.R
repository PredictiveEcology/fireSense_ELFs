## Everything in this file and any files in the R directory are sourced during `simInit()`;
## all functions and objects are put into the `simList`.
## To use objects, use `sim$xxx` (they are globally available to all modules).
## Functions can be used inside any function that was sourced in this module;
## they are namespaced to the module, just like functions in R packages.
## If exact location is required, functions will be: `sim$.mods$<moduleName>$FunctionName`.
defineModule(sim, list(
  name = "fireSense_ELFs",
  description = "Create ELFs for fireSense family of modules",
  keywords = "",
  authors = c(
    person("Eliot", "McIntire", email = "eliot.mcintire@nrcan-rncan.gc.ca",
           role = c("aut", "cre"))
  ),
  childModules = character(0),
  version = list(fireSense_ELFs = "1.2.0.9009"),
  ## This module defines the study area every other fireSense module works in, so
  ## it has to be scheduled first. The object dependency graph only orders modules
  ## that actually exchange objects, so a module that needs the study area
  ## indirectly could otherwise be scheduled ahead of this one -- which is why
  ## callers were passing a `studyAreaLarge` purely to force the order, the very
  ## thing .assertOneStudyArea() now rejects. Naming a module that is not part of
  ## a given run is harmless: absent names are ignored (verified against
  ## SpaDES.core 3.2.1.9002), so this list can name the whole family.
  loadOrder = list(before = c("fireSense_burn",
                              "fireSense_dataPrep",
                              "fireSense_dataPrepFit",
                              "fireSense_dataPrepPredict",
                              "fireSense_hindcast",
                              "fireSense_ignitionFit",
                              "fireSense_ignitionPredict",
                              "fireSense_NWT",
                              "fireSense_NWT_DataPrep",
                              "fireSense_spreadFit",
                              "fireSense_spreadPredict",
                              "fireSense_summary")),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "fireSense_ELFs.Rmd"),
  reqdPkgs = list("SpaDES.core (>= 3.0.1)", "data.table", "googledrive", "httr2", "terra",
                  "PredictiveEcology/reproducible@development (>= 3.2.1.9073)",
                  "PredictiveEcology/SpaDES.core@development (>= 3.2.1.9056)",
                  "PredictiveEcology/LandR@development (>= 1.2.0.9021)",
                  "deldir", "withr", "sf", "FOR-CAST/fireregimetools@main (>= 0.1.0.9008)",
                  "PredictiveEcology/fireSenseUtils@development (>= 0.2.3.9120)",
                  "PredictiveEcology/SpaDES.project@development (>= 1.0.1.9205)"),
  parameters = bindrows(
    defineParameter("sppEquivCol", "character", "LandR", NA, NA,
                    "The column in `sim$speciesEquivalency` data.table to use as a naming convention."),
    defineParameter("fitFileSuffix", "character", "", NA, NA,
                    paste("Text put after the model tag in the ledger file names, e.g. `\"_boundfix_rep81\"`, so a test run",
                          "writes and reads (`\"latest\"`) only its own files, never the production ones. `\"\"` (the",
                          "default) writes the unsuffixed file and reads (`\"latest\"`) every file of the model tag, newest by the date in its",
                          "suffix (`fireSenseUtils::ledgerFileOrder()`); experiment fits belong in `spreadFitLedgerFolder(testing = TRUE)`. The same parameter of `fireSense_spreadFit`, `fireSense_ignitionFit` and `fireSense_dataPrepFit`;",
                          "set it for all with `.globals = list(fitFileSuffix = ...)`; modules that disagree stop",
                          "(`SpaDES.core::paramCheckOtherMods()`). Ignored when a file name is given.")),
    defineParameter("spreadFitFilename", "character", "latest",
                    NA, NA, paste("Name of the file in `spreadFitGoogleDriveFolder` that holds previously fitted SpreadFit",
                                  "parameters. `\"latest\"` (the default) takes each ELF's fit from the most recent",
                                  "file that has it (`fireSenseUtils::latestSpreadFits()`).")),
    defineParameter("spreadFitGoogleDriveFolder", "character",
                    fireSenseUtils::spreadFitLedgerFolder(),
                    NA, NA, paste("Google Drive folder URL that holds `spreadFitFilename` and, with `.useCloud`, the shared ELF maps.",
                                  "The default is `fireSenseUtils::spreadFitLedgerFolder()`, which follows `options(fireSenseUtils.spreadFitLedgerFolder = )`.")),
    defineParameter("ignitionFitFilename", "character", "latest",
                    NA, NA, paste("Name of the file in `ignitionFitGoogleDriveFolder` that holds the ignition/escape fits of",
                                  "`fireSense_ignitionFit`. `\"latest\"` (the default) takes each ELF's fit from the most recent",
                                  "file that has it (`fireSenseUtils::latestIgnitionFits()`).")),
    defineParameter("ignitionFitGoogleDriveFolder", "character",
                    fireSenseUtils::ignitionFitLedgerFolder(),
                    NA, NA, paste("Google Drive folder URL that holds `ignitionFitFilename`. The default is",
                                  "`fireSenseUtils::ignitionFitLedgerFolder()` (`options(fireSenseUtils.ignitionFitLedgerFolder = )`). `NULL` reads a named",
                                  "ledger file from `inputPath(sim)`, with no Google Drive access.")),
    defineParameter("heldOutFold", "integer", default = NA, NA, NA,
                    paste("NA (default): unchanged. `1` or `2`: a cross-validation fold is being fitted (the same",
                          "parameter as in `fireSense_spreadFit`), so the SpreadFit ledger is not relevant and is not",
                          "read: `spreadFitPreRun` is NULL, no ELF counts as fitted, and `studyAreaLarge` is not masked to",
                          "fitted ELFs. Set it for every fireSense module at once with `.globals = list(heldOutFold = 1L)`;",
                          "`init` stops if `fireSense_spreadFit` has a different value. Any other value is an error.")),
    defineParameter("borderBuffer", "numeric", 5000, 0, NA,
                    paste("Metres. Cells within this distance of the Canada-United States land border (49th parallel,",
                          "Great Lakes and St Lawrence, Alaska-Yukon/BC; not the coast) are removed from every ELF",
                          "(`NA` in `rasterToMatchLargeELF`, `rasterToMatchELF`, and out of `studyAreaLarge`,",
                          "`studyAreaLargeELF`, `studyAreaELF`). ClimateNA's DEM is invalid in the United States, which",
                          "contaminates interpolated climate in Canadian cells ~2 km from the border; the fire data are",
                          "Canada-only. The line is Natural Earth 10 m `admin_0_boundary_lines_land`. `0` or `NA` removes nothing.")),
    defineParameter("fireYears", "integer", fireSenseUtils::defaultFireYears(), NA, NA,
                    paste("Fire years over which each ELF's natural ignitions and fire polygons are counted.",
                          "An ELF with too few is merged with a neighbour that shares its base, or not fitted",
                          "(see `fireSenseUtils::ELFmergePlan()`). The default is",
                          "`fireSenseUtils::defaultFireYears()`, the default of `fireSense_dataPrepFit`'s `fireYears`,",
                          "so the ELFs are merged over the years the fit uses; `init` warns if another module in",
                          "the simList has different `fireYears`. `NULL`: no counting and no merging.")),
    defineParameter("minNaturalIgnitions", "numeric", 50, 0, NA,
                    "An ELF with fewer natural-cause ignitions than this over `fireYears` has too few fires."),
    defineParameter("minFirePolygons", "numeric", 50, 0, NA,
                    "An ELF with fewer fire polygons than this over `fireYears` has too few fires."),
    defineParameter("escapeSizeHa", "numeric", 50, 0, NA,
                    paste("Size (ha) a fire must reach to count as escaped, as in `fireSense_dataPrepFit`'s `escapeSizeHa`.",
                          "The escape and spread fits use only escaped fires; `init` warns if another module in the",
                          "simList has a different `escapeSizeHa`.")),
    defineParameter("minEscapes", "numeric", 5, 0, NA,
                    paste("An ELF with fewer escaped natural fires than this over `fireYears` has too few fires.",
                          "5 is the minimum the escape fit's 5-fold cross-validation needs.")),
    defineParameter("minRegionAreaKm2", "numeric", 35000, 0, NA,
                    paste("After the fire-count merging, an ELF whose core is smaller than this (km2) is merged with a",
                          "similar neighbour that shares its base (`fireSenseUtils::ELFsizePlan()`), choosing the merge",
                          "that leaves the fewest small ELFs without a partner. Land cover is SCANFI v2 2020. `NULL` or",
                          "`NA` turns the rule off; so does `fireYears = NULL`.")),
    defineParameter("maxLandCoverDist", "numeric", 0.35, 0, 1,
                    "Size rule: largest Bray-Curtis distance between the land-cover shares of two ELFs that may merge."),
    defineParameter("maxBurnRatio", "numeric", 6, 1, NA,
                    "Size rule: largest ratio (larger over smaller) of the burn rates (%/yr over `fireYears`) of two ELFs that may merge."),
    defineParameter("maskToELFsWithFits", "logical", FALSE, NA, NA,
                    paste("With `studyArea_fireSense`, when some of its ELFs have no stored SpreadFit and no module",
                          "can fit them (`doFit` FALSE): `FALSE` (default) stops, naming them; `TRUE` runs over only",
                          "the ELFs that have fits, cropping and masking `studyArea` and `rasterToMatch` to them.")),
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Passed to `types` in `Plots()`. If any, `init` plots the map of all ELFs and this run's study areas."),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "`NA` turns off screen plots in `Plots()`. No plot event is scheduled."),
    defineParameter(".studyAreaName", "character", NA, NA, NA,
                    "Human-readable name for the study area; used in the filename of the single-ELF raster."),
    defineParameter("ELFversion", "character", "2026-10-26", NA, NA,
                    paste("The only thing that decides whether the national ELF list is rebuilt. The list is built once,",
                          "kept in the cache and, with `.useCloud`, shared through Google Drive. Change this by hand to",
                          "rebuild it. Changing other parameters (`fireYears`, `minNaturalIgnitions`, ...) or the code",
                          "does NOT rebuild it unless this changes.")),
    defineParameter(".useCache", "logical", FALSE, NA, NA,
                    paste("Events to cache. The default caches no event: the national ELF list has its own",
                          "cache, keyed on `ELFversion` alone, which an event cache (keyed on parameters and",
                          "module version) would undo.")),
    defineParameter(".useCloud", c("logical", "character"), TRUE, NA, NA,
                    paste("Share the national ELF list (see `ELFversion`) through Google Drive, in the",
                          "fireSense folder named by `spreadFitGoogleDriveFolder` (the same folder that",
                          "holds the fitted-parameter file). `TRUE`: download the list if someone has",
                          "already built it for this `ELFversion`, otherwise build and upload it.",
                          "`\"pull\"`: download only, never upload (for read-only access). `FALSE`: build",
                          "locally without Google Drive. Needs Google Drive access to that folder.")),
    defineParameter(".useCacheArgs", "list", list(), NA, NA,
                    "Extra `Cache()` arguments for each event, by event name. None by default; see `.useCache`.")
  ),
  inputObjects = bindrows(
    expectsInput(".ELFind", "character", paste("Name of one ELF to run, e.g. \"4.3\" (fitting); the study area is the",
                                                 "buffered ELF. Supply this or `studyArea_fireSense`, not both.")),
    expectsInput("studyArea_fireSense", objectClass = "SpatVector",
                 desc = paste("The area of interest plus its buffer (fires spread in from outside it); it must already",
                              "be buffered. The run's ELFs are the ones it overlaps. Only for choosing and checking:",
                              "every module still works over `studyArea`, which must cover it. If `studyArea` is",
                              "already buffered, pass `studyArea_fireSense = studyArea`. Supply this or `.ELFind`."),
                 sourceURL = NA), # nolint: in_no_default
    expectsInput("studyAreaLarge", objectClass = "SpatVector",
                 desc = "Deprecated: the old name of `studyArea_fireSense`, used (with a warning) when that is not supplied.",
                 sourceURL = NA) # nolint: in_no_default
  ),
  outputObjects = bindrows(
    createsOutput("ELFs", objectClass = "SpatRaster",
                  desc = paste("All ELFs, from `fireSenseUtils::makeELFs()`: a list with `rasWhole` and `rasCentered`",
                               "(one SpatRaster per ELF), plus `poly` when `studyArea_fireSense` is supplied.")),
    createsOutput("rasterToMatchLargeELF", objectClass = "SpatRaster", 
                  desc = "Raster of the ELF(s) in the study area, including the ELF buffer when a single ELF is used."),
    createsOutput("rasterToMatchELF", objectClass = "SpatRaster",
                  desc = paste("`rasterToMatchLargeELF` without the buffer when a single ELF is used;",
                               "identical to it when `studyArea_fireSense` is supplied.")),
    createsOutput("rasterToMatch", objectClass = "SpatRaster",
                  desc = paste("Only if not already in the `simList`: the national template raster cropped and masked to",
                               "`studyAreaLarge`; 1 inside, `NA` outside. With `maskToELFsWithFits`, a supplied one",
                               "cropped and masked to the ELFs that have fits.")),
    createsOutput("studyArea", objectClass = "SpatVector",
                  desc = paste("Only if not already in the `simList`: same as `studyAreaLarge`. With `maskToELFsWithFits`,",
                               "a supplied one cropped to the ELFs that have fits.")),
    createsOutput("studyAreaLarge", objectClass = "SpatVector", 
                  desc = paste("Single ELF: the buffered ELF. `studyArea_fireSense` supplied: it intersected",
                               "with the ELFs that have fitted SpreadFit parameters, dissolved.")),
    createsOutput("studyAreaLargeELF", objectClass = "SpatVector",
                  desc = "Polygons of `rasterToMatchLargeELF`."),
    createsOutput("studyAreaELF", objectClass = "SpatVector",
                  desc = "Polygons of `rasterToMatchELF`."),
    createsOutput("sppEquiv", objectClass = "data.table",
                  desc = "Species table for `studyAreaELF` from `LandR::speciesInStudyArea()`. Zero rows for a few non-forested ELFs."),
    createsOutput("ELFsExcluded", "character",
                  desc = paste("ELFs with too few fires over `fireYears` that could not be merged; fireSenseUtils::runELFs()",
                               "leaves them out of the queue. NULL when `fireYears` is NULL.")),
    createsOutput("ELFfireStatus", "data.table",
                  desc = paste("Natural ignitions, escaped natural ignitions, fire polygons and zero/few/ok status of every ELF over `fireYears`",
                               "(fireSenseUtils::ELFfitStatus()). NULL when `fireYears` is NULL.")),
    createsOutput("ELFmerges", "data.table",
                  desc = paste("The merges and skips decided for ELFs with too few fires (fireSenseUtils::ELFmergePlan()),",
                               "and the merges of ELFs smaller than `minRegionAreaKm2` (fireSenseUtils::ELFsizePlan()).",
                               "NULL when `fireYears` is NULL.")),
    createsOutput("spreadFitPreRun", "data.frame",
                  desc = paste("This is a data.frame that has a geometry list column, so it can be ",
                               "converted to a sf or SpatVector (e.g., `terra::vect(sf::st_as_sf(sim$spreadFitPreRun))` ",
                               " , plus other mostly list columns:",
                               "numIterations, objFunVal (not list), params, sppEquiv, ", 
                               "nonForestedLCCGroups, missingLCCgroup, and polygonID. These are from ",
                               "previously fitted SpreadFit. If no pre-existing object exists from ",
                               "CacheGeo, this will be NULL")),
    createsOutput("fireSense_IgnitionFittedList", "list",
                  desc = paste("One `fireSense_IgnitionFitted` per ELF the study area touches, named by `ELFind`, read from",
                               "the ledger of `fireSense_ignitionFit`. With `studyArea_fireSense` an ELF without a fit is an error.",
                               "With one ELF, `NULL` when it has no fit yet (`fireSense_ignitionFit` is about to fit it),",
                               "and always `NULL` when `heldOutFold` is not `NA`.")),
    createsOutput("fireSense_EscapeFittedList", "list",
                  desc = "As `fireSense_IgnitionFittedList`, for `fireSense_EscapeFitted`.")
  )
))

#' Event dispatcher
#'
#' The only event is `init`.
#'
#' @param sim A `simList`.
#' @param eventTime Time of the event.
#' @param eventType `"init"`.
#'
#' @return The `simList`, invisibly.
doEvent.fireSense_ELFs = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      sim <- Init(sim)
    },
    warning(noEventWarning(sim))
  )
  return(invisible(sim))
}

#' Build the ELF maps and this run's study area objects
#'
#' Makes the national ELF maps, optionally merges ELFs with too few fires, reads
#' the previously fitted SpreadFit parameters from Google Drive, then derives the
#' study areas, rasters to match and `sppEquiv` for `.ELFind` or
#' for the ELFs under `studyArea_fireSense`. Plots them if `.plots` asks for it.
#'
#' @param sim A `simList`.
#'
#' @return The `simList`, invisibly, with every declared output assigned.
Init <- function(sim) {
  inputPath <- inputPath(sim)
  ELF <- as.character(sim$.ELFind)

  ## The template is the same for all ELFs, and each run needs it for its own rasters below.
  rastTemplate <- ELFtemplateRaster(inputPath)

  ## Cells near the Canada-US border are dropped from the per-ELF rasters and study areas below. The
  ## ELF maps are 5 km cells, too coarse for a 5 km buffer, so the border is applied at the 240 m template.
  borderZone <- if (isTRUE(Par$borderBuffer > 0)) # no download when switched off
    bufferBorder(canadaUSBorder(inputPath), Par$borderBuffer, crs = terra::crs(rastTemplate))
  borderCacheExtra <- list(borderBuffer = Par$borderBuffer, bufferBorder = bufferBorder,
                           maskOutBorder = maskOutBorder, selectCanadaUSBorder = selectCanadaUSBorder)

  ## The area of interest plus its buffer, which picks the ELFs; `studyAreaLarge` is its old name
  saFS <- sim$studyArea_fireSense
  if (is.null(saFS) && !is.null(sim$studyAreaLarge)) {
    warning("fireSense_ELFs: `studyAreaLarge` is deprecated; supply it as `studyArea_fireSense`", call. = FALSE)
    saFS <- sim$studyAreaLarge
  }
  hasStudyAreaLarge <- !is.null(saFS)
  ## every module simulates over `studyArea`; a supplied one must hold the whole buffered area
  if (hasStudyAreaLarge && !is.null(sim$studyArea))
    .assertStudyAreaCovers(sim$studyArea, saFS)
  ## .inputObjects records whether `.ELFind` was supplied. SpaDES skips .inputObjects when every input
  ## is supplied, and then it was.
  ELFindSupplied <- if (is.null(mod$ELFindSupplied)) !is.null(sim$.ELFind) else isTRUE(mod$ELFindSupplied)
  if (!is.null(Par$fireYears)) {
    SpaDES.core::paramCheckOtherMods(sim, "fireYears", ifSetButDifferent = "warning")
    SpaDES.core::paramCheckOtherMods(sim, "escapeSizeHa", ifSetButDifferent = "warning")
  }
  ## The national ELF list is built once and shared through the cloud cache. Its key is `ELFversion`
  ## alone: no argument, no code and no other parameter is part of it. Change `ELFversion` to rebuild.
  built <- buildELFs(inputPath, fireYears = Par$fireYears, minNaturalIgnitions = Par$minNaturalIgnitions,
                     minFirePolygons = Par$minFirePolygons, escapeSizeHa = Par$escapeSizeHa,
                     minEscapes = Par$minEscapes, minRegionAreaKm2 = Par$minRegionAreaKm2,
                     maxLandCoverDist = Par$maxLandCoverDist, maxBurnRatio = Par$maxBurnRatio) |>
    Cache(omitArgs = c("FUN", names(formals(buildELFs))), .cacheExtra = list(ELFversion = Par$ELFversion),
          .functionName = "ELFs", useCache = TRUE, useCloud = Par$.useCloud,
          cloudFolderID = SpaDES.core::paramCheckOtherMods(sim, "spreadFitGoogleDriveFolder"))
  ELFs <- built$ELFs
  ELFsBeforeMerges <- built$ELFsBeforeMerges
  ELFsExcluded <- built$excluded
  ELFfireStatus <- built$status
  ELFmerges <- built$plan
  if (!is.null(ELFmerges) && length(ELF) == 1L) {
    ## A job is queued under a merged ELF's name, but the default `.ELFind` (e.g. from global.R) may
    ## name one of its members
    runAs <- fireSenseUtils::ELFrunName(ELF, ELFmerges)
    if (!identical(runAs, ELF)) {
      message("fireSense_ELFs: ELF ", ELF, " is part of merged ELF ", runAs, "; using ", runAs)
      ELF <- runAs
    }
  }

  ## Over a study area the ledger lookup below needs only the ELFs it covers, so they are found first.
  ## Their names are the merged ELFs' (ELFs is built with the merges), as in the ledger's `polygonID`.
  if (hasStudyAreaLarge) {
    out <- ELFsInStudyArea(saFS, ELFsRaster = ELFs["rasWhole"],
                           ELFsPolygon = ELFs$poly, inputPath = inputPath(sim))
    ELFsNeeded <- unique(out$poly$ID)
    ## Both study areas were supplied and they disagree: stop rather than pick one
    ## silently, which once produced five identically-fitted "different" ELFs.
    .assertOneStudyArea(sim$.ELFind, ELFindSupplied, ELFsNeeded)
    v <- values(out$rast, dataframe = TRUE)
    out$rast[which(v[[1]] %in% "none")] <- NA
    out$rast <- terra::sieve(out$rast, threshold = 100, directions = 8)
    rr <- terra::trim(out$rast)
    pp <- as.polygons(rr)
  }

  # Check on what fireSense_spreadFit has already been run.
  # A held-out fold is fitted without the ledger: it is not read, and nothing counts as fitted.
  heldOutFold <- SpaDES.core::paramCheckOtherMods(sim, "heldOutFold")
  if (!isTRUE(is.na(heldOutFold)) && !(length(heldOutFold) == 1L && heldOutFold %in% 1:2))
    stop("fireSense_ELFs: parameter 'heldOutFold' must be NA, 1L or 2L; got: ",
         paste(format(heldOutFold), collapse = ", "))
  heldOut <- !isTRUE(is.na(heldOutFold))
  fitFileSuffix <- SpaDES.core::paramCheckOtherMods(sim, "fitFileSuffix")
  prepInputsFSURL <- SpaDES.core::paramCheckOtherMods(sim, "spreadFitGoogleDriveFolder")
  fireSenseParamsRDS <- SpaDES.core::paramCheckOtherMods(sim, "spreadFitFilename")
  latest <- identical(fireSenseParamsRDS, "latest")
  ## A ledger with no rows means "nothing has been fitted", which is the normal state at the start of a
  ## new experiment: the first completed fit creates the file. The ledger is read the way
  ## fireSense_spreadFit writes it (reproducible's CacheGeo family): from the copy in `inputPath(sim)`,
  ## which is refreshed from the Drive folder only when that is reachable.
  spreadFitPreRun <- if (heldOut) {
    NULL
  } else if (latest) {
    fireSenseUtils::latestSpreadFits(prepInputsFSURL, destinationPath = inputPath(sim),
                                      polygonIDs = if (hasStudyAreaLarge) as.character(unique(pp$ELFind)),
                                      suffix = fitFileSuffix)
  } else {
    ledger <- reproducible::CacheGeoLedger(fireSenseParamsRDS, remote = prepInputsFSURL,
                                           destinationPath = inputPath(sim), key = "polygonID")
    rows <- reproducible::CacheGeoRead(ledger, area = NULL)
    if (NROW(rows) == 0L) {
      message("fireSense_ELFs: no '", fireSenseParamsRDS, "' in ", prepInputsFSURL,
              " -- treating this as no pre-run SpreadFit results yet.")
      NULL
    } else rows
  }
  
  
  if (hasStudyAreaLarge) {

    ## the ELFs actually inside the area (the ELF map's cells can reach past its edge)
    pp <- terra::project(pp, saFS)
    pp <- terra::intersect(pp, saFS) |> maskOutBorder(borderZone)

    # Not all will have SpreadFit yet
    hasELFFittedData <- pp$ELFind %in% spreadFitPreRun$polygonID
    noFit <- sort(unique(as.character(pp$ELFind[!hasELFFittedData])))
    maskedToFits <- length(noFit) > 0L && !heldOut
    if (maskedToFits) {
      ## no fit and none can be made: stop, unless asked to run over the ELFs that have one
      if (!isTRUE(Par$maskToELFsWithFits) && !.fitsAllowed(sim))
        .stopNoFits(noFit, sort(unique(as.character(pp$ELFind[hasELFFittedData]))))
      if (!any(hasELFFittedData))
        stop("fireSense_ELFs: none of the ELFs in `studyArea_fireSense` has a stored SpreadFit", call. = FALSE)
      warning("Not all the ELFs have SpreadFit parameters (", paste(noFit, collapse = ", "),
              "); masking studyAreaLarge to ONLY the ELFs that have data")
      pp <- pp[pp$ELFind %in% spreadFitPreRun$polygonID,]
    }
    ELFpolys <- pp
    ## This run's ELFs, unless the user named them (.assertOneStudyArea() checked those): the ones the
    ## study area covers that have a fit. Not the default "4.3", which the fit modules took for this run's
    ## ELF: with doFit = FALSE they stopped, finding no stored fit for it.
    if (!ELFindSupplied) {
      ELF <- sort(unique(as.character(pp$ELFind)))
      sim$.ELFind <- ELF
    }
    studyAreaLargeELF <- terra::project(pp, rastTemplate)
    w <- 0.00000001 # the aggregate function creates artifacts --> lines that shouldn't be there
    salELFagg <- terra::aggregate(studyAreaLargeELF)
    studyAreaLarge <- terra::buffer(width = -w, terra::buffer(width = w, salELFagg))
    studyAreaELF <- studyAreaLargeELF
    ## Each pixel's ELF, on the grid of rasterToMatch: fireSense_spreadPredict blends neighbour ELFs on
    ## that grid (flammableRTM), and stopped with "rasterToMatchLargeELF is not on the grid of
    ## flammableRTM" when this was the 5 km grid of the ELF maps.
    grid <- if (is.null(sim$rasterToMatch)) studyAreaGrid(rastTemplate, studyAreaLarge) else sim$rasterToMatch
    rasterToMatchLargeELF <- terra::mask(terra::rasterize(studyAreaLargeELF, grid, field = "ELFind"), grid)
    rasterToMatchELF <- rasterToMatchLargeELF

  } else {
    rtml <- ELFs$rasWhole[[ELF]]
    rasterToMatchLargeELF <- {
      if (identical(1, terra::freq(is.na(rtml))$value))
        stop("This ELF has no data")
      rtml[rtml[] == 0] <- NA
      {
        postProcess(rtml, projectTo = rastTemplate, method = "near",
                    writeTo = file.path(inputPath, paste0("rtml_", Par$.studyAreaName,".tif"))) |>
          maskOutBorder(borderZone) |>
          terra::trim() } |>
        Cache(omitArgs = c("x"),
              .functionName = paste0("rasterToMatchLargeELF"),
              .cacheExtra = c(list(ELFs = attr(ELFs, "tags"),
                                   ELFind = ELF,
                                   rastTemplate = attr(rastTemplate, "tags")),
                              borderCacheExtra))
    }
    studyAreaLargeELF <- {
      {
        terra::as.polygons(rasterToMatchLargeELF > 0)
      } |> Cache(omitArgs = c("x"), .functionName = "studyAreaLargeELF",
                 .cacheExtra = list(rtml = attr(rasterToMatchLargeELF, "tags")))
    }
    rasterToMatchELF <- {
      {
        rasterToMatchLargeELF |>
          replace(list = rasterToMatchLargeELF != 2, NA) |>
          terra::trim()
      } |> Cache(omitArgs = c("x"),
                 .functionName = "rasterToMatchELF",
                 .cacheExtra = list(rtml = attr(rasterToMatchLargeELF, "tags")))
    }
    studyAreaELF <- {
      terra::as.polygons(rasterToMatchELF) |>
        Cache(omitArgs = c("x"), .functionName = "studyArea",
              .cacheExtra = list(rtm = attr(rasterToMatchELF, "tags")))
    }
    studyAreaLarge <- studyAreaLargeELF
    ELFpolys <- studyAreaLargeELF
    ELFpolys$ELFind <- ELF
  }

  ## The fitted ignition and escape models of every ELF this run touches. A study area over several
  ## ELFs is for prediction, so every ELF needs its fit; a single ELF may be about to be fitted.
  fireSense_IgnitionFittedList <- fireSense_EscapeFittedList <- NULL
  if (!heldOut) {
    ignitionRows <- readIgnitionFitRows(ELFpolys,
                                        folder = SpaDES.core::paramCheckOtherMods(sim, "ignitionFitGoogleDriveFolder"),
                                        filename = SpaDES.core::paramCheckOtherMods(sim, "ignitionFitFilename"),
                                        destinationPath = inputPath,
                                        fitFileSuffix = fitFileSuffix)
    ignitionFits <- ignitionFitLists(ignitionRows, ELFpolys$ELFind, required = hasStudyAreaLarge)
    fireSense_IgnitionFittedList <- ignitionFits$ignition
    fireSense_EscapeFittedList <- ignitionFits$escape
  }
  
  ## The species table (no _Spp genus entries, only species with LANDIS traits, Engelmann
  ## spruce merged into Pice_eng) comes from LandR, so every module uses the same one.
  species <- LandR::speciesInStudyArea(studyAreaELF, sppEquivCol = P(sim)$sppEquivCol, dPath = inputPath) |>
    reproducible::Cache(omitArgs = "studyArea",
                        ## read inside the function, so its contents are not otherwise part of the key: a LandR
                        ## change to it (e.g. a FuelClass) would keep returning the cached, stale sppEquiv
                        .cacheExtra = list(sa = attr(studyAreaELF, "tags"),
                                           sppEquivalencies = reproducible::.robustDigest(LandR::sppEquivalencies_CA)))
  sppEquiv <- species$sppEquiv

  ## A few ELFs (3.2.1, 3.2.4, 3.2.5, 3.3.2) genuinely have no tree species; the fit then uses
  ## nonForest fuel classes only. That used to be silent, and the run died several modules
  ## later with "No trait values were found for ." naming nothing. This is the one place the
  ## state is established, so it is announced here and only here.
  if (NROW(sppEquiv) == 0L)
    message("fireSense_ELFs: ELF ", ELF, ": no tree species found in this study area ",
            "(LandR::speciesInStudyArea returned none with LANDIS traits). This is expected ",
            "for a few non-forested ELFs and is not an error: the run proceeds with an empty ",
            "sppEquiv, no species layers, no tree cohorts, and nonForest fuel classes only.")
  
  if (is.null(sim$studyArea)) # conditional; can't put it in metadata or this will not be run first
    studyArea <- studyAreaLarge

  ## maskToELFsWithFits: a supplied studyArea and rasterToMatch are cut to the ELFs that have fits too,
  ## or the ELFs without one would be simulated with no spread parameters
  if (hasStudyAreaLarge && maskedToFits && isTRUE(Par$maskToELFsWithFits)) {
    if (!is.null(sim$studyArea)) {
      sa <- if (inherits(sim$studyArea, "SpatVector")) sim$studyArea else terra::vect(sim$studyArea)
      studyArea <- terra::crop(sa, terra::project(studyAreaLarge, sa))
      if (inherits(sim$studyArea, "sf")) studyArea <- sf::st_as_sf(studyArea)
    }
    if (!is.null(sim$rasterToMatch)) {
      keep <- terra::project(studyAreaLarge, sim$rasterToMatch)
      rasterToMatch <- terra::mask(terra::crop(sim$rasterToMatch, keep), keep,
                                   filename = file.path(inputPath, paste0("rasterToMatch_", studyAreaName(keep), ".tif")),
                                   overwrite = TRUE)
    }
    message("fireSense_ELFs: maskToELFsWithFits: running over ELF(s) ", paste(ELF, collapse = ", "),
            " only; `studyArea` and `rasterToMatch` are masked to them")
  }

  if (is.null(sim$rasterToMatch)) # conditional; can't put it in metadata or this will not be run first
    rasterToMatch <- studyAreaGrid(rastTemplate, studyAreaLarge,
                                   filename = file.path(inputPath, paste0("rasterToMatch_", studyAreaName(studyAreaLarge), ".tif")))
  
  # Put them all in the sim; a supplied rasterToMatch or studyArea was not made here and stays as it is
  objsHere <- depends(sim)@dependencies[[currentModule(sim)]]@outputObjects$objectName
  objsHere <- objsHere[vapply(objsHere, exists, logical(1), envir = environment(), inherits = FALSE)]
  list2env(mget(objsHere, envir = environment()), envir = envir(sim))
  
  if (anyPlotting(Par$.plots)) {
    
    Plots(fn = plotAllELFsFn, centred = ELFs$rasCentered,
          crsToUse = terra::crs(ELFs$rasWhole[[11]]), alreadyRun = spreadFitPreRun, thisELF = ELF,
          path = inputPath, deviceArgs = list(width = 11, height = 8, units = "in", res = 300),
          filename = paste0("ELF_polygons.png")
    )
    
    ## the ELFs after the merges, those without enough fires shaded; the file type is .plots' to decide
    if (!is.null(ELFmerges))
      Plots(fn = fireSenseUtils::plotELFs, ELFs = ELFsBeforeMerges, plan = ELFmerges, buffers = FALSE,
            path = inputPath, deviceArgs = list(width = 11, height = 8, units = "in", res = 300),
            filename = "ELFs_postMerge")

    Plots(as.list(sim[grep("studyArea|rasterToMatchELF", names(sim), value = TRUE)]),
          title = paste0("StudyArea ", paste(sim$.ELFind, collapse = ", ")),
          fn = SpaDES.project::plotSAs,
          filename = paste0("studyAreas", paste(sim$.ELFind, collapse = "_")),
          path = inputPath,
          ggsaveArgs = list(width = 11, height = 8, units = "in"))
    
  }
  
  return(invisible(sim))
}

#' Plot all ELFs, marking those already fitted and those running
#'
#' @param centred List of per-ELF `SpatRaster`s (`ELFs$rasCentered`); cells equal to 2 are the ELF without its buffer.
#' @param crsToUse CRS that all ELFs are projected to for plotting.
#' @param alreadyRun `data.frame` with a geometry column (`sim$spreadFitPreRun`); drawn green. May be `NULL`.
#' @param thisELF Character; this run's ELF (`sim$.ELFind`), drawn yellow. May be `NULL`.
#'
#' @return Called for its plot.
plotAllELFsFn <- function(centred, crsToUse, alreadyRun, thisELF) {
  allELFs <- { Map(r = centred, function(r) {
    r2 <- r == 2
    r2[!terra::values(r2, mat = FALSE) %in% TRUE] <- NA
    terra::as.polygons(r2) |> terra::project(y = crsToUse)}) |>
      Reduce(rbind, x = _)
  }
  wh <- rowSums(as.data.frame(allELFs), na.rm = TRUE) == 1
  allELFs2 <- allELFs[wh, ]
  cen <- terra::centroids(allELFs2)
  terra::plot(allELFs)
  if (!missing(alreadyRun)) {
    if (NROW(alreadyRun)) {
      if (is.data.frame(alreadyRun)) {
        alreadyRunPolys <- sf::st_as_sf(alreadyRun) |> terra::vect()
      }
      terra::plot(alreadyRunPolys, add = TRUE, col = "green", alpha = 0.5)
      
    }
  }
  if (!missing(thisELF)) { # this run's ELF in yellow
    if (NROW(thisELF)) {
      turnYellow <- sapply(thisELF, function(x) grep(pattern = x, names(allELFs)))
      terra::plot(allELFs[turnYellow,], add = TRUE, col = "yellow", alpha = 0.5)
    }
  }
  
  terra::text(cen, label = gsub("^X", "", names(allELFs)), cex = 0.8)
}

#' Check that a study area was given
#'
#' Stops if neither `.ELFind` nor `studyArea_fireSense` (or its old name `studyAreaLarge`) is supplied
#' (with a `studyArea_fireSense`, Init sets `.ELFind` to the ELFs it covers), and records in
#' `mod$ELFindSupplied` whether `.ELFind` was supplied.
#'
#' @param sim A `simList`.
#'
#' @return The `simList`.
.inputObjects <- function(sim) {
  
  ## Init has to tell an ELF the user asked for from one it set itself: only the
  ## former can conflict with a `studyArea_fireSense`. See .assertOneStudyArea().
  mod$ELFindSupplied <- suppliedElsewhere(".ELFind", sim)
  ## with a studyArea_fireSense, Init sets `.ELFind` to the ELFs it covers
  if (!mod$ELFindSupplied && !suppliedElsewhere("studyArea_fireSense", sim) &&
      !suppliedElsewhere("studyAreaLarge", sim))
    stop("fireSense_ELFs needs `studyArea_fireSense`: your area of interest plus a buffer (fires spread in ",
         "from outside it). If `studyArea` is already buffered, pass `studyArea_fireSense = studyArea`. ",
         "To run a single ELF instead, set `.ELFind` (e.g. `.ELFind = \"12.3\"`).", call. = FALSE)

  sim
}
