# Gescrapte Organisationen mit GERIT-Einrichtungen matchen

Orchestriert die vollständige Matching-Pipeline: extrahiert eindeutige
Werte aus der gescrapten Spalte `organisation`, matched sie gegen
`Einrichtung` aus den vorbereiteten GERIT-Daten, generiert
Embedding-Kandidaten, führt LLM-basiertes Matching durch und fügt die
Ergebnisse in die ursprünglichen gescrapten Daten ein.

## Usage

``` r
match_scraped_organisations(
  df_scraped,
  df_gerit,
  organisation_col = "organisation",
  year_col = "jahr",
  semester_col = "semester",
  model = "gpt-4.1-mini",
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  embedding_batch_size = 100,
  review_confidence = 0.65
)
```

## Arguments

- df_scraped:

  Gescrapter Kursdaten-Data-Frame.

- df_gerit:

  Vorbereitete GERIT-Daten aus
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).

- organisation_col:

  Spalte in `df_scraped` mit den Organisationsnamen.

- year_col:

  Spalte in `df_scraped` mit der Jahresangabe.

- semester_col:

  Spalte in `df_scraped` mit der Semesterangabe.

- model:

  OpenAI-Modell für
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html).

- top_k:

  Anzahl der GERIT-Kandidaten, die pro Organisation an das LLM übergeben
  werden.

- embedding_model:

  OpenAI-Embedding-Modell für den Kandidatenabruf.

- embedding_batch_size:

  Batch-Größe für Embedding-Anfragen.

- review_confidence:

  Unterer Schwellenwert, unterhalb dessen ein Fall zur Review
  weitergeleitet wird.

## Value

Eine Liste mit den Elementen:

- `organisation_matches`:

  Organisationsebene-Tibble mit allen befüllten Match-Spalten.

- `candidates`:

  Kandidaten-Tibble aus dem Embedding-Retrieval.

- `llm_decisions`:

  Rohe LLM-Entscheidungen als Tibble.

- `df_scraped_matched`:

  Vollständiger gescrapter Data Frame mit zurückgefügten Match-Spalten.

## Details

Der in den Kandidaten enthaltene `score` stammt aus dem Embedding-
Retrieval und dient nur dazu, Kandidaten nach semantischer Aehnlichkeit
zu sortieren. Die finale Match-Entscheidung trifft das LLM im Schritt
[`match_organisations_with_llm()`](https://github.com/Stifterverband/HEXmatchR/reference/match_organisations_with_llm.md)
auf Basis der Kandidatenliste, Bezeichnungen und des Prompts.

Unsicherheit wird in der Praxis ueber `review_confidence` gesteuert:
Entscheidungen unterhalb des Schwellenwerts (oder ohne Konfidenz) werden
als Review-Faelle markiert.
