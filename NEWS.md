# fireSense_ELFs 1.1.6

- `spreadFitFilename` now defaults to `"latest"`: each ELF's fit comes from the most recent
  `fireSenseParams_*_linearFuel.rds` file in `spreadFitGoogleDriveFolder` that has it
  (`fireSenseUtils::latestSpreadFits()`), so `spreadFitPreRun` lists every ELF fitted with the current
  model. A named file is read as before.

# fireSense_ELFs 1.1.5

- **needs `fireregimetools >= 0.1.0.9008`.** `fewFireELFs()` reads NFDB and NBAC through
  `load_nfdb_points()` and `load_nbac_polys()` with a study area. From 0.1.0.9007 these read only the
  study area's extent instead of the whole national file (FOR-CAST/fireregimetools#2), and 0.1.0.9008
  builds that extent from the study area's outline so records just inside a curved or reprojected edge
  are kept. 0.1.0.9007 is also the version of a superseded fork, so 0.1.0.9008 is the first version
  that is unambiguously the merged code.

# fireSense_ELFs 1.1.4

- `Init` takes its species table from `LandR::speciesInStudyArea()$sppEquiv` instead of building
  one here. LandR applies the same rules this module did by hand -- no `_Spp` genus entries, only
  species with `LANDIS_traits`, and the white x Engelmann spruce hybrid merged into Engelmann
  spruce -- so the fireSense modules and the Biomass modules now read one table built in one
  place, and its logic is tested in LandR rather than here. `sppEquivCol` is passed through, so
  the table comes back keyed on the naming convention this run uses.
- **needs `LandR >= 1.2.0.9021`.** `sppEquiv` was added to the return value at 1.2.0.9020, the
  version LandR `development` already carried, so a floor of `>= 1.2.0.9020` would also be met by
  an earlier 1.2.0.9020 whose `speciesInStudyArea()` returns no `sppEquiv` -- failing at run time
  with an empty species table instead of at install time.
- The no-tree-species announcement (1.1.2) is unchanged and still made here: LandR returns the
  0-row table, this module says which ELF it belongs to.

# fireSense_ELFs 1.1.3

- ELFs with too few fires can now be fitted by merging them with a neighbour. With `fireYears` set, `init`
  counts each ELF's natural-cause ignitions (NFDB points) and fire polygons (NBAC) over those years, reading
  the fire records as fireSense_dataPrepFit does. An ELF below `minNaturalIgnitions` or `minFirePolygons`
  (50 each) merges with the neighbouring ELF of the same base and depth that shares the longest border, and
  the merged ELF is named by the shared base and the members' last parts (3.2.1 with 3.2.4 is `3.2.1_4`).
  If the pair is still too thin, neither is fitted. The results are the outputs `ELFfireStatus`, `ELFmerges`
  and `ELFsExcluded`, which `fireSenseUtils::runELFs()` leaves out of the queue. The merge happens before this
  run's ELF is picked, and an `.ELFind` naming a merged member runs as its merged ELF. ELFs of ecozones 1
  and 2 are out permanently: they are neither counted nor merged. `fireYears = NULL` (the default) keeps the
  previous behaviour.
- The national ELF map and the fire counts are cached with `useCache = TRUE`: they do not depend on the ELF,
  and under `spades.useCache = "eventsOnly"` a plain `Cache()` there is skipped, so every job would rebuild
  them.

# fireSense_ELFs 1.1.2

- an ELF with no tree species now says so, once: `Init`'s `sppEquiv` block emits a single
  message naming the ELF and stating that the run proceeds with nonForest fuel classes only.
  It used to be silent, and the run died several modules later in "No trait values were
  found for .". The block still returns a valid 0-row `sppEquiv` in that case, not NULL.

# fireSense_ELFs 1.1.1

- the module now stops when it is given both a `studyAreaLarge` and a `.ELFind`
  that describe different study areas. It used to take `studyAreaLarge` and
  ignore `.ELFind`, while `.studyAreaName` still named every input and output
  folder from `.ELFind` -- so runs were labelled with an ELF they had not used.
- a missing fit ledger on Google Drive is now treated as "nothing has been fitted"
  rather than erroring. That is the normal state at the start of a new experiment,
  when `spreadFitFilename` names a file the first completed fit will create; before
  this, pointing it at a new filename failed in every job, and in
  `fireSenseUtils::runELFs()` before the queue was even built.
- the module now declares `loadOrder = list(before = <the fireSense modules>)`, so
  it is scheduled before them without the caller having to know to ask. Callers
  were passing a `studyAreaLarge` during fitting purely to force that order, which
  is what caused the mislabelled runs above. Naming modules that are absent from a
  given run is harmless; they are ignored.

# fireSense_ELFs 0.0.1 (26 January 2026)

- initial module version
