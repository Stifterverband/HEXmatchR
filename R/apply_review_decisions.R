
#' Review-Ergebnisse in die Match-Tabelle zurückschreiben
#'
#' Diese Funktion übernimmt die Entscheidungen aus dem manuellen Review und
#' aktualisiert damit die passenden Zeilen in `organisation_matches`.
#'
#' Für jede `scraped_ID` wird die gewählte Entscheidung angewendet:
#' - `"accept_model_match"`: den bisherigen Match bestätigen
#' - `"select_other_candidate"`: einen anderen GERIT-Kandidaten übernehmen
#' - `"mark_no_match"`: festhalten, dass es keinen passenden GERIT-Eintrag gibt
#'
#' Entscheidungen mit `NA` oder `"skip"` werden ignoriert. Alle anderen Zeilen
#' in `organisation_matches` bleiben unverändert.
#'
#' @param organisation_matches Eine Tabelle mit Organisations-Matches, zum
#'   Beispiel `llm_result$scraped` aus [match_scraped_organisations()].
#'   Sie muss eine Spalte `scraped_ID` enthalten.
#' @param review_decisions Eine Tabelle mit den manuellen Review-Entscheidungen,
#'   zum Beispiel `run_review_app(...)$decisions`. Erwartet werden mindestens
#'   die Spalten `scraped_ID` und `review_decision`. Je nach Entscheidung werden
#'   außerdem `selected_gerit_id` und `review_comment` verwendet.
#' @param df_gerit Die vorbereiteten GERIT-Daten aus [prepare_gerit_data()].
#'   Diese werden nur gebraucht, wenn im Review ein alternativer Kandidat
#'   ausgewählt wurde.
#'
#' @return `organisation_matches` mit aktualisierten Match-Spalten für alle
#'   bearbeiteten Review-Fälle.
#'
#' @export
apply_review_decisions <- function(organisation_matches, review_decisions, df_gerit) {
  # Baut einen gut lesbaren match_reason aus Standardtext und optionalem Kommentar.
  format_review_reason <- function(prefix, comment) {
    trimws(paste(prefix, comment %||% ""))
  }

  # Übersetzt eine einzelne Review-Entscheidung in einen vollständigen
  # Match-Datensatz, der später in die Zieltabelle geschrieben wird.
  build_review_record <- function(current_match, decision_row, df_gerit) {
    switch(
      decision_row$review_decision[[1]],
      accept_model_match = list(
        gerit_ID = current_match$gerit_ID[[1]],
        gerit_organisation = current_match$gerit_organisation[[1]],
        gerit_cleaned = current_match$gerit_cleaned[[1]] %||% NA_character_,
        Fachgebiet_Gerit_1 = current_match$Fachgebiet_Gerit_1[[1]] %||% NA_character_,
        Fachgebiet_Gerit_2 = current_match$Fachgebiet_Gerit_2[[1]] %||% NA_character_,
        Fachgebiet_Gerit_3 = current_match$Fachgebiet_Gerit_3[[1]] %||% NA_character_,
        Fachgebiet_Gerit_4 = current_match$Fachgebiet_Gerit_4[[1]] %||% NA_character_,
        Fachgebiet_Gerit_5 = current_match$Fachgebiet_Gerit_5[[1]] %||% NA_character_,
        Fachgebiet_Gerit_6 = current_match$Fachgebiet_Gerit_6[[1]] %||% NA_character_,
        Faechergruppen = current_match$Faechergruppen[[1]] %||% NA_character_,
        Faechergruppen_IDs = current_match$Faechergruppen_IDs[[1]] %||% NA_character_,
        LUF_IDs = current_match$LUF_IDs[[1]] %||% NA_character_,
        LUF_Namen = current_match$LUF_Namen[[1]] %||% NA_character_,
        matched = "yes",
        match_type = "review_confirmed",
        match_confidence = current_match$match_confidence[[1]],
        match_reason = format_review_reason("Review confirmed.", decision_row$review_comment[[1]]),
        needs_review = FALSE
      ),
      select_other_candidate = lookup_match_from_gerit(
        df_gerit = df_gerit,
        gerit_id = decision_row$selected_gerit_id[[1]],
        match_type = "review_candidate",
        confidence = 1,
        reason = format_review_reason("Review selected alternative candidate.", decision_row$review_comment[[1]]),
        needs_review = FALSE
      ),
      mark_no_match = not_match_record(
        reason = format_review_reason("Review marked as no match.", decision_row$review_comment[[1]]),
        needs_review = FALSE
      ),
      NULL
    )
  }

  # Sorgt dafür, dass wir mit Tibbles arbeiten und die folgenden Schritte
  # konsistent mit dplyr/purrr funktionieren.
  organisation_matches <- tibble::as_tibble(organisation_matches)
  review_decisions <- tibble::as_tibble(review_decisions)

  # Prüft, ob die Review-Tabelle die Pflichtspalten enthält, die wir zum
  # Zuordnen und Ausführen der Entscheidungen brauchen.
  required_review_columns <- c("scraped_ID", "review_decision")
  missing_review_columns <- setdiff(required_review_columns, names(review_decisions))

  if (length(missing_review_columns) > 0) {
    stop(
      "`review_decisions` is missing required column(s): ",
      paste(missing_review_columns, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  if (!"scraped_ID" %in% names(organisation_matches)) {
    stop("`organisation_matches` must contain a `scraped_ID` column.", call. = FALSE)
  }

  # Behält nur echte Entscheidungen und merkt sich für jede `scraped_ID`,
  # welche Zeile in `organisation_matches` aktualisiert werden muss.
  decisions_to_apply <- review_decisions |>
    dplyr::filter(!is.na(.data$review_decision), .data$review_decision != "skip") |>
    dplyr::mutate(row_id = match(.data$scraped_ID, organisation_matches$scraped_ID))

  # Bricht mit einer klaren Fehlermeldung ab, falls Entscheidungen für
  # `scraped_ID`s vorliegen, die in der Match-Tabelle gar nicht existieren.
  unknown_scraped_ids <- decisions_to_apply |>
    dplyr::filter(is.na(.data$row_id)) |>
    dplyr::pull(.data$scraped_ID) |>
    unique()

  if (length(unknown_scraped_ids) > 0) {
    stop(
      "Some `scraped_ID`s from `review_decisions` were not found in `organisation_matches`: ",
      paste(unknown_scraped_ids, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  # Läuft Entscheidung für Entscheidung durch, baut jeweils den neuen
  # Match-Datensatz und schreibt ihn in die passende Zeile zurück.
  purrr::reduce(
    split(decisions_to_apply, seq_len(nrow(decisions_to_apply))),
    .init = organisation_matches,
    .f = function(matches_tbl, decision_row) {
      # Holt den aktuellen Stand der betroffenen Match-Zeile, damit z. B.
      # beim Bestätigen bestehende Werte übernommen werden können.
      current_match <- matches_tbl[decision_row$row_id[[1]], , drop = FALSE]
      record <- build_review_record(
        current_match = current_match,
        decision_row = decision_row,
        df_gerit = df_gerit
      )

      # Unbekannte oder nicht unterstützte Entscheidungen ändern nichts.
      if (is.null(record)) {
        return(matches_tbl)
      }

      # Schreibt den neuen Match-Datensatz in die richtige Zeile zurück.
      apply_match_record(matches_tbl, decision_row$row_id[[1]], record)
    }
  )
}
