# Matching-Durchlauf abschliessen

Teilt die fertige Match-Tabelle in einen gematchten Anteil und einen
Review-Anteil auf, speichert die Matches in einer standardisierten
`.rds`-Datei und schreibt optional eine `.csv` mit Faellen, die noch
manuell ueberprueft werden muessen.

## Usage

``` r
finalise_matching(
  df_scraped_matching_complete,
  who_matched,
  output_dir = ".",
  matching_iteration = "erstkodierung"
)
```

## Arguments

- df_scraped_matching_complete:

  Gematchte Organisationstabelle, typischerweise das Element
  `organisation_matches` aus
  [`match_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/match_scraped_organisations.md).

- who_matched:

  Benutzername, der in den Ausgabedatei-Metadaten und im Dateinamen
  gespeichert wird.

- output_dir:

  Ausgabeverzeichnis fuer `.rds`- und Review-`.csv`-Datei. Wird rekursiv
  angelegt, falls nicht vorhanden.

- matching_iteration:

  Iterations-Tag im Dateinamen (z. B. `"erstkodierung"`,
  `"zweitkodierung"`).

## Value

Eine Liste mit den Elementen:

- `matched`:

  Tibble der erfolgreich gematchten Organisationen.

- `review`:

  Tibble der Review- oder ungeklaerten Faelle.

- `output_file`:

  Pfad zur geschriebenen `.rds`-Datei.

- `review_file`:

  Pfad zur Review-`.csv`, oder `NA_character_` wenn keine Review-Faelle
  vorliegen.
