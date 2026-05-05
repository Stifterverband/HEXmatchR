# Eindeutige Organisationen aus gescrapten Daten extrahieren

Dedupliziert die Organisationsspalte der gescrapten Kursdaten, zerlegt
semikolongetrennte Mehrfachorganisationseintraege in einzelne Zeilen,
erzeugt bereinigte Organisationsnamen und initialisiert alle
Match-Spalten mit Standardleerwerten.

## Usage

``` r
extract_scraped_organisations(
  df_scraped,
  organisation_col = "organisation",
  year_col = "jahr",
  semester_col = "semester"
)
```

## Arguments

- df_scraped:

  Gescrapter Kursdaten-Data-Frame, z. B. aus
  [`HEXCleanR::load_data_from_sp()`](https://rdrr.io/pkg/HEXCleanR/man/load_data_from_sp.html).

- organisation_col:

  Spalte mit den Organisationsnamen.

- year_col:

  Ungenutzt; nur aus Kompatibilitaetsgruenden vorhanden.

- semester_col:

  Ungenutzt; nur aus Kompatibilitaetsgruenden vorhanden.

## Value

Ein Tibble eindeutiger Organisationen mit den Spalten `scraped_ID`,
`organisation`, `organisation_names_for_matching_back`,
`organisation_original`, `cleaned` sowie leeren Match-Spalten
(initialisiert mit `"no"` bzw. `NA`).
