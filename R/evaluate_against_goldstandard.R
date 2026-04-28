#' Matching-Ergebnisse mit einem Goldstandard vergleichen
#'
#' Diese Funktion prüft, ob die im Matching vorhergesagten `LUF_IDs`
#' aus den gematchten GERIT-Einrichtungen mit dem Goldstandard aus
#' `gold_data$luf_code` übereinstimmen.
#'
#' Dafür werden die gematchten GERIT-Einrichtungen über `organisation`
#' mit dem Goldstandard verknüpft und drei Ergebnisse zurückgegeben:
#' - eine Vergleichstabelle auf Zeilenebene
#' - einige Gesamtmetriken
#' - eine Auswertung nach `matchingart` aus dem Goldstandard
#'
#' Die zurückgegebenen Gesamtmetriken sind:
#' - `n_organisations`: Anzahl der Organisationen in `organisation_matches`
#' - `n_with_gold_luf`: Anzahl der Organisationen, für die im Goldstandard ein
#'   `luf_code` vorliegt
#' - `match_rate`: Anteil der Organisationen mit `matched == "yes"`
#' - `review_rate`: Anteil der Organisationen mit `needs_review == TRUE`
#' - `luf_accuracy`: Anteil der Organisationen, bei denen die
#'   vorhergesagten `LUF_IDs` exakt mit dem Goldstandard-Wert in
#'   `luf_code` übereinstimmen. Die Reihenfolge der Codes wird dabei
#'   ignoriert, sodass z. B. `231|771` und `771|231` als identisch gelten.
#'   Diese Metrik wird nur für
#'   Organisationen berechnet, für die im Goldstandard überhaupt ein
#'   Vergleichswert vorliegt.
#'
#' @param organisation_matches Eine Match-Tabelle auf Ebene der gescrapten
#'   `organisation`, zum Beispiel die Ausgabe von
#'   [match_scraped_organisations()]. Erwartet werden die aus GERIT
#'   übernommenen Spalten `gerit_organisation`, `Faechergruppen` und
#'   `LUF_IDs`.
#' @param gold_data Ein Data Frame oder ein Pfad zu einer `.rds`-Datei mit den
#'   manuellen Referenzdaten. Erwartet werden eine Organisationsspalte,
#'   `matchingart`, `luf_code` und `faechergruppe`.
#'   Groß-/Kleinschreibung der Spaltennamen ist egal.
#' @param organisation_col Name der Organisationsspalte in `gold_data`.
#'
#' @return Eine Liste mit drei Elementen:
#'   \describe{
#'     \item{`comparison`}{Vergleichstabelle mit Vorhersage, Goldstandard und
#'       Korrektheitsindikatoren pro Organisation.}
#'     \item{`metrics`}{Tibble mit den wichtigsten Gesamtmetriken. Enthält die
#'       Spalten `metric` und `value`. `value` ist jeweils wie folgt berechnet:
#'       `n_organisations = nrow(comparison)`;
#'       `n_with_gold_luf = sum(has_gold_luf)`;
#'       `match_rate = mean(matched == "yes")`;
#'       `review_rate = mean(needs_review)`;
#'       `luf_accuracy = mean(luf_correct[has_gold_luf])`.}
#'     \item{`by_gold_matchingart`}{Zusammenfassung der Metriken getrennt nach
#'       `matchingart` aus dem Goldstandard. Für jede Gruppe werden `n`,
#'       `match_rate`, `review_rate` und `luf_accuracy` mit derselben
#'       Logik wie oben innerhalb der jeweiligen Teilmenge berechnet.}
#'   }
#'
#' @export
evaluate_against_goldstandard <- function(
  organisation_matches,
  gold_data,
  organisation_col = "organisation"
) {
  safe_mean <- function(x) {
    if (length(x) == 0) {
      return(NA_real_)
    }
    mean(x, na.rm = TRUE)
  }

  normalize_luf_code <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""

    purrr::map_chr(x, function(value) {
      parts <- stringr::str_split(value, "\\|", simplify = FALSE)[[1]]
      parts <- stringr::str_trim(parts)
      parts <- parts[parts != ""]
      parts <- unique(parts)

      if (length(parts) == 0) {
        return(NA_character_)
      }

      parts <- sort(parts)
      paste(parts, collapse = "|")
    })
  }

  # Liest die Goldstandard-Daten entweder direkt aus einem Data Frame oder
  # aus einer `.rds`-Datei ein und wandelt sie in ein Tibble um.
  gold_df <- if (is.character(gold_data) && length(gold_data) == 1) {
    if (!file.exists(gold_data)) {
      stop(
        "`gold_data` wurde als Pfad angegeben, aber die Datei existiert nicht: ",
        gold_data,
        ".",
        call. = FALSE
      )
    }

    tibble::as_tibble(readRDS(gold_data))
  } else {
    tibble::as_tibble(gold_data)
  }

  # Vereinheitlicht die Spaltennamen auf Kleinbuchstaben, damit unterschiedliche
  # Schreibweisen in den Eingabedaten leichter abgefangen werden.
  colnames(gold_df) <- stringr::str_to_lower(colnames(gold_df))
  organisation_col <- stringr::str_to_lower(organisation_col)

  # Prüft, ob die nötigen Spalten im Goldstandard vorhanden sind.
  required_gold_columns <- c(
    organisation_col,
    "matchingart",
    "lehr_und_forschungsbereich",
    "studienbereich",
    "faechergruppe",
    "luf_code",
    "stub_code",
    "fg_code"
  )
  missing_gold_columns <- setdiff(required_gold_columns, names(gold_df))

  if (length(missing_gold_columns) > 0) {
    stop(
      "`gold_data` is missing required column(s): ",
      paste(missing_gold_columns, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  # Benennt die Organisationsspalte einheitlich in `organisation` um, damit
  # der Join später unabhängig vom ursprünglichen Spaltennamen funktioniert.
  names(gold_df)[names(gold_df) == organisation_col] <- "organisation"
  organisation_matches <- tibble::as_tibble(organisation_matches)

  gold_df <- gold_df |>
    dplyr::mutate(
      gold_luf_name_source = as.character(.data$lehr_und_forschungsbereich)
    )

  if (!"LUF_IDs" %in% names(organisation_matches)) {
    stop("`organisation_matches` must contain a `LUF_IDs` column.", call. = FALSE)
  }

  # Verdichtet den Goldstandard auf eine Zeile pro Organisation und sammelt
  # die Referenzwerte, gegen die später verglichen wird.
  gold_orgs <- gold_df |>
    dplyr::filter(!is.na(.data$organisation), .data$organisation != "") |>
    dplyr::group_by(.data$organisation) |>
    dplyr::summarise(
      gold_matchingart = collapse_unique(.data$matchingart),
      gold_faechergruppe = collapse_unique(.data$faechergruppe),
      gold_luf = normalize_luf_code(collapse_unique(.data$luf_code, sep = "|")),
      gold_luf_name = collapse_unique(.data$gold_luf_name_source, sep = "; "),
      gold_stub_code = collapse_unique(.data$stub_code, sep = "|"),
      gold_studienbereich = collapse_unique(.data$studienbereich, sep = "; "),
      gold_fg_code = collapse_unique(.data$fg_code, sep = "|"),
      .groups = "drop"
    )

  # Verknüpft die gematchte GERIT-Einrichtung über die gescrapte Organisation
  # mit dem Goldstandard und ergänzt die zugehörigen Fachgruppen.
  comparison <- organisation_matches |>
    dplyr::select(
      "organisation",
      "matched",
      "match_type",
      "gerit_organisation",
      dplyr::any_of(paste0("Fachgebiet_Gerit_", 1:6)),
      "Faechergruppen",
      dplyr::any_of("Faechergruppen_IDs"),
      dplyr::any_of("gerit_cleaned"),
      "LUF_IDs",
      dplyr::any_of("LUF_Namen"),
      "needs_review"
    ) |>
    dplyr::left_join(gold_orgs, by = "organisation") |>
    dplyr::rename(
      fachgruppe_scrape_orga = "gold_faechergruppe",
      fachgruppe_gerit_orga = "Faechergruppen"
    ) |>
    dplyr::mutate(
      predicted_luf = normalize_luf_code(.data$LUF_IDs),
      has_gold_luf = !is.na(.data$gold_luf) & .data$gold_luf != "",
      luf_correct = .data$predicted_luf == .data$gold_luf
    )

  # Fasst die wichtigsten Kennzahlen über alle Organisationen hinweg zusammen.
  metrics <- tibble::tibble(
    metric = c(
      "n_organisations",
      "n_with_gold_luf",
      "match_rate",
      "review_rate",
      "luf_accuracy"
    ),
    value = c(
      nrow(comparison),
      sum(comparison$has_gold_luf, na.rm = TRUE),
      mean(comparison$matched == "yes", na.rm = TRUE),
      mean(comparison$needs_review, na.rm = TRUE),
      safe_mean(comparison$luf_correct[comparison$has_gold_luf])
    )
  )

  # Berechnet dieselben Kennzahlen getrennt nach Matchingart im Goldstandard,
  # damit sichtbar wird, bei welchen Falltypen das Matching besser oder
  # schlechter funktioniert.
  by_gold_matchingart <- comparison |>
    dplyr::filter(!is.na(.data$gold_matchingart)) |>
    dplyr::group_by(.data$gold_matchingart) |>
    dplyr::summarise(
      n = dplyr::n(),
      match_rate = mean(.data$matched == "yes", na.rm = TRUE),
      review_rate = mean(.data$needs_review, na.rm = TRUE),
      luf_accuracy = safe_mean(.data$luf_correct[.data$has_gold_luf]),
      .groups = "drop"
    )

  # Gibt sowohl die Detailtabelle als auch die beiden Zusammenfassungen zurück.
  list(
    comparison = comparison,
    metrics = metrics,
    by_gold_matchingart = by_gold_matchingart
  )
}
