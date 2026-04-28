# Matching-Daten in gescrapte Kursdaten zurückführen

Liest die von
[`finalise_matching()`](https://github.com/Stifterverband/HEXmatchR/reference/finalise_matching.md)
erzeugte Matching-Ausgabe und fügt die zentralen Matching-Spalten
(`matchingart`, `gerit_id`, `einrichtung`) über den Organisationsnamen
in die ursprünglichen gescrapten Kursdaten ein.

## Usage

``` r
import_matching_data(add_to_this_file, matching_file)
```

## Arguments

- add_to_this_file:

  Ein Data Frame oder Pfad zu einer gescrapten `.rds`-Datei, in die die
  Matching-Daten eingespielt werden sollen.

- matching_file:

  Pfad zur Matching-`.rds`-Datei, die von
  [`finalise_matching()`](https://github.com/Stifterverband/HEXmatchR/reference/finalise_matching.md)
  erstellt wurde.

## Value

`add_to_this_file` als Tibble mit den eingejoinssten Matching-Spalten.
