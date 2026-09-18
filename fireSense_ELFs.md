---
title: "fireSense_ELFs Manual"
subtitle: "v.1.1.4"
date: "Last updated: 2026-09-18"
output:
  bookdown::html_document2:
    toc: true
    toc_float: true
    theme: sandstone
    number_sections: false
    df_print: paged
    keep_md: yes
editor_options:
  chunk_output_type: console
bibliography: citations/references_fireSense_ELFs.bib
link-citations: true
always_allow_html: true
---

# fireSense_ELFs Module

<!-- the following are text references used in captions for LaTeX compatibility -->
(ref:fireSense-ELFs) *fireSense_ELFs*



[![made-with-Markdown](figures/markdownBadge.png)](https://commonmark.org)

<!-- if knitting to pdf remember to add the pandoc_args: ["--extract-media", "."] option to yml in order to get the badge images -->

#### Authors:

Eliot McIntire <eliot.mcintire@nrcan-rncan.gc.ca> [aut, cre]
<!-- ideally separate authors with new lines, '\n' not working -->

## Module Overview

### Module summary

Provide a brief summary of what the module does / how to use the module.

Module documentation should be written so that others can use your module.
This is a template for module documentation, and should be changed to reflect your module.

### Module inputs and parameters

Describe input data required by the module and how to obtain it (e.g., directly from online sources or supplied by other modules)
If `sourceURL` is specified, `downloadData("fireSense_ELFs", "..")` may be sufficient.

Table \@ref(tab:moduleInputs-fireSense-ELFs) shows the full list of module inputs.

<table class="table" style="margin-left: auto; margin-right: auto;">
<caption>(\#tab:moduleInputs-fireSense-ELFs)(\#tab:moduleInputs-fireSense-ELFs)List of (ref:fireSense-ELFs) input objects and their description.</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> objectName </th>
   <th style="text-align:left;"> objectClass </th>
   <th style="text-align:left;"> desc </th>
   <th style="text-align:left;"> sourceURL </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> .ELFind </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> Some descriptive, short name for this fitting, e.g., ELF14.1 </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> studyAreaLarge </td>
   <td style="text-align:left;"> SpatVector </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
  </tr>
</tbody>
</table>

#### Sharing the ELF maps: `.useCloud`

Building the ELF maps in the `init` event is slow, so its results are shared with
everyone through Google Drive. They are saved to the same fireSense folder that holds
the fitted-parameter file (`fireSenseParams*.rds`): the folder named by
`spreadFitGoogleDriveFolder`. Everyone reads from and writes to this one folder.

- `.useCloud = TRUE` (the default): if someone has already built the maps with the same
  inputs, download them; otherwise build them and upload them for the next person.
- `.useCloud = "pull"`: download if available, but never upload. Use this if you can read
  the folder but not write to it. Uploads that fail are not fatal in any case; the run
  carries on with the local copy.
- `.useCloud = FALSE`: do not use Google Drive for this; build locally.

This needs Google Drive access to that folder, which the module already needs: `init`
reads the fitted-parameter file from it. Pass the folder as its bare ID, or as a link
that has something after the ID (e.g. ending in `?usp=drive_link`); until
reproducible's link handling is fixed, a link that ends exactly at the ID is not
recognised, and the results go to a folder that is not shared.

Summary of user-visible parameters (Table \@ref(tab:moduleParams-fireSense-ELFs))


<table class="table" style="margin-left: auto; margin-right: auto;">
<caption>(\#tab:moduleParams-fireSense-ELFs)(\#tab:moduleParams-fireSense-ELFs)List of (ref:fireSense-ELFs) parameters and their description.</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> paramName </th>
   <th style="text-align:left;"> paramClass </th>
   <th style="text-align:left;"> default </th>
   <th style="text-align:left;"> min </th>
   <th style="text-align:left;"> max </th>
   <th style="text-align:left;"> paramDesc </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> sppEquivCol </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> LandR </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> The column in `sim$speciesEquivalency` data.table to use as a naming convention. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> spreadFitFilename </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> fireSens.... </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> A Googledrive folder url where a file with fireSense studyArea exists as an 'sf' class object </td>
  </tr>
  <tr>
   <td style="text-align:left;"> spreadFitGoogleDriveFolder </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> https://.... </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> A Googledrive folder url where a file with fireSense studyArea exists as an 'sf' class object </td>
  </tr>
  <tr>
   <td style="text-align:left;"> queue_path </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> A character scalar indicating what the filename of the queue.rds file is from experimentTmux; if NULL, then this can't determine which ELFs are being run (no 'yellow' on the map) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> fireYears </td>
   <td style="text-align:left;"> integer </td>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Fire years over which each ELF's natural ignitions and fire polygons are counted. An ELF with too few is merged with a neighbour that shares its base, or not fitted (see `fireSenseUtils::ELFmergePlan()`). `NULL`: no counting and no merging. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> minNaturalIgnitions </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 50 </td>
   <td style="text-align:left;"> 0 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> An ELF with fewer natural-cause ignitions than this over `fireYears` has too few fires. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> minFirePolygons </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 50 </td>
   <td style="text-align:left;"> 0 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> An ELF with fewer fire polygons than this over `fireYears` has too few fires. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .plots </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> screen </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Used by Plots function, which can be optionally used here </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .plotInitialTime </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> 0 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Describes the simulation time at which the first plot event should occur. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .plotInterval </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Describes the simulation time interval between plot events. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .saveInitialTime </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Describes the simulation time at which the first save event should occur. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .saveInterval </td>
   <td style="text-align:left;"> numeric </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> This describes the simulation time interval between save events. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .studyAreaName </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Human-readable name for the study area used - e.g., a hash of the studyarea obtained using `reproducible::studyAreaName()` </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .useCache </td>
   <td style="text-align:left;"> logical </td>
   <td style="text-align:left;"> init </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Should caching of events or module be used? </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .useCloud </td>
   <td style="text-align:left;"> logical,.... </td>
   <td style="text-align:left;"> TRUE </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Share the ELF maps built in the `init` event through Google Drive, in the fireSense folder named by `spreadFitGoogleDriveFolder` (the same folder that holds the fitted-parameter file). `TRUE`: download the maps if someone has already built them with the same inputs, otherwise build and upload them. `"pull"`: download only, never upload (for read-only access). `FALSE`: build locally without Google Drive. Needs Google Drive access to that folder. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> .useCacheArgs </td>
   <td style="text-align:left;"> list </td>
   <td style="text-align:left;"> list(use.... </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> Extra `Cache()` arguments for each event. By default the `init` event uses `.useCloud` and caches to `spreadFitGoogleDriveFolder`; see `.useCloud`. Its key also includes a digest of `LandR::sppEquivalencies_CA`, which `init` reads, so a change to that table rebuilds the ELF maps instead of reusing old ones. </td>
  </tr>
</tbody>
</table>

### Events

Describe what happens for each event type.

### Plotting

Write what is plotted.

### Saving

Write what is saved.

### Module outputs

Description of the module outputs (Table \@ref(tab:moduleOutputs-fireSense-ELFs)).

<table class="table" style="margin-left: auto; margin-right: auto;">
<caption>(\#tab:moduleOutputs-fireSense-ELFs)(\#tab:moduleOutputs-fireSense-ELFs)List of (ref:fireSense-ELFs) outputs and their description.</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> objectName </th>
   <th style="text-align:left;"> objectClass </th>
   <th style="text-align:left;"> desc </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> homogeneousFire </td>
   <td style="text-align:left;"> SpatRaster </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> ELFs </td>
   <td style="text-align:left;"> SpatRaster </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> rasterToMatchLargeELF </td>
   <td style="text-align:left;"> SpatRaster </td>
   <td style="text-align:left;"> A very coarse rasterToMatch (5kmx5km); with the ELF values on it </td>
  </tr>
  <tr>
   <td style="text-align:left;"> rasterToMatchELF </td>
   <td style="text-align:left;"> SpatRaster </td>
   <td style="text-align:left;"> This will be smaller than rasterToMatchLargeELF if the studyAreaLarge covers less than one ELF, i.e., the buffers will be removed. But if there are no buffers (i.e., studyAreaLarge covers more than one ELF), then it will be same as rasterToMatchLargeELF </td>
  </tr>
  <tr>
   <td style="text-align:left;"> rasterToMatch </td>
   <td style="text-align:left;"> SpatRaster </td>
   <td style="text-align:left;"> If not supplied from another source, it will be studyArea, with metadata from trim(ELFs$rasCentred) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> studyArea </td>
   <td style="text-align:left;"> SpatVector </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> studyAreaLarge </td>
   <td style="text-align:left;"> SpatVector </td>
   <td style="text-align:left;"> This will be the inputted studyAreaLarge, but intersected with the ELFs that have results for them </td>
  </tr>
  <tr>
   <td style="text-align:left;"> studyAreaLargeELF </td>
   <td style="text-align:left;"> SpatVector </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> studyAreaELF </td>
   <td style="text-align:left;"> SpatVector </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> sppEquiv </td>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> studyAreaPSP </td>
   <td style="text-align:left;"> SpatVector </td>
   <td style="text-align:left;"> NA </td>
  </tr>
  <tr>
   <td style="text-align:left;"> ELFsExcluded </td>
   <td style="text-align:left;"> character </td>
   <td style="text-align:left;"> ELFs with too few fires over `fireYears` that could not be merged; fireSenseUtils::runELFs() leaves them out of the queue. NULL when `fireYears` is NULL. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> ELFfireStatus </td>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:left;"> Natural ignitions, fire polygons and zero/few/ok status of every ELF over `fireYears` (fireSenseUtils::ELFfitStatus()). NULL when `fireYears` is NULL. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> ELFmerges </td>
   <td style="text-align:left;"> data.table </td>
   <td style="text-align:left;"> The merges and skips decided for ELFs with too few fires (fireSenseUtils::ELFmergePlan()). NULL when `fireYears` is NULL. </td>
  </tr>
  <tr>
   <td style="text-align:left;"> spreadFitPreRun </td>
   <td style="text-align:left;"> data.frame </td>
   <td style="text-align:left;"> This is a data.frame that has a geometry list column, so it can be converted to a sf or SpatVector (e.g., `terra::vect(sf::st_as_sf(sim$spreadFitPreRun))` , plus other mostly list columns: numIterations, objFunVal (not list), params, sppEquiv, nonForestedLCCGroups, missingLCCgroup, and polygonID. These are from previously fitted SpreadFit. If no pre-existing object exists from CacheGeo, this will be NULL </td>
  </tr>
</tbody>
</table>

### Links to other modules

Describe any anticipated linkages to other modules, such as modules that supply input data or do post-hoc analysis.

### Getting help

-   provide a way for people to obtain help (e.g., module repository issues page)

## References

<!-- autogenerated from bibligraphy -->
