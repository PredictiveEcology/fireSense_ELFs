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
  authors = structure(list(list(given = c("First", "Middle"), family = "Last", role = c("aut", "cre"), email = "email@example.com", comment = NULL)), class = "person"),
  childModules = character(0),
  version = list(fireSense_ELFs = "1.1.0"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "fireSense_ELFs.Rmd"),
  reqdPkgs = list("SpaDES.core (>= 3.0.1)", "terra", 
                  "PredictiveEcology/reproducible@development (>=3.1.1.9000)",
                  "PredictiveEcology/SpaDES.core@development (>= 3.1.2.9000)",
                  "PredictiveEcology/scfmutils@development",
                  "deldir", "withr",
                  "PredictiveEcology/fireSenseUtils@development (>= 0.2.0.9000)",
                  "PredictiveEcology/SpaDES.project@development (>= 1.0.1.9205)"),
  parameters = bindrows(
    #defineParameter("paramName", "paramClass", value, min, max, "parameter description"),
    defineParameter("sppEquivCol", "character", "LandR", NA, NA,
                    "The column in `sim$speciesEquivalency` data.table to use as a naming convention."),
    defineParameter("spreadFitFilename", "character", "fireSenseParams.rds",
                    NA, NA, "A Googledrive folder url where a file with fireSense studyArea exists as an 'sf' class object"),
    defineParameter("spreadFitGoogleDriveFolder", "character",
                    "https://drive.google.com/drive/folders/1X9-mRjyLMNpgkP_cfqhbr_AQEPOsVCHf",
                    # KNN pre Oct 2025: "https://drive.google.com/drive/u/0/folders/1spxq7CnL4kNcJoUQlRek2CmBJ1InAmbP",
                    NA, NA, "A Googledrive folder url where a file with fireSense studyArea exists as an 'sf' class object"),
    # defineParameter("hashSpreadFitRemoteFile", "character", NULL,
    #                 NA, NA, "A character scalar with the remote hash value e.g., from reproducible:::getRemoteMetadata, ",
    #                 " which will determine whether the module needs to be rerun"),
    defineParameter("queue_path", "character", NULL,
                    NA, NA, "A character scalar indicating what the filename of the queue.rds file is from experimentTmux; ",
                    "if NULL, then this can't determine which ELFs are being run (no 'yellow' on the map)"),
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Used by Plots function, which can be optionally used here"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "Describes the simulation time at which the first plot event should occur."),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    "Describes the simulation time interval between plot events."),
    defineParameter(".saveInitialTime", "numeric", NA, NA, NA,
                    "Describes the simulation time at which the first save event should occur."),
    defineParameter(".saveInterval", "numeric", NA, NA, NA,
                    "This describes the simulation time interval between save events."),
    defineParameter(".studyAreaName", "character", NA, NA, NA,
                    "Human-readable name for the study area used - e.g., a hash of the study",
                          "area obtained using `reproducible::studyAreaName()`"),
    ## .seed is optional: `list('init' = 123)` will `set.seed(123)` for the `init` event only.
    # defineParameter(".seed", "list", list('init' = 123), NA, NA,
    #                 "Named list of seeds to use for each event (names)."),
    defineParameter(".useCache", "logical", "init", NA, NA,
                    "Should caching of events or module be used?"),
    defineParameter(".useCacheArgs", "list",
                    list(init = list(
                      # cacheId       = quote(paste0("fireSense_ELFs_v1.0_ELF", sim$.ELFind)),
                      useCloud      = FALSE,
                      # omitArgs = TRUE,
                      # .cacheExtra   = quote(sim$.ELFind),
                      cloudFolderID = "1gCgLiF4P0kAEp37OW1gak7F_rkkkCzse"
                    )),
                    NA, NA,
                    "Per-event Cache() args; cacheId pins the key for cloud reuse")
  ),
  inputObjects = bindrows(
    #expectsInput("objectName", "objectClass", "input object description", sourceURL, ...),
    expectsInput(".ELFind", "character", "Some descriptive, short name for this fitting, e.g., ELF14.1"),
    expectsInput("studyAreaLarge", objectClass = "SpatVector", desc = NA, sourceURL = NA) # nolint: in_no_default
    
  ),
  outputObjects = bindrows(
    #createsOutput("objectName", "objectClass", "output object description", ...),
    # createsOutput("rastTemplate", obje$tClass = "SpatRaster", desc = NA),
    createsOutput("homogeneousFire", objectClass = "SpatRaster", desc = NA),
    createsOutput("ELFs", objectClass = "SpatRaster", desc = NA),
    createsOutput("rasterToMatchLargeELF", objectClass = "SpatRaster", 
                  desc = "A very coarse rasterToMatch (5kmx5km); with the ELF values on it"),
    createsOutput("rasterToMatchELF", objectClass = "SpatRaster", desc = "This will be smaller than ",
                  "rasterToMatchLargeELF if the studyAreaLarge covers less than one ELF, ",
                  "i.e., the buffers will be removed. But if there are no buffers (i.e., ",
                  "studyAreaLarge covers more than one ELF), then it will be same as ", 
                  "rasterToMatchLargeELF"),
    createsOutput("rasterToMatch", objectClass = "SpatRaster",
                  desc = "If not supplied from another source, it will be studyArea, ",
                  "with metadata from trim(ELFs$rasCentred)"),
    createsOutput("studyArea", objectClass = "SpatVector", desc = NA),
    createsOutput("studyAreaLarge", objectClass = "SpatVector", 
                  desc = "This will be the inputted studyAreaLarge, but intersected with ", 
                  "the ELFs that have results for them"),
    createsOutput("studyAreaLargeELF", objectClass = "SpatVector", desc = NA),
    createsOutput("studyAreaELF", objectClass = "SpatVector", desc = NA),
    # createsOutput("studyAreaReporting", objectClass = "SpatVector", desc = NA),
    createsOutput("sppEquiv", objectClass = "data.table", desc = NA),
    createsOutput("studyAreaPSP", objectClass = "SpatVector", desc = NA),
    createsOutput("spreadFitPreRun", "data.frame",
                  desc = paste("This is a data.frame that has a geometry list column, so it can be ",
                               "converted to a sf or SpatVector (e.g., `terra::vect(sf::st_as_sf(sim$spreadFitPreRun))` ",
                               " , plus other mostly list columns:",
                               "numIterations, objFunVal (not list), params, sppEquiv, ", 
                               "nonForestedLCCGroups, missingLCCgroup, and polygonID. These are from ",
                               "previously fitted SpreadFit. If no pre-existing object exists from ",
                               "CacheGeo, this will be NULL"))
    
  )
))

