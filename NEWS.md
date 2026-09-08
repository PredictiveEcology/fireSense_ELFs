# fireSense_ELFs 1.1.1

- the module now stops when it is given both a `studyAreaLarge` and a `.ELFind`
  that describe different study areas. It used to take `studyAreaLarge` and
  ignore `.ELFind`, while `.studyAreaName` still named every input and output
  folder from `.ELFind` -- so runs were labelled with an ELF they had not used.
- the module now declares `loadOrder = list(before = <the fireSense modules>)`, so
  it is scheduled before them without the caller having to know to ask. Callers
  were passing a `studyAreaLarge` during fitting purely to force that order, which
  is what caused the mislabelled runs above. Naming modules that are absent from a
  given run is harmless; they are ignored.

# fireSense_ELFs 0.0.1 (26 January 2026)

- initial module version
