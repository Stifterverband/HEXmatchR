# GERIT-Daten für das Matching vorbereiten

Liest die GERIT-Basis aus einer `.rds`-Datei, filtert auf die gewünschte
Hochschule (`Hochschul_Name`, ehemals `HS`) und bereitet die Kernfelder
für das Matching von gescrapten `organisation`-Werten gegen `Gerit_Orga`
(ehemals `Einrichtung`) vor.

## Usage

``` r
prepare_gerit_data(name_gerit, gerit_file = "data/GERIT_DESTATIS_data.rds")
```

## Arguments

- name_gerit:

  Hochschulname genau so, wie er in `Hochschul_Name` der GERIT-Datei
  vorkommt.

- gerit_file:

  Pfad zur GERIT-`.rds`-Datei.

## Value

Ein Tibble mit den gefilterten GERIT-Einträgen. Enthält alle Spalten aus
der Quelle plus: `gerit_ID` als stabilen Schlüssel für
Kandidatenauswahl, Review und Matching-Exporte; `gerit_cleaned` für
robustere Textvergleiche im deterministischen und embedding-basierten
Matching; `unique_name_for_einrichtung` als Flag, ob ein
Einrichtungsname in der gefilterten GERIT-Menge eindeutig ist.
