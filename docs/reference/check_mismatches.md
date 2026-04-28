# Falsch gematchte Goldstandard-Fälle anzeigen

Filtert die Goldstandard-Evaluation auf Fälle mit vorhandenem
Goldstandard- LUF, bei denen die vorhergesagten LUFs nicht korrekt sind,
und gibt nur die für die Prüfung relevanten GERIT-Spalten zurück.

## Usage

``` r
check_mismatches(x)
```

## Arguments

- x:

  Entweder das Ergebnis von
  [`run_matching_workflow()`](https://github.com/Stifterverband/HEXmatchR/reference/run_matching_workflow.md),
  die Liste `workflow_result$goldstandard_evaluation` oder direkt deren
  `comparison`-Tabelle.

## Value

Ein Tibble mit den Spalten `Scraping_Orga`, `Gerit_Orga`, `Matchingart`,
`Fachgebiet_Gerit_1` bis `Fachgebiet_Gerit_6`, `LUF_IDs_Gerit`,
`LUF_Namen_Gerit`, `Faechergruppen_IDs_Gerit` und
`Faechergruppen_Gerit`. Die Goldstandard-Spalten stehen gesammelt am
Ende.
