# Verfügbare GERIT-Hochschulnamen auflisten

Liest die Spalte `Hochschul_Name` (oder `HS` in alten Dateien) aus der
GERIT-`.rds`-Datei und gibt alle eindeutigen Namen alphabetisch sortiert
aus.

## Usage

``` r
find_names(gerit_file = "data/GERIT_DESTATIS_data.rds")
```

## Arguments

- gerit_file:

  Pfad zur GERIT-`.rds`-Datei.

## Value

Ein Tibble mit einer Spalte `name_gerit`; wird ausgegeben und unsichtbar
zurückgegeben.
