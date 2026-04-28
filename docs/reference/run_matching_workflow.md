# Matching, Review und Goldstandard-Evaluation in einem Aufruf

Führt automatisches Matching, optionalen Shiny-Review und optional einen
Goldstandard-Vergleich in einem einzigen Aufruf durch und schreibt alle
Ausgabedateien auf die Festplatte.

## Usage

``` r
run_matching_workflow(
  name_gerit,
  gold_data = NULL,
  df_scraped,
  organisation_col = "organisation",
  year_col = "jahr",
  semester_col = "semester",
  model = "gpt-4.1-mini",
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  embedding_batch_size = 100,
  review_confidence = 0.65,
  auto_review = TRUE,
  output_dir = ".",
  matching_iteration = "erstkodierung",
  include_debug = FALSE
)
```

## Arguments

- name_gerit:

  Hochschulname in der Spalte `HS` von `GERIT_DESTATIS_data.rds`.

- gold_data:

  Ein Data Frame oder Pfad zu einer `.rds`-Datei mit manuellen Labels
  (optional).

- df_scraped:

  Gescrapter Kursdaten-Data-Frame. Dessen Spalte `organisation` wird
  gegen `Einrichtung` aus `GERIT_DESTATIS_data.rds` gematcht.

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

  Anzahl der GERIT-Kandidaten, die an das LLM übergeben werden.

- embedding_model:

  OpenAI-Embedding-Modell für den Kandidatenabruf.

- embedding_batch_size:

  Batch-Größe für Embedding-Anfragen.

- review_confidence:

  Unterer Schwellenwert, unterhalb dessen Matches zur Review
  weitergeleitet werden.

- auto_review:

  Ob die Shiny-Review-App automatisch geöffnet werden soll, wenn
  ungeklärte oder markierte Fälle vorliegen.

- output_dir:

  Ausgabeverzeichnis für die Ergebnisdateien.

- matching_iteration:

  Iterations-Tag im Ausgabedateinamen.

- include_debug:

  Ob zusätzlich umfangreiche Zwischenergebnisse zurückgegeben werden
  sollen, z. B. GERIT-Daten, Kandidaten, rohe LLM-Entscheidungen und
  Vorher-/Nachher-Organisationstabellen.

## Value

Eine Liste mit sprechend benannten Hauptergebnissen:

- `scraped_data_with_matching`:

  Ursprüngliche gescrapte Daten mit zurückgefügten Match-Spalten. Dieses
  Objekt wird zusätzlich als `.rds` gespeichert, damit der wichtigste
  Arbeitsstand auch bei späteren Fehlern erhalten bleibt.

- `matched_organisations`:

  Erfolgreich gematchte Organisationen.

- `review_cases`:

  Offene oder unklare Fälle.

- `goldstandard_evaluation`:

  Goldstandard-Vergleich oder `NULL`, wenn kein `gold_data` übergeben
  wurde.

- `scraped_output_file`:

  Pfad zur geschriebenen `scraped_data_with_matching`-`.rds`.

Wenn `include_debug = TRUE`, enthält die Liste zusätzlich das Element
`debug` mit umfangreichen Zwischenergebnissen.

## Details

Zur Einordnung von `score` und Match-Entscheidung:

- Die Embedding-Scores entstehen beim Kandidatenabruf und messen nur
  semantische Aehnlichkeit zwischen Organisationstexten.

- Diese Scores sind keine direkt kalibrierte Match-Wahrscheinlichkeit.

- Das finale Match (`select_candidate` oder `no_match`) entscheidet das
  LLM im Schritt
  [`match_organisations_with_llm()`](https://github.com/Stifterverband/HEXmatchR/reference/match_organisations_with_llm.md).

Unsicherheit wird ueber `review_confidence` operationalisiert: Faelle
mit zu niedriger (oder fehlender) Konfidenz werden fuer manuelle Review
markiert.
