
#' Organisationsmatches in einer Shiny-App reviewen
#'
#' Bereitet die Review-Fälle vor, startet die interaktive Shiny-App
#' ([run_review_app()]) und wendet die erfassten Entscheidungen auf die
#' Matches an.
#'
#' @param organisation_matches Organisationsebene-Matches, typischerweise
#'   aus [match_scraped_organisations()] oder `llm_result$scraped`.
#' @param candidates Kandidaten-Tabelle aus [generate_embedding_candidates()]
#'   oder `result$candidates`.
#' @param df_gerit Vorbereitete GERIT-Daten aus [prepare_gerit_data()].
#' @param review_filter Optionaler logischer Filter. Standard:
#'   `needs_review | matched == "no"`.
#' @param reviewed_by Optionaler Reviewer-Name, der bei jeder Entscheidung
#'   gespeichert wird.
#'
#' @return Eine Liste mit den Elementen `review_cases`, `review_result`,
#'   `review_decisions` und `organisation_matches_reviewed`.
#'
#' @export
review_matches <- function(
  organisation_matches,
  candidates,
  df_gerit,
  review_filter = NULL,
  reviewed_by = current_username()
) {
  review_cases <- prepare_review_cases(
    organisation_matches = organisation_matches,
    candidates = candidates,
    review_filter = review_filter
  )

  message("Starte Review-App fuer ", nrow(review_cases$review_cases), " Faelle.")
  review_result <- run_review_app(
    review_cases = review_cases,
    df_gerit = df_gerit,
    reviewed_by = reviewed_by
  )

  reviewed_matches <- apply_review_decisions(
    organisation_matches = organisation_matches,
    review_decisions = review_result$decisions,
    df_gerit = df_gerit
  )

  list(
    review_cases = review_cases,
    review_result = review_result,
    review_decisions = review_result$decisions,
    organisation_matches_reviewed = reviewed_matches
  )
}
