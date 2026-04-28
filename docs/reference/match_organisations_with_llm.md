# Fachgebiete per LLM (OpenAI via ellmer) matchen

Erstellt fuer jedes noch nicht gematchte gescrapte Fachgebiet einen
strukturierten Prompt aus den top-k Kandidaten und befragt das LLM nach
dem besten Treffer oder keinem Match. Review-Faelle werden nur fuer
wirklich unsichere Entscheidungen markiert: bei fehlender Konfidenz oder
unter `review_confidence`.

## Usage

``` r
match_organisations_with_llm(
  df_scraped,
  candidate_tbl,
  df_gerit,
  model = "gpt-4.1-mini",
  review_confidence = 0.65,
  temperature = 0
)
```

## Arguments

- df_scraped:

  Ausgabe von
  [`extract_scraped_organisations()`](https://github.com/Stifterverband/HEXmatchR/reference/extract_scraped_organisations.md)
  nachdem deterministische Matches angewendet wurden.

- candidate_tbl:

  Ausgabe von
  [`generate_embedding_candidates()`](https://github.com/Stifterverband/HEXmatchR/reference/generate_embedding_candidates.md).

- df_gerit:

  Ausgabe von
  [`prepare_gerit_data()`](https://github.com/Stifterverband/HEXmatchR/reference/prepare_gerit_data.md).

- model:

  OpenAI-Modellname fuer
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html).

- review_confidence:

  Numerischer Schwellenwert; LLM-Entscheidungen darunter werden fuer
  Review markiert.

- temperature:

  Numerischer Wert zwischen 0 und 1 fuer die Zufaelligkeit des LLM.
  Standard: 0 fuer deterministische Ausgaben.

## Value

Eine Liste mit den Elementen:

- `scraped`:

  Aktualisiertes Fachgebiets-Tibble mit eingetragenen LLM-Matches.

- `decisions`:

  Tibble der rohen LLM-Entscheidungen, eine Zeile pro verarbeitetem
  Fachgebiet.

## Details

Wie OpenAI hier die Match-Entscheidung trifft:

- Das Modell sieht pro Organisation nur die top-k Kandidaten aus dem
  Embedding-Retrieval (inklusive `embedding_score`).

- Es darf ausschliesslich zwischen zwei Entscheidungen waehlen:
  `select_candidate` oder `no_match`.

- Bei `select_candidate` muss `selected_candidate_id` exakt eine
  erlaubte `gerit_ID` aus der Kandidatenliste sein.

- Die Antwort wird ueber ein striktes JSON-Schema validiert, damit keine
  anderen Entscheidungswerte oder zusaetzlichen Felder auftreten.

Wie Unsicherheit behandelt wird:

- Das Modell gibt eine `confidence` im Bereich \[0, 1\] zur eigenen
  Entscheidung an.

- Ein Fall wird als unsicher fuer Review markiert, wenn
  `confidence < review_confidence` oder `confidence` fehlt.

- Das vom Modell gelieferte Feld `needs_review` wird ebenfalls
  beruecksichtigt; die Pipeline setzt Review aber in jedem Fall, sobald
  die Konfidenz unter dem Schwellenwert liegt.

- `review_confidence` ist damit der praktische Punkt, ab dem die
  automatische Entscheidung als nicht ausreichend sicher gilt.