doEvent.fireSense_ELFs = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      ### check for more detailed object dependencies:
      ### (use `checkObject` or similar)

      # do stuff for this event
      sim <- Init(sim)

      # schedule future event(s)
      # sim <- scheduleEvent(sim, P(sim)$.plotInitialTime, "fireSense_ELFs", "plot")
      # sim <- scheduleEvent(sim, P(sim)$.saveInitialTime, "fireSense_ELFs", "save")
    },
    plot = {
      plotFun(sim) # example of a plotting function
    },
    save = {},
    warning(noEventWarning(sim))
  )
  return(invisible(sim))
}

### template initialization
Init <- function(sim) {
  # The generation of the ELFs has a tiny bit of randomness; we don't actually
  #   want this; they should be identical
  withr::local_seed(123)
  
  
  inputPath <- inputPath(sim)
  ELF <- as.character(sim$.ELFind)
  # ll <- list(

  # This template is not specific to any one ELF; it is the same for all; so the 
  #   sequence below allows the Cache to find it once, because it is in memory; it
  #   will be cleaned up at the end of the function
  rastTemplate <- ELFtemplateRaster(inputPath)

  homogeneousFire <- {
    {
      scfmutils::prepInputsFireRegimePolys(type = "FRU", destinationPath = inputPath) |>
        reproducible::Cache(cacheSaveFormat = "rds")
    }}
  
  hasStudyAreaLarge <- !is.null(sim$studyAreaLarge)
  ELFs <- {
    # fireSenseUtils::makeELFs(homogeneousFire, desiredBuffer = 20000, destinationPath = inputPath) |>
    fireSenseUtils::makeELFs(rastTemplate, desiredBuffer = 20000, destinationPath = inputPath, 
                             singleSpatVector = hasStudyAreaLarge) |>
      Cache(omitArgs = "nationalForestPolygon",
            .cacheExtra = list(rt = attr(rastTemplate, "tags"),
                               makeELFs = fireSenseUtils::makeELFs,
                               bufferOutFn = fireSenseUtils:::bufferOut,
                               splitPoly = fireSenseUtils:::split_poly,
                               merge = fireSenseUtils:::mergeAndSplitRas))
  }
  
  # Check on what fireSense_SpreadFit has already been run
  prepInputsFSURL <- SpaDES.core::paramCheckOtherMods(sim, "spreadFitGoogleDriveFolder")
  # prepInputsFSURL <- Par$spreadFitGoogleDriveFolder
  gdLs <- googledrive::drive_ls(prepInputsFSURL)
  fireSenseParamsRDS <- SpaDES.core::paramCheckOtherMods(sim, "spreadFitFilename")
  # fireSenseParamsRDS <- Par$spreadFitFilename
  remoteFile <- gdLs[gdLs$name %in% fireSenseParamsRDS,]
  digRemote <- remoteFile$drive_resource[[1]]$md5Checksum
  gdMeta <- googledrive::drive_download(remoteFile,
                                        path = file.path(inputPath(sim), remoteFile$name),
                                        overwrite = TRUE) |>
    reproducible::Cache(.cacheExtra = digRemote)
  spreadFitPreRun <- readRDS(gdMeta$local_path)
  
  
  if (hasStudyAreaLarge) {

    out <- ELFsInStudyArea(sim$studyAreaLarge, ELFsRaster = ELFs["rasWhole"], 
                           ELFsPolygon = ELFs$poly, inputPath = inputPath(sim))
    # terra::plot(out$rast, main = "ELFs that touch Yukon/BC Mountain Caribou Ranges")
    # terra::plot(terra::project(sim$studyAreaLarge, out$rast), add = TRUE)
    ELFsNeeded <- unique(out$poly$ID)
    v <- values(out$rast, dataframe = TRUE)
    out$rast[which(v[[1]] %in% "none")] <- NA
    out$rast <- terra::sieve(out$rast, threshold = 100, directions = 8)
    rr <- terra::trim(out$rast)
    pp <- as.polygons(rr)
    
    # Not all will have SpreadFit yet
    hasELFFittedData <- pp$ELFind %in% spreadFitPreRun$polygonID
    if (any(!hasELFFittedData)) {
      warning("Not all the ELFs have SpreadFit parameters; masking studyAreaLarge to ONLY the ELFs that have data")
      pp <- pp[pp$ELFind %in% spreadFitPreRun$polygonID,]
    }
    
    pp <- terra::project(pp, sim$studyAreaLarge)
    # There are holes that show up
    # pp1 <- terra::buffer(terra::buffer(terra::aggregate(pp), width = 1000), width = -1000)
    pp <- terra::intersect(pp, sim$studyAreaLarge)
    studyAreaLargeELF <- terra::project(pp, ELFs$rasWhole[[1]])
    rr <- rasterize(studyAreaLargeELF, ELFs$rasWhole[[1]], field = "ELFind")
    rasterToMatchLargeELF <- terra::trim(rr)
    rasterToMatchELF <- rasterToMatchLargeELF
    
    w <- 0.00000001 # the aggregate function creates artifacts --> lines that shouldn't be there
    salELFagg <- terra::aggregate(studyAreaLargeELF)
    studyAreaLarge <- terra::buffer(width = -w, terra::buffer(width = w, salELFagg))
    studyAreaELF <- studyAreaLargeELF

  } else {
    rtml <- ELFs$rasWhole[[ELF]]
    rasterToMatchLargeELF <- {
      # rtml <- ELFs$rasWhole[[ELF]]
      if (identical(1, terra::freq(is.na(rtml))$value))
        stop("This ELF has no data")
      rtml[rtml[] == 0] <- NA
      {
        postProcess(rtml, projectTo = rastTemplate, method = "near",
                    writeTo = file.path(inputPath, paste0("rtml_", Par$.studyAreaName,".tif"))) |>
          terra::trim() } |>
        Cache(omitArgs = c("x"),
              .functionName = paste0("rasterToMatchLargeELF"),
              .cacheExtra = list(ELFs = attr(ELFs, "tags"),
                                 ELFind = ELF,
                                 rastTemplate = attr(rastTemplate, "tags")))
    }
    studyAreaLargeELF <- {
      {
        terra::as.polygons(rasterToMatchLargeELF > 0) # |>
        #  terra::buffer(width = d1) |>
        #  terra::buffer(width = -d1)
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
        #  terra::buffer(width = d1) |>
        #  terra::buffer(width = -d1)
        Cache(omitArgs = c("x"), .functionName = "studyArea",
              .cacheExtra = list(rtm = attr(rasterToMatchELF, "tags")))
    }
    studyAreaLarge <- studyAreaLargeELF
  }
  
  # rastTemplate <- { # This is HUGE 2+GB
  #   { postProcess(rastTemplate, to = rasterToMatchLargeELF,
  #                 writeTo = file.path(inputPath, paste0("rasterTemplate_", ELF,".tif")))} |>
  #     Cache(omitArgs = c("x"), .cacheExtra = attr(rastTemplate, "tags"))
  # }
  
  
  # studyAreaReporting <- studyAreaELF
  sppEquiv <- {
    species <- LandR::speciesInStudyArea(studyAreaELF, dPath = inputPath) |>
      reproducible::Cache(omitArgs = "studyArea", .cacheExtra = list(sa = attr(studyAreaELF, "tags")))
    spp <- grep("_Spp", species$speciesList, invert = TRUE, value = TRUE)
    column <- LandR::equivalentNameColumn(spp, LandR::sppEquivalencies_CA)
    #for ForSITE, merge Pice_eng_gla and Pice_eng, and make sure Pinus contorta includes both variants
    sppEquivCol <- P(sim)$sppEquivCol
    studyAreaSpp <- LandR::equivalentName(spp, LandR::sppEquivalencies_CA, column = sppEquivCol, searchColumn = column)
    
    sppEquiv <- LandR::sppEquivalencies_CA[get(sppEquivCol) %in% studyAreaSpp,]
    sppEquiv[LANDIS_traits != "",]

    if ("PICE_ENG_GLA" %in% spp | "PICE_ENG" %in% spp) {
      #get both - treat them as the same - so 
      sppEquiv <- rbind(sppEquiv, 
                        LandR::sppEquivalencies_CA[LandR %in% c("Pice_eng", "Pice_eng_gla")])
      sppEquiv[LandR == "Pice_eng_gla", LandR := "Pice_eng"]
      sppEquiv <- unique(sppEquiv)
    }
  }
  studyAreaPSP <- {
    a <- reproducible::prepInputs(url = paste0("https://sis.agr.gc.ca/cansis/nsdb/ecostrat/",
                                               "province/ecoprovince_shp.zip"), dPath = inputPath,
                                  fun = "terra::vect", projectTo = studyAreaELF) |>
      reproducible::Cache(.functionName = "prepInputs_ecoprovince",
                          omitArgs = "projectTo", .cacheExtra = list(sa = attr(studyAreaELF, "tags")))
    b <- reproducible::postProcess(a, studyArea = studyAreaLarge) |>
      reproducible::Cache(omitArgs = c("x", "studyArea"), .cacheExtra = list(sa = attr(studyAreaLarge, "tags"),
                                                                             sa = attr(a, "tags")))
    ecoprovinces <- unique(b$ECOPROVINC)
    a[a$ECOPROVINC %in% ecoprovinces] # |> terra::aggregate()
  }
  
  if (is.null(sim$studyArea)) # conditional; can't put it in metadata or this will not be run first
    studyArea <- studyAreaLarge

  if (is.null(sim$rasterToMatch)) {# conditional; can't put it in metadata or this will not be run first
    rasterToMatch <- postProcessTo(rastTemplate, maskTo = studyAreaLarge, cropTo = studyAreaLarge)
    rasterToMatch <- terra::trim(rasterToMatch)
    rasterToMatch <- ifel(!is.na(rasterToMatch), 1, NA) # needs to not be zero --> zero is like NA
  }
  
  # Put them all in the sim
  # rm(list = "rastTemplate", envir = envir(sim)) # don't need this
  objsHere <- depends(sim)@dependencies[[currentModule(sim)]]@outputObjects$objectName
  list2env(mget(objsHere, envir = environment()), envir = envir(sim))
  ## 
  
  if (anyPlotting(Par$.plots)) {
    
    runningELFs <- NULL
    if (!is.null(Par$queue_path)) {
      activeRunningPath <- SpaDES.project::tmuxActiveRunningPath(activeRunningPath = NULL, Par$queue_path)
      
      fi <- rownames(
        SpaDES.project:::activeRunningFileInfo(queue_path = Par$queue_path, activeRunningPath = activeRunningPath))
      if (!is.null(fi)) {
        runningELFs <- sapply(basename(fi) |> strsplit(split = "_"), function(x) x[[2]]) 
      } 
    } 
    
    
    Plots(fn = plotAllELFsFn, centred = ELFs$rasCentered,
          crsToUse = terra::crs(ELFs$rasWhole[[11]]), alreadyRun = spreadFitPreRun, runningELFs = runningELFs,
          path = inputPath, deviceArgs = list(width = 11, height = 8, units = "in", res = 300),
          filename = paste0("ELF_polygons.png"), useCache = TRUE
    )
    
    Plots(as.list(sim[grep("studyArea|rasterToMatchELF", names(sim), value = TRUE)]),
          title = paste0("StudyArea ", sim$.ELFind),
          fn = SpaDES.project::plotSAs,
          filename = paste0("studyAreas", sim$.ELFind),
          path = inputPath,
          # ggsaveArgs = list(width = 11, height = 8, units = "in", res = 300),
          ggsaveArgs = list(width = 11, height = 8, units = "in"),
          # deviceArgs = list(width = 11, height = 8, units = "in", res = 300),
          useCache = TRUE)
    
  }
  
  # bring to memory as it is relatively small; better for caching
  for (j in seq_along(ELFs[1:2]))
    for (i in seq_along(ELFs[[j]])) 
      ELFs[[j]][[i]] <- toMemory(ELFs[[j]][[i]])
  sim$ELFs <- ELFs
  
  return(invisible(sim))
}
### template for save events
Save <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sim <- saveFiles(sim)

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

### template for plot events
plotFun <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sampleData <- data.frame("TheSample" = sample(1:10, replace = TRUE))
  Plots(sampleData, fn = ggplotFn) # needs ggplot2

  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

ggplotFn <- function(data, ...) {
  ggplot2::ggplot(data, ggplot2::aes(TheSample)) +
    ggplot2::geom_histogram(...)
}


plotAllELFsFn <- function(centred, crsToUse, alreadyRun, runningELFs) {
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
  if (!missing(runningELFs)) {
    if (NROW(runningELFs)) {
      turnYellow <- sapply(runningELFs, function(x) grep(pattern = x, names(allELFs)))
      terra::plot(allELFs[turnYellow,], add = TRUE, col = "yellow", alpha = 0.5)
    }
  }
  
  terra::text(cen, label = gsub("^X", "", names(allELFs)), cex = 0.8)
}

.inputObjects <- function(sim) {
  
  if (!suppliedElsewhere(".ELFind", sim)) {
    sim$.ELFind <- "4.3"
  }
  
  sim
}