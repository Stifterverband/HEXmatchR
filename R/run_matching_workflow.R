
#' Matching, Review und Goldstandard-Evaluation in einem Aufruf
#'
#' Führt automatisches Matching, optionalen Shiny-Review und optional einen
#' Goldstandard-Vergleich in einem einzigen Aufruf durch und schreibt alle
#' Ausgabedateien auf die Festplatte.
#'
#' @param name_gerit Hochschulname in der Spalte `HS` von
#'   `GERIT_DESTATIS_data.rds`.
#' @param gold_data Ein Data Frame oder Pfad zu einer `.rds`-Datei mit
#'   manuellen Labels (optional).
#' @param df_scraped Gescrapter Kursdaten-Data-Frame. Dessen Spalte
#'   `organisation` wird gegen `Einrichtung` aus `GERIT_DESTATIS_data.rds`
#'   gematcht.
#' @param organisation_col Spalte in den gescrapten Daten mit den
#'   Organisationsnamen.
#' @param year_col Spalte in den gescrapten Daten mit der Jahresangabe.
#' @param semester_col Spalte in den gescrapten Daten mit der
#'   Semesterangabe.
#' @param model OpenAI-Modell für `ellmer::chat_openai()`.
#' @param top_k Anzahl der GERIT-Kandidaten, die an das LLM übergeben
#'   werden.
#' @param embedding_model OpenAI-Embedding-Modell für den Kandidatenabruf.
#' @param embedding_batch_size Batch-Größe für Embedding-Anfragen.
#' @param review_confidence Unterer Schwellenwert, unterhalb dessen Matches
#'   zur Review weitergeleitet werden.
#' @param auto_review Ob die Shiny-Review-App automatisch geöffnet werden
#'   soll, wenn ungeklärte oder markierte Fälle vorliegen.
#' @param output_dir Ausgabeverzeichnis für die Ergebnisdateien.
#' @param matching_iteration Iterations-Tag im Ausgabedateinamen.
#' @param include_debug Ob zusätzlich umfangreiche Zwischenergebnisse
#'   zurückgegeben werden sollen, z. B. GERIT-Daten, Kandidaten, rohe
#'   LLM-Entscheidungen und Vorher-/Nachher-Organisationstabellen.
#'
#' @details
#' Zur Einordnung von `score` und Match-Entscheidung:
#' - Die Embedding-Scores entstehen beim Kandidatenabruf und messen nur
#'   semantische Aehnlichkeit zwischen Organisationstexten.
#' - Diese Scores sind keine direkt kalibrierte Match-Wahrscheinlichkeit.
#' - Das finale Match (`select_candidate` oder `no_match`) entscheidet das
#'   LLM im Schritt [match_organisations_with_llm()].
#'
#' Unsicherheit wird ueber `review_confidence` operationalisiert: Faelle mit
#' zu niedriger (oder fehlender) Konfidenz werden fuer manuelle Review
#' markiert.
#'
#' @return Eine Liste mit sprechend benannten Hauptergebnissen:
#'   \describe{
#'     \item{`scraped_data_with_matching`}{Ursprüngliche gescrapte Daten mit
#'       zurückgefügten Match-Spalten. Dieses Objekt wird zusätzlich als
#'       `.rds` gespeichert, damit der wichtigste Arbeitsstand auch bei
#'       späteren Fehlern erhalten bleibt.}
#'     \item{`matched_organisations`}{Erfolgreich gematchte Organisationen.}
#'     \item{`review_cases`}{Offene oder unklare Fälle.}
#'     \item{`goldstandard_evaluation`}{Goldstandard-Vergleich oder `NULL`,
#'       wenn kein `gold_data` übergeben wurde.}
#'     \item{`scraped_output_file`}{Pfad zur geschriebenen
#'       `scraped_data_with_matching`-`.rds`.}
#'   }
#'   Wenn `include_debug = TRUE`, enthält die Liste zusätzlich das Element
#'   `debug` mit umfangreichen Zwischenergebnissen.
#'
#' @export
run_matching_workflow <- function(
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
) {
  who_matched <- current_username()
  df_scraped <- tibble::as_tibble(df_scraped)

  message("Bereite GERIT-Daten vor.")
  df_gerit <- prepare_gerit_data(name_gerit)
  message("GERIT geladen: ", nrow(df_gerit), " Einheiten fuer ", name_gerit, ".")

  message("Automatisches Matching startet: `organisation` wird gegen GERIT-`Einrichtung` gematcht.")
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

  n_review_cases <- match_result$organisation_matches |>
    dplyr::filter(.data$needs_review | .data$matched == "no") |>
    nrow()

  review_result <- NULL
  organisation_matches_reviewed <- match_result$organisation_matches

  if (auto_review && n_review_cases > 0) {
    message("Review erforderlich: ", n_review_cases, " Faelle. Oeffne Shiny-App.")
    review_result <- review_matches(
      organisation_matches = match_result$organisation_matches,
      candidates = match_result$candidates,
      df_gerit = df_gerit,
      reviewed_by = who_matched
    )
    organisation_matches_reviewed <- review_result$organisation_matches_reviewed
  } else if (n_review_cases > 0) {
    message("Review offen: ", n_review_cases, " Faelle, aber `auto_review = FALSE`.")
  } else {
    message("Kein Review erforderlich.")
  }

  df_scraped_matched_reviewed <- join_matches_back_to_scraped(
    df_scraped = df_scraped,
    organisation_matches = organisation_matches_reviewed,
    organisation_col = organisation_col
  )

  scraped_output_file <- file.path(
    output_dir,
    paste0(
      "scraped_data_with_matching_",
      who_matched,
      "_",
      Sys.Date(),
      "#",
      matching_iteration,
      ".rds"
    )
  )
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  saveRDS(df_scraped_matched_reviewed, scraped_output_file)
  message("Scraping-Daten mit Matching geschrieben: ", scraped_output_file)

  evaluation <- NULL
  if (!is.null(gold_data)) {
    message("Starte Goldstandard-Vergleich.")
    evaluation <- evaluate_against_goldstandard(
      organisation_matches = organisation_matches_reviewed,
      gold_data = gold_data
    )
    message(
      "Goldstandard: Match-Rate ",
      round(evaluation$metrics$value[evaluation$metrics$metric == "match_rate"], 3),
      ", LUF ",
      round(evaluation$metrics$value[evaluation$metrics$metric == "luf_accuracy"], 3),
      "."
    )

    mismatches <- check_mismatches(evaluation)

    if (nrow(mismatches) > 0) {
      message("Goldstandard: Nicht passende Faelle (erste 10):")
      print(mismatches, n = min(10, nrow(mismatches)))
    }
  }

  matched_organisations <- organisation_matches_reviewed |>
    dplyr::filter(.data$matched == "yes") |>
    dplyr::mutate(
      who_matched = who_matched,
      when_matched = Sys.Date(),
      this_matching_is = matching_iteration,
      hochschule = NA_character_
    )

  review_cases <- organisation_matches_reviewed |>
    dplyr::filter(.data$needs_review | .data$matched == "no") |>
    dplyr::select(
      .data$scraped_ID, .data$organisation_names_for_matching_back, .data$organisation,
      .data$match_type, .data$match_confidence, .data$match_reason, .data$needs_review
    )

  workflow_output <- list(
    scraped_data_with_matching = df_scraped_matched_reviewed,
    matched_organisations = matched_organisations,
    review_cases = review_cases,
    goldstandard_evaluation = evaluation,
    scraped_output_file = scraped_output_file
  )

  if (isTRUE(include_debug)) {
    workflow_output$debug <- list(
      gerit_data = df_gerit,
      input_scraped_data = df_scraped,
      automatic_matching_result = match_result,
      review_result = review_result,
      organisation_matches_before_review = match_result$organisation_matches,
      organisation_matches_after_review = organisation_matches_reviewed,
      embedding_candidates = match_result$candidates,
      llm_decisions = match_result$llm_decisions
    )
  }

  workflow_output
}
