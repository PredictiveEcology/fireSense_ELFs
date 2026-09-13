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
