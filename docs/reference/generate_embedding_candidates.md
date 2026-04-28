# GERIT-Kandidaten per OpenAI-Embeddings erzeugen

Bettet alle noch nicht gematchten gescrapten Organisationen und alle
eindeutig benannten GERIT-Eintraege mit dem angegebenen OpenAI-Modell
ein, berechnet Kosinusaehnlichkeiten und gibt die top-`k` GERIT-
Kandidaten pro Organisation zurueck. Erfordert die Umgebungsvariable
`OPENAI_API_KEY`.

## Usage

``` r
generate_embedding_candidates(
  df_scraped,
  df_gerit,
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  batch_size = 100,
  gerit_embedding_cache_file = file.path("data", "cache", paste0("gerit_embeddings_",
    gsub("[^A-Za-z0-9_-]+", "_", embedding_model), ".rds"))
)
```

## Arguments

- df_scraped:

  Ausgabe von
  [`extract_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/extract_scraped_organisations.md)
  nachdem deterministische Matches bereits angewendet wurden.

- df_gerit:

  Ausgabe von
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).

- top_k:

  Maximale Anzahl zurueckgegebener Kandidaten pro Organisation.

- embedding_model:

  OpenAI-Embedding-Modellkennung.

- batch_size:

  Anzahl der Texte pro Embedding-API-Anfrage.

- gerit_embedding_cache_file:

  Pfad zu einer `.rds`-Cache-Datei fuer GERIT-Embeddings. Bereits
  gespeicherte Embeddings werden wiederverwendet; fehlende Eintraege
  werden neu von der OpenAI-API abgerufen. Mit `NULL` wird kein Cache
  verwendet.

## Value

Ein Tibble gerankter GERIT-Kandidaten mit den Spalten `scraped_ID`,
`organisation`, `cleaned`, `gerit_ID`, `Einrichtung`, `score`,
`candidate_rank` und `candidate_source`. Gibt ein leeres Tibble zurueck,
wenn alle Organisationen bereits gematcht sind.

## Details

Der Rueckgabewert `score` ist die Kosinusaehnlichkeit zwischen dem
Embedding der gescrapten Organisation und dem Embedding der GERIT-
Einrichtung. Die Embeddings kommen aus der OpenAI-Embedding-API mit dem
in `embedding_model` gesetzten Modell.

Wichtige Interpretation von `score`:

- Hoher Wert bedeutet: hohe semantische Aehnlichkeit der Texte.

- Niedriger Wert bedeutet: geringe semantische Aehnlichkeit.

- Der Wert ist eine Ranking-Groesse fuer die Kandidatenauswahl und keine
  kalibrierte Wahrscheinlichkeit fuer einen korrekten Match.

- Ein guter `score` allein reicht nicht als finale Match-Entscheidung;
  die finale Entscheidung trifft im naechsten Schritt das LLM.
