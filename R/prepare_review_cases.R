#' Review-Fälle für die Shiny-Review-App vorbereiten
#'
#' Filtert die Organisations-Match-Tabelle auf Fälle, die manuell überprüft
#' werden müssen, ergänzt die zugehörigen Kandidaten um lesbare Labels und
#' initialisiert eine leere Entscheidungstabelle, die der Reviewer ausfüllen
#' kann.
#'
#' @param organisation_matches Organisationsebene-Matches, typischerweise
#'   aus [match_scraped_organisations()].
#' @param candidates Kandidaten-Tabelle aus [generate_embedding_candidates()].
#' @param review_filter Optionaler logischer Vektor zum Filtern von
#'   `organisation_matches`. Standard: `needs_review | matched == "no"`.
#'
#' @return Eine Liste mit den Elementen:
#'   \describe{
#'     \item{`review_cases`}{Gefiltertes Tibble der zu prüfenden
#'       Organisationen.}
#'     \item{`candidate_choices`}{Kandidaten-Tibble mit zusätzlicher
#'       `candidate_label`-Spalte für die App-Anzeige.}
#'     \item{`decisions`}{Vorinitialisiertes Entscheidungs-Tibble mit je
#'       einer Zeile pro Review-Fall und allen Entscheidungsspalten auf
#'       `NA` gesetzt.}
#'   }
#'
#' @export
prepare_review_cases <- function(
  organisation_matches,
  candidates,
  review_filter = NULL
) {
  organisation_matches <- tibble::as_tibble(organisation_matches)
  candidates <- tibble::as_tibble(candidates)

  if (is.null(review_filter)) {
    review_cases <- organisation_matches |>
      dplyr::filter(.data$needs_review | .data$matched == "no")
  } else {
    review_cases <- organisation_matches[review_filter, , drop = FALSE] |>
      tibble::as_tibble()
  }

  candidate_choices <- candidates |>
    dplyr::filter(.data$scraped_ID %in% review_cases$scraped_ID) |>
    dplyr::arrange(.data$scraped_ID, .data$candidate_rank) |>
    dplyr::mutate(
      candidate_label = paste0(
        "#", .data$candidate_rank, " | ",
        .data$Einrichtung, " | score=",
        format(round(.data$score, 3), nsmall = 3)
      )
    )

  decisions <- review_cases |>
    dplyr::transmute(
      scraped_ID = .data$scraped_ID,
      organisation = .data$organisation,
      review_decision = NA_character_,
      selected_gerit_id = NA_integer_,
      review_comment = NA_character_,
      reviewed_at = as.POSIXct(NA),
      reviewed_by = NA_character_
    )

  list(
    review_cases = review_cases,
    candidate_choices = candidate_choices,
    decisions = decisions
  )
}
