# Gerankte GERIT-Kandidaten für gescrapte Organisationen erzeugen

Komfortfunktion um
[`generate_embedding_candidates()`](https://github.com/Stifterverband/HEXmatchR/reference/generate_embedding_candidates.md),
die für jede noch nicht gematche Organisation die top-`k` ähnlichsten
GERIT-Einträge via OpenAI-Text-Embeddings ermittelt.

## Usage

``` r
generate_candidate_matches(
  df_scraped,
  df_gerit,
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  batch_size = 100
)
```

## Arguments

- df_scraped:

  Ausgabe von
  [`extract_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/extract_scraped_organisations.md).

- df_gerit:

  Ausgabe von
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).

- top_k:

  Maximale Anzahl zurückgegebener Kandidaten pro Organisation.

- embedding_model:

  OpenAI-Embedding-Modellkennung.

- batch_size:

  Anzahl der Texte pro Embedding-API-Anfrage.

## Value

Ein Tibble gerankter GERIT-Kandidaten mit je einer Zeile pro Kombination
(gescrapte Organisation × Kandidat). Die vollständige Spaltenliste ist
bei
[`generate_embedding_candidates()`](https://github.com/Stifterverband/HEXmatchR/reference/generate_embedding_candidates.md)
beschrieben.
