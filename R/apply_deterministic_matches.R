
#' Deterministische namensbasierte Zuordnung
#'
#' Versucht, noch nicht gematchte Organisationen durch direkten Namensvergleich
#' (Rohname und bereinigter Name) mit GERIT-Eintraegen zu matchen. Nur
#' wirklich eindeutige Treffer werden automatisch uebernommen.
#'
#' @param df_scraped Ausgabe von [extract_scraped_organisations()].
#' @param candidate_tbl Fuer zukuenftige Nutzung reserviert; `NULL` uebergeben.
#' @param df_gerit Vorbereitete GERIT-Daten aus [prepare_gerit_data()].
#'
#' @return Das aktualisierte `df_scraped`-Tibble mit eingetragenen
#'   deterministischen Treffern in den Match-Spalten.
#'
#' @noRd
apply_deterministic_matches <- function(df_scraped, candidate_tbl, df_gerit) {
  gerit_lookup <- df_gerit |>
    dplyr::select(
      "gerit_ID",
      "Einrichtung",
      "gerit_cleaned",
      dplyr::any_of(paste0("Fachgebiet_Gerit_", 1:6)),
      "Faechergruppen",
      dplyr::any_of("Faechergruppen_IDs"),
      "LUF_IDs",
      dplyr::any_of("LUF_Namen")
    )

  direct_lookup <- gerit_lookup |>
    dplyr::add_count(.data$Einrichtung, name = "n_direct_matches") |>
    dplyr::filter(.data$n_direct_matches == 1L) |>
    dplyr::select(-"n_direct_matches")

  cleaned_lookup <- gerit_lookup |>
    dplyr::filter(!is.na(.data$gerit_cleaned), .data$gerit_cleaned != "") |>
    dplyr::add_count(.data$gerit_cleaned, name = "n_cleaned_matches") |>
    dplyr::filter(.data$n_cleaned_matches == 1L) |>
    dplyr::select(-"n_cleaned_matches")

  unmatched <- df_scraped |>
    dplyr::filter(.data$matched == "no") |>
    dplyr::select("scraped_ID", "organisation", "cleaned")

  direct <- unmatched |>
    dplyr::inner_join(direct_lookup, by = c("organisation" = "Einrichtung")) |>
    dplyr::transmute(.data$scraped_ID, .data$gerit_ID, match_type = "direct")

  cleaned <- unmatched |>
    dplyr::anti_join(direct, by = "scraped_ID") |>
    dplyr::inner_join(cleaned_lookup, by = c("cleaned" = "gerit_cleaned")) |>
    dplyr::transmute(.data$scraped_ID, .data$gerit_ID, match_type = "cleaned")

  all_matches <- dplyr::bind_rows(direct, cleaned) |>
    dplyr::distinct(.data$scraped_ID, .keep_all = TRUE) |>
    dplyr::inner_join(
      gerit_lookup |>
        dplyr::distinct(.data$gerit_ID, .keep_all = TRUE),
      by = "gerit_ID"
    ) |>
    dplyr::transmute(
      .data$scraped_ID,
      .data$gerit_ID,
      gerit_organisation = .data$Einrichtung,
      gerit_cleaned = .data$gerit_cleaned,
      Fachgebiet_Gerit_1 = .data$Fachgebiet_Gerit_1,
      Fachgebiet_Gerit_2 = .data$Fachgebiet_Gerit_2,
      Fachgebiet_Gerit_3 = .data$Fachgebiet_Gerit_3,
      Fachgebiet_Gerit_4 = .data$Fachgebiet_Gerit_4,
      Fachgebiet_Gerit_5 = .data$Fachgebiet_Gerit_5,
      Fachgebiet_Gerit_6 = .data$Fachgebiet_Gerit_6,
      Faechergruppen = .data$Faechergruppen,
      Faechergruppen_IDs = .data$Faechergruppen_IDs,
      LUF_IDs = .data$LUF_IDs,
      LUF_Namen = .data$LUF_Namen,
      matched = "yes",
      .data$match_type,
      match_confidence = 1,
      match_reason = paste0("Deterministic ", .data$match_type, " match."),
      needs_review = FALSE
    )

  if (nrow(all_matches) == 0) {
    message("Exakte Matches: 0 automatische Treffer.")
    return(df_scraped)
  }

  direct_n <- sum(all_matches$match_type == "direct")
  cleaned_n <- sum(all_matches$match_type == "cleaned")
  message(
    "Exakte Matches: ", nrow(all_matches), " Treffer (",
    direct_n, " direkt, ", cleaned_n, " cleaned)."
  )

  dplyr::rows_update(df_scraped, all_matches, by = "scraped_ID", unmatched = "ignore")
}
