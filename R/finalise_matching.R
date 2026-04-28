#' Matching-Durchlauf abschliessen
#'
#' Teilt die fertige Match-Tabelle in einen gematchten Anteil und einen
#' Review-Anteil auf, speichert die Matches in einer standardisierten
#' `.rds`-Datei und schreibt optional eine `.csv` mit Faellen, die noch
#' manuell ueberprueft werden muessen.
#'
#' @param df_scraped_matching_complete Gematchte Organisationstabelle,
#'   typischerweise das Element `organisation_matches` aus
#'   [match_scraped_organisations()].
#' @param who_matched Benutzername, der in den Ausgabedatei-Metadaten
#'   und im Dateinamen gespeichert wird.
#' @param output_dir Ausgabeverzeichnis fuer `.rds`- und Review-`.csv`-Datei.
#'   Wird rekursiv angelegt, falls nicht vorhanden.
#' @param matching_iteration Iterations-Tag im Dateinamen
#'   (z. B. `"erstkodierung"`, `"zweitkodierung"`).
#'
#' @return Eine Liste mit den Elementen:
#'   \describe{
#'     \item{`matched`}{Tibble der erfolgreich gematchten Organisationen.}
#'     \item{`review`}{Tibble der Review- oder ungeklaerten Faelle.}
#'     \item{`output_file`}{Pfad zur geschriebenen `.rds`-Datei.}
#'     \item{`review_file`}{Pfad zur Review-`.csv`, oder `NA_character_`
#'       wenn keine Review-Faelle vorliegen.}
#'   }
#'
#' @export
finalise_matching <- function(
  df_scraped_matching_complete,
  who_matched,
  output_dir = ".",
  matching_iteration = "erstkodierung"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  df_scraped_matching_complete <- tibble::as_tibble(df_scraped_matching_complete)

  if (!"organisation_names_for_matching_back" %in% names(df_scraped_matching_complete)) {
    fallback_names <- dplyr::coalesce(
      df_scraped_matching_complete$organisation_original %||% rep(NA_character_, nrow(df_scraped_matching_complete)),
      df_scraped_matching_complete$organisation %||% rep(NA_character_, nrow(df_scraped_matching_complete))
    )

    df_scraped_matching_complete <- df_scraped_matching_complete |>
      dplyr::mutate(
        organisation_names_for_matching_back = fallback_names
      )
  }

  matched_tbl <- df_scraped_matching_complete |>
    dplyr::filter(.data$matched == "yes") |>
    dplyr::mutate(
      who_matched = who_matched,
      when_matched = Sys.Date(),
      this_matching_is = matching_iteration,
      hochschule = NA_character_
    )

  review_tbl <- df_scraped_matching_complete |>
    dplyr::filter(.data$needs_review | .data$matched == "no") |>
    dplyr::select(
      .data$scraped_ID, .data$organisation_names_for_matching_back, .data$organisation,
      .data$match_type, .data$match_confidence, .data$match_reason, .data$needs_review
    )

  output_file <- file.path(
    output_dir,
    build_matching_filename(who_matched, Sys.Date(), matching_iteration)
  )

  saveRDS(matched_tbl, output_file)

  review_file <- NA_character_
  if (nrow(review_tbl) > 0) {
    review_file <- file.path(
      output_dir,
      paste0("matching_review_", who_matched, "_", Sys.Date(), ".csv")
    )
    readr::write_csv(review_tbl, review_file)
  }

  list(
    matched = matched_tbl,
    review = review_tbl,
    output_file = output_file,
    review_file = review_file
  )
}
