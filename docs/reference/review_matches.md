# Organisationsmatches in einer Shiny-App reviewen

Bereitet die Review-Fälle vor, startet die interaktive Shiny-App
([`run_review_app()`](https://github.com/Stifterverband/HEXmatchR/reference/run_review_app.md))
und wendet die erfassten Entscheidungen auf die Matches an.

## Usage

``` r
review_matches(
  organisation_matches,
  candidates,
  df_gerit,
  review_filter = NULL,
  reviewed_by = current_username()
)
```

## Arguments

- organisation_matches:

  Organisationsebene-Matches, typischerweise aus
  [`match_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/match_scraped_organisations.md)
  oder `llm_result$scraped`.

- candidates:

  Kandidaten-Tabelle aus
  [`generate_embedding_candidates()`](https://github.com/Stifterverband/HEXmatchR/reference/generate_embedding_candidates.md)
  oder `result$candidates`.

- df_gerit:

  Vorbereitete GERIT-Daten aus
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).

- review_filter:

  Optionaler logischer Filter. Standard:
  `needs_review | matched == "no"`.

- reviewed_by:

  Optionaler Reviewer-Name, der bei jeder Entscheidung gespeichert wird.

## Value

Eine Liste mit den Elementen `review_cases`, `review_result`,
`review_decisions` und `organisation_matches_reviewed`.
