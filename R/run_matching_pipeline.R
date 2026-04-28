#' Matching-Pipeline von Anfang bis Ende ausführen
#'
#' Bereitet GERIT-Daten vor, führt die vollständige automatische
#' Matching-Pipeline ([match_scraped_organisations()]) aus und schließt die
#' Ausgabe ab, indem Matches und eine Review-CSV auf die Festplatte
#' geschrieben werden. Öffnet die interaktive Review-App nicht; für einen
#' vollständigen Durchlauf inklusive Shiny-Review-Schritt
#' [run_matching_workflow()] verwenden.
#'
#' @param name_gerit Hochschulname genau so, wie er in `HS` von
#'   `GERIT_DESTATIS_data.rds` vorkommt. Mit [find_names()] können alle
#'   verfügbaren Namen angezeigt werden.
#' @param df_scraped Gescrapter Kursdaten-Data-Frame.
#' @param organisation_col Spalte in den gescrapten Daten mit den
#'   Organisationsnamen.
#' @param year_col Spalte in den gescrapten Daten mit der Jahresangabe.
#' @param semester_col Spalte in den gescrapten Daten mit der
#'   Semesterangabe.
#' @param model OpenAI-Modell für `ellmer::chat_openai()`.
#' @param top_k Anzahl der GERIT-Kandidaten pro Organisation, die an das
#'   LLM übergeben werden.
#' @param embedding_model OpenAI-Embedding-Modell für den Kandidatenabruf.
#' @param embedding_batch_size Batch-Größe für Embedding-Anfragen.
#' @param review_confidence Unterer Schwellenwert, unterhalb dessen Matches
#'   zur Review weitergeleitet werden.
#' @param output_dir Ausgabeverzeichnis für die Ergebnisdateien.
#'
#' @return Eine Liste mit den Elementen `df_gerit`, `organisation_matches`,
#'   `df_scraped_matched`, `candidates`, `llm_decisions`, `matched`,
#'   `review`, `output_file` und `review_file`.
#'
#' @export
run_matching_pipeline <- function(
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
) {
  who_matched <- current_username()
  df_gerit <- prepare_gerit_data(name_gerit)
  df_scraped <- tibble::as_tibble(df_scraped)
  match_result <- match_scraped_organisations(
    df_scraped = df_scraped,
    df_gerit = df_gerit,
    organisation_col = organisation_col,
    year_col = year_col,
    semester_col = semester_col,
    model = model,
    top_k = top_k,
    embedding_model = embedding_model,
    embedding_batch_size = embedding_batch_size,
    review_confidence = review_confidence
  )

  finalised <- finalise_matching(
    df_scraped_matching_complete = match_result$organisation_matches,
    who_matched = who_matched,
    output_dir = output_dir,
    matching_iteration = "erstkodierung"
  )

  list(
    df_gerit = df_gerit,
    organisation_matches = match_result$organisation_matches,
    df_scraped_matched = match_result$df_scraped_matched,
    candidates = match_result$candidates,
    llm_decisions = match_result$llm_decisions,
    matched = finalised$matched,
    review = finalised$review,
    output_file = finalised$output_file,
    review_file = finalised$review_file
  )
}
