#' GERIT-Kandidaten per OpenAI-Embeddings erzeugen
#'
#' Bettet alle noch nicht gematchten gescrapten Organisationen und alle
#' eindeutig benannten GERIT-Eintraege mit dem angegebenen OpenAI-Modell
#' ein, berechnet Kosinusaehnlichkeiten und gibt die top-`k` GERIT-
#' Kandidaten pro Organisation zurueck.
#' Erfordert die Umgebungsvariable `OPENAI_API_KEY`.
#'
#' @param df_scraped Ausgabe von [extract_scraped_organisations()] nachdem
#'   deterministische Matches bereits angewendet wurden.
#' @param df_gerit Ausgabe von [prepare_gerit_data()].
#' @param top_k Maximale Anzahl zurueckgegebener Kandidaten pro Organisation.
#' @param embedding_model OpenAI-Embedding-Modellkennung.
#' @param batch_size Anzahl der Texte pro Embedding-API-Anfrage.
#' @param gerit_embedding_cache_file Pfad zu einer `.rds`-Cache-Datei fuer
#'   GERIT-Embeddings. Bereits gespeicherte Embeddings werden wiederverwendet;
#'   fehlende Eintraege werden neu von der OpenAI-API abgerufen. Mit `NULL`
#'   wird kein Cache verwendet.
#'
#' @details
#' Der Rueckgabewert `score` ist die Kosinusaehnlichkeit zwischen dem
#' Embedding der gescrapten Organisation und dem Embedding der GERIT-
#' Einrichtung. Die Embeddings kommen aus der OpenAI-Embedding-API mit dem
#' in `embedding_model` gesetzten Modell.
#'
#' Wichtige Interpretation von `score`:
#' - Hoher Wert bedeutet: hohe semantische Aehnlichkeit der Texte.
#' - Niedriger Wert bedeutet: geringe semantische Aehnlichkeit.
#' - Der Wert ist eine Ranking-Groesse fuer die Kandidatenauswahl und
#'   keine kalibrierte Wahrscheinlichkeit fuer einen korrekten Match.
#' - Ein guter `score` allein reicht nicht als finale Match-Entscheidung;
#'   die finale Entscheidung trifft im naechsten Schritt das LLM.
#'
#' @return Ein Tibble gerankter GERIT-Kandidaten mit den Spalten
#'   `scraped_ID`, `organisation`, `cleaned`, `gerit_ID`, `Einrichtung`,
#'   `score`, `candidate_rank` und `candidate_source`. Gibt ein leeres
#'   Tibble zurueck, wenn alle Organisationen bereits gematcht sind.
#'
#' @export
generate_embedding_candidates <- function(
  df_scraped,
  df_gerit,
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  batch_size = 100,
  gerit_embedding_cache_file = file.path(
    "data",
    "cache",
    paste0("gerit_embeddings_", gsub("[^A-Za-z0-9_-]+", "_", embedding_model), ".rds")
  )
) {
  candidate_lookup <- df_gerit |>
    dplyr::filter(.data$unique_name_for_einrichtung == "ja") |>
    dplyr::mutate(
      embedding_text = purrr::map_chr(.data$Einrichtung, build_gerit_embedding_text)
    ) |>
    dplyr::select(
      "gerit_ID",
      "Einrichtung",
      "embedding_text"
    )

  query_lookup <- df_scraped |>
    dplyr::filter(.data$matched == "no") |>
    dplyr::mutate(
      embedding_text = purrr::map2_chr(.data$organisation, .data$cleaned, build_scraped_embedding_text)
    ) |>
    dplyr::select(
      "scraped_ID",
      "organisation",
      "cleaned",
      "embedding_text"
    )

  candidates <- generate_ranked_embedding_candidates(
    query_tbl = query_lookup,
    candidate_tbl = candidate_lookup,
    query_id_col = "scraped_ID",
    candidate_id_col = "gerit_ID",
    query_keep_cols = c("organisation", "cleaned"),
    candidate_keep_cols = "Einrichtung",
    top_k = top_k,
    embedding_model = embedding_model,
    batch_size = batch_size,
    query_label = "Scraping",
    candidate_label = "GERIT",
    ranking_label = "Kandidatenranking laeuft.",
    empty_message = "Keine offenen Organisationen mehr fuer Embedding-Retrieval.",
    start_message = paste0(
      "Embedding-Retrieval: ", nrow(query_lookup), " offene Organisationen, ",
      nrow(candidate_lookup), " GERIT-Einheiten, top_", top_k, "."
    ),
    candidate_source = "embedding",
    candidate_tiebreak_cols = "Einrichtung",
    candidate_embedding_cache_file = gerit_embedding_cache_file
  )

  message(
    "Embedding-Retrieval fertig: ", nrow(candidates), " Kandidaten fuer ",
    nrow(query_lookup), " Organisationen."
  )
  candidates
}
