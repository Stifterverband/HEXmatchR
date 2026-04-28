# Matching-Pipeline von Anfang bis Ende ausführen

Bereitet GERIT-Daten vor, führt die vollständige automatische
Matching-Pipeline
([`match_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/match_scraped_organisations.md))
aus und schließt die Ausgabe ab, indem Matches und eine Review-CSV auf
die Festplatte geschrieben werden. Öffnet die interaktive Review-App
nicht; für einen vollständigen Durchlauf inklusive Shiny-Review-Schritt
[`run_matching_workflow()`](https://github.com/Stifterverband/HEXmatchR/reference/run_matching_workflow.md)
verwenden.

## Usage

``` r
run_matching_pipeline(
  name_gerit,
  df_scraped,
  organisation_col = "organisation",
  year_col = "jahr",
  semester_col = "semester",
  model = "gpt-4.1-mini",
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  embedding_batch_size = 100,
  review_confidence = 0.65,
  output_dir = "."
)
```

## Arguments

- name_gerit:

  Hochschulname genau so, wie er in `HS` von `GERIT_DESTATIS_data.rds`
  vorkommt. Mit
  [`find_names()`](https://github.com/Stifterverband/HEXmatchR/reference/find_names.md)
  können alle verfügbaren Namen angezeigt werden.

- df_scraped:

  Gescrapter Kursdaten-Data-Frame.

- organisation_col:

  Spalte in den gescrapten Daten mit den Organisationsnamen.

- year_col:

  Spalte in den gescrapten Daten mit der Jahresangabe.

- semester_col:

  Spalte in den gescrapten Daten mit der Semesterangabe.

- model:

  OpenAI-Modell für
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html).

- top_k:

  Anzahl der GERIT-Kandidaten pro Organisation, die an das LLM übergeben
  werden.

- embedding_model:

  OpenAI-Embedding-Modell für den Kandidatenabruf.

- embedding_batch_size:

  Batch-Größe für Embedding-Anfragen.

- review_confidence:

  Unterer Schwellenwert, unterhalb dessen Matches zur Review
  weitergeleitet werden.

- output_dir:

  Ausgabeverzeichnis für die Ergebnisdateien.

## Value

Eine Liste mit den Elementen `df_gerit`, `organisation_matches`,
`df_scraped_matched`, `candidates`, `llm_decisions`, `matched`,
`review`, `output_file` und `review_file`.
