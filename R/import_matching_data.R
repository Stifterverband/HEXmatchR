#' Matching-Daten in gescrapte Kursdaten zurückführen
#'
#' Liest die von [finalise_matching()] erzeugte Matching-Ausgabe und
#' fügt die zentralen Matching-Spalten (`matchingart`, `gerit_id`,
#' `einrichtung`) über den Organisationsnamen in die ursprünglichen
#' gescrapten Kursdaten ein.
#'
#' @param add_to_this_file Ein Data Frame oder Pfad zu einer gescrapten
#'   `.rds`-Datei, in die die Matching-Daten eingespielt werden sollen.
#' @param matching_file Pfad zur Matching-`.rds`-Datei, die von
#'   [finalise_matching()] erstellt wurde.
#'
#' @return `add_to_this_file` als Tibble mit den eingejoinssten
#'   Matching-Spalten.
#'
#' @export
import_matching_data <- function(add_to_this_file, matching_file) {
  df_add <- if (is.character(add_to_this_file) && length(add_to_this_file) == 1 && file.exists(add_to_this_file)) {
    tibble::as_tibble(readRDS(add_to_this_file))
  } else {
    tibble::as_tibble(add_to_this_file)
  }

  if (!file.exists(matching_file)) {
    stop("`matching_file` does not exist.", call. = FALSE)
  }

  df_matching <- tibble::as_tibble(readRDS(matching_file)) |>
    dplyr::transmute(
      organisation_key = stringr::str_squish(as.character(.data$organisation_names_for_matching_back)),
      matchingart = .data$match_type,
      gerit_id = .data$gerit_ID,
      einrichtung = .data$gerit_organisation
    ) |>
    dplyr::distinct(.data$organisation_key, .keep_all = TRUE)

  if ("organisation_mehrere" %in% colnames(df_add)) {
    df_add <- df_add |>
      dplyr::mutate(
        organisation = dplyr::if_else(
          .data$organisation == "MEHRERE ORGANISATIONEN",
          as.character(.data$organisation_mehrere),
          as.character(.data$organisation)
        )
      )
  }

  df_add |>
    dplyr::mutate(organisation_key = stringr::str_squish(as.character(.data$organisation))) |>
    dplyr::left_join(df_matching, by = "organisation_key") |>
    dplyr::select(-"organisation_key")
}
