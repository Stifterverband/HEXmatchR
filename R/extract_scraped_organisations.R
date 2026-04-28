
#' Eindeutige Organisationen aus gescrapten Daten extrahieren
#'
#' Dedupliziert die Organisationsspalte der gescrapten Kursdaten, zerlegt
#' semikolongetrennte Mehrfachorganisationseintraege in einzelne Zeilen,
#' erzeugt bereinigte Organisationsnamen und initialisiert alle
#' Match-Spalten mit Standardleerwerten.
#'
#' @param df_scraped Gescrapter Kursdaten-Data-Frame, z. B. aus
#'   `HEXCleanR::load_data_from_sp()`.
#' @param organisation_col Spalte mit den Organisationsnamen.
#' @param year_col Ungenutzt; nur aus Kompatibilitaetsgruenden vorhanden.
#' @param semester_col Ungenutzt; nur aus Kompatibilitaetsgruenden vorhanden.
#'
#' @return Ein Tibble eindeutiger Organisationen mit den Spalten
#'   `scraped_ID`, `organisation`, `organisation_names_for_matching_back`,
#'   `organisation_original`, `cleaned` sowie leeren Match-Spalten
#'   (initialisiert mit `"no"` bzw. `NA`).
#'
#' @export
extract_scraped_organisations <- function(
  df_scraped,
  organisation_col = "organisation",
  year_col = "jahr",
  semester_col = "semester"
) {
  df_scraped <- tibble::as_tibble(df_scraped)
  colnames(df_scraped) <- stringr::str_to_lower(colnames(df_scraped))
  organisation_col <- stringr::str_to_lower(organisation_col)

  if (!organisation_col %in% colnames(df_scraped)) {
    stop("The scraped data must contain an organisation column.", call. = FALSE)
  }

  names(df_scraped)[names(df_scraped) == organisation_col] <- "organisation"

  df_scraped <- df_scraped |>
    dplyr::mutate(
      organisation = as.character(.data$organisation)
    )

  exploded_orgs <- df_scraped |>
    dplyr::mutate(
      organisation_names_for_matching_back = as.character(.data$organisation),
      organisation = purrr::map(.data$organisation, split_orgs_or_na)
    ) |>
    tidyr::unnest_longer(.data$organisation, values_to = "organisation") |>
    dplyr::filter(!is.na(.data$organisation), .data$organisation != "")

  organisations <- exploded_orgs |>
    dplyr::group_by(.data$organisation) |>
    dplyr::summarise(
      organisation_names_for_matching_back = collapse_unique(.data$organisation_names_for_matching_back, sep = " || "),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      organisation_original = .data$organisation,
      cleaned = normalize_text(.data$organisation)
    )

  organisations <- organisations |>
    dplyr::bind_cols(empty_match_columns(nrow(organisations))) |>
    dplyr::mutate(scraped_ID = dplyr::row_number()) |>
    dplyr::relocate("scraped_ID")

  organisations
}
