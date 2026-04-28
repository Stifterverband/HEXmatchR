# Review-Fälle für die Shiny-Review-App vorbereiten

Filtert die Organisations-Match-Tabelle auf Fälle, die manuell überprüft
werden müssen, ergänzt die zugehörigen Kandidaten um lesbare Labels und
initialisiert eine leere Entscheidungstabelle, die der Reviewer
ausfüllen kann.

## Usage

``` r
prepare_review_cases(organisation_matches, candidates, review_filter = NULL)
```

## Arguments

- organisation_matches:

  Organisationsebene-Matches, typischerweise aus
  [`match_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/match_scraped_organisations.md).

- candidates:

  Kandidaten-Tabelle aus
  [`generate_embedding_candidates()`](https://github.com/Stifterverband/HEXmatchR/reference/generate_embedding_candidates.md).

- review_filter:

  Optionaler logischer Vektor zum Filtern von `organisation_matches`.
  Standard: `needs_review | matched == "no"`.

## Value

Eine Liste mit den Elementen:

- `review_cases`:

  Gefiltertes Tibble der zu prüfenden Organisationen.

- `candidate_choices`:

  Kandidaten-Tibble mit zusätzlicher `candidate_label`-Spalte für die
  App-Anzeige.

- `decisions`:

  Vorinitialisiertes Entscheidungs-Tibble mit je einer Zeile pro
  Review-Fall und allen Entscheidungsspalten auf `NA` gesetzt.
