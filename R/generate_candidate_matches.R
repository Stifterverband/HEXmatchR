#' Gerankte GERIT-Kandidaten für gescrapte Organisationen erzeugen
#'
#' Komfortfunktion um [generate_embedding_candidates()], die für jede noch
#' nicht gematche Organisation die top-`k` ähnlichsten GERIT-Einträge
#' via OpenAI-Text-Embeddings ermittelt.
#'
#' @param df_scraped Ausgabe von [extract_scraped_organisations()].
#' @param df_gerit Ausgabe von [prepare_gerit_data()].
#' @param top_k Maximale Anzahl zurückgegebener Kandidaten pro Organisation.
#' @param embedding_model OpenAI-Embedding-Modellkennung.
#' @param batch_size Anzahl der Texte pro Embedding-API-Anfrage.
#'
#' @return Ein Tibble gerankter GERIT-Kandidaten mit je einer Zeile pro
#'   Kombination (gescrapte Organisation × Kandidat). Die vollständige
#'   Spaltenliste ist bei [generate_embedding_candidates()] beschrieben.
#'
#' @export
generate_candidate_matches <- function(
  df_scraped,
  df_gerit,
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  batch_size = 100
) {
  generate_embedding_candidates(
    df_scraped = df_scraped,
    df_gerit = df_gerit,
    top_k = top_k,
    embedding_model = embedding_model,
    batch_size = batch_size
  )
}
