# Review-Ergebnisse in die Match-Tabelle zurückschreiben

Diese Funktion übernimmt die Entscheidungen aus dem manuellen Review und
aktualisiert damit die passenden Zeilen in `organisation_matches`.

## Usage

``` r
apply_review_decisions(organisation_matches, review_decisions, df_gerit)
```

## Arguments

- organisation_matches:

  Eine Tabelle mit Organisations-Matches, zum Beispiel
  `llm_result$scraped` aus
  [`match_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/match_scraped_organisations.md).
  Sie muss eine Spalte `scraped_ID` enthalten.

- review_decisions:

  Eine Tabelle mit den manuellen Review-Entscheidungen, zum Beispiel
  `run_review_app(...)$decisions`. Erwartet werden mindestens die
  Spalten `scraped_ID` und `review_decision`. Je nach Entscheidung
  werden außerdem `selected_gerit_id` und `review_comment` verwendet.

- df_gerit:

  Die vorbereiteten GERIT-Daten aus
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).
  Diese werden nur gebraucht, wenn im Review ein alternativer Kandidat
  ausgewählt wurde.

## Value

`organisation_matches` mit aktualisierten Match-Spalten für alle
bearbeiteten Review-Fälle.

## Details

Für jede `scraped_ID` wird die gewählte Entscheidung angewendet:

- `"accept_model_match"`: den bisherigen Match bestätigen

- `"select_other_candidate"`: einen anderen GERIT-Kandidaten übernehmen

- `"mark_no_match"`: festhalten, dass es keinen passenden GERIT-Eintrag
  gibt

Entscheidungen mit `NA` oder `"skip"` werden ignoriert. Alle anderen
Zeilen in `organisation_matches` bleiben unverändert.
