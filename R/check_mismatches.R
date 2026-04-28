#' Falsch gematchte Goldstandard-Fälle anzeigen
#'
#' Filtert die Goldstandard-Evaluation auf Fälle mit vorhandenem Goldstandard-
#' LUF, bei denen die vorhergesagten LUFs nicht korrekt sind, und gibt nur die
#' für die Prüfung relevanten GERIT-Spalten zurück.
#'
#' @param x Entweder das Ergebnis von [run_matching_workflow()], die Liste
#'   `workflow_result$goldstandard_evaluation` oder direkt deren
#'   `comparison`-Tabelle.
#'
#' @return Ein Tibble mit den Spalten `Scraping_Orga`, `Gerit_Orga`,
#'   `Matchingart`, `Fachgebiet_Gerit_1` bis `Fachgebiet_Gerit_6`,
#'   `LUF_IDs_Gerit`, `LUF_Namen_Gerit`,
#'   `Faechergruppen_IDs_Gerit` und `Faechergruppen_Gerit`.
#'   Die Goldstandard-Spalten stehen gesammelt am Ende.
#'
#' @export
check_mismatches <- function(x) {
  comparison <- if (is.data.frame(x)) {
    x
  } else if (is.list(x) && !is.null(x$comparison)) {
    x$comparison
  } else if (is.list(x) && !is.null(x$goldstandard_evaluation$comparison)) {
    x$goldstandard_evaluation$comparison
  } else {
    stop(
      "`x` must be a workflow result, a goldstandard evaluation, or a comparison table.",
      call. = FALSE
    )
  }

  comparison <- tibble::as_tibble(comparison)

  required_cols <- c("organisation", "gerit_organisation", "match_type", "has_gold_luf", "luf_correct")
  missing_cols <- setdiff(required_cols, names(comparison))
  if (length(missing_cols) > 0) {
    stop(
      "`comparison` is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  visible_cols <- c(
    paste0("Fachgebiet_Gerit_", 1:6),
    "LUF_IDs",
    "LUF_Namen",
    "gold_luf",
    "gold_luf_name",
    "gold_stub_code",
    "gold_studienbereich",
    "gold_fg_code",
    "Faechergruppen_IDs",
    "Faechergruppen"
  )
  for (visible_col in setdiff(visible_cols, names(comparison))) {
    comparison[[visible_col]] <- NA_character_
  }

  if (all(is.na(comparison$Faechergruppen)) && "fachgruppe_gerit_orga" %in% names(comparison)) {
    comparison$Faechergruppen <- comparison$fachgruppe_gerit_orga
  }

  comparison |>
    dplyr::filter(.data$has_gold_luf, !.data$luf_correct) |>
    dplyr::transmute(
      Scraping_Orga = .data$organisation,
      Matchingart = dplyr::case_when(
        .data$match_type %in% c("review_confirmed", "review_candidate") ~ "Manual",
        .data$match_type == "llm" ~ "KI",
        .data$match_type %in% c("direct", "cleaned") ~ "Deterministisch",
        TRUE ~ .data$match_type
      ),
      Gerit_Orga = .data$gerit_organisation,
      Fachgebiet_Gerit_1 = .data$Fachgebiet_Gerit_1,
      Fachgebiet_Gerit_2 = .data$Fachgebiet_Gerit_2,
      Fachgebiet_Gerit_3 = .data$Fachgebiet_Gerit_3,
      Fachgebiet_Gerit_4 = .data$Fachgebiet_Gerit_4,
      Fachgebiet_Gerit_5 = .data$Fachgebiet_Gerit_5,
      Fachgebiet_Gerit_6 = .data$Fachgebiet_Gerit_6,
      LUF_IDs_Gerit = .data$LUF_IDs,
      LUF_Namen_Gerit = .data$LUF_Namen,
      Faechergruppen_IDs_Gerit = .data$Faechergruppen_IDs,
      Faechergruppen_Gerit = .data$Faechergruppen,
      Gold_LUF_IDs = .data$gold_luf,
      Gold_LUF_Namen = .data$gold_luf_name,
      Gold_STUB_IDs = .data$gold_stub_code,
      Gold_Studienbereiche = .data$gold_studienbereich,
      Gold_Faechergruppen_IDs = .data$gold_fg_code
    )
}
