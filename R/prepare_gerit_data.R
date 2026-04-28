#' GERIT-Daten für das Matching vorbereiten
#'
#' Liest die GERIT-Basis aus einer `.rds`-Datei, filtert auf die gewünschte
#' Hochschule (`Hochschul_Name`, ehemals `HS`) und bereitet die Kernfelder für
#' das Matching von gescrapten `organisation`-Werten gegen `Gerit_Orga`
#' (ehemals `Einrichtung`) vor.
#'
#' @param name_gerit Hochschulname genau so, wie er in `Hochschul_Name` der
#'   GERIT-Datei vorkommt.
#' @param gerit_file Pfad zur GERIT-`.rds`-Datei.
#'
#' @return Ein Tibble mit den gefilterten GERIT-Einträgen. Enthält alle
#'   Spalten aus der Quelle plus:
#'   `gerit_ID` als stabilen Schlüssel für Kandidatenauswahl, Review und
#'   Matching-Exporte;
#'   `gerit_cleaned` für robustere Textvergleiche im deterministischen und
#'   embedding-basierten Matching;
#'   `unique_name_for_einrichtung` als Flag, ob ein Einrichtungsname in der
#'   gefilterten GERIT-Menge eindeutig ist.
#'
#' @export
prepare_gerit_data <- function(
  name_gerit,
  gerit_file = "data/GERIT_DESTATIS_data.rds"
) {
  # 1) Sicherstellen, dass die GERIT-Datei vorhanden ist.
  if (!file.exists(gerit_file)) {
    stop(
      paste0("GERIT-Datei nicht gefunden: ", gerit_file, "."),
      call. = FALSE
    )
  }

  # 2) RDS laden und als Tibble vereinheitlichen.
  gerit_raw <- readRDS(gerit_file) |>
    tibble::as_tibble()

  if (!"HS" %in% names(gerit_raw) && "Hochschul_Name" %in% names(gerit_raw)) {
    gerit_raw <- gerit_raw |>
      dplyr::mutate(HS = .data$Hochschul_Name)
  }

  if (!"Einrichtung" %in% names(gerit_raw) && "Gerit_Orga" %in% names(gerit_raw)) {
    gerit_raw <- gerit_raw |>
      dplyr::mutate(Einrichtung = .data$Gerit_Orga)
  }

  optional_cols <- c(
    paste0("Fachgebiet_Gerit_", 1:6),
    "Faechergruppen_IDs",
    "LUF_Namen"
  )
  for (optional_col in setdiff(optional_cols, names(gerit_raw))) {
    gerit_raw[[optional_col]] <- NA_character_
  }

  # 3) Pflichtspalten prüfen, damit die spätere Logik zuverlässig läuft.
  required_cols <- c("HS", "Einrichtung")
  missing_cols <- setdiff(required_cols, names(gerit_raw))
  if (length(missing_cols) > 0) {
    stop(
      paste0(
        "In der GERIT-Datei fehlen Pflichtspalten: ",
        paste(missing_cols, collapse = ", "),
        ". Erwartet werden `Hochschul_Name`/`HS` und `Gerit_Orga`/`Einrichtung`."
      ),
      call. = FALSE
    )
  }

  # 4) Verfügbare Hochschulnamen aus der Quelle ermitteln.
  available_names <- gerit_raw |>
    dplyr::pull("HS") |>
    as.character() |>
    unique() |>
    sort()

  # 5) Gewählten Hochschulnamen validieren; bei Fehlern zulässige Namen ausgeben.
  if (!name_gerit %in% available_names) {
    warning(
      paste0("name_gerit = \"", name_gerit, "\" wurde in Hochschul_Name/HS nicht gefunden."),
      call. = FALSE
    )

    tibble::tibble(name_gerit = available_names) |>
      print(n = Inf)

    stop("Ungueltiger name_gerit. Siehe Liste der zulaessigen Namen oben.", call. = FALSE)
  }

  # 6) Auf die gewünschte Hochschule filtern.
  gerit <- gerit_raw |>
    dplyr::filter(.data$HS == name_gerit)

  # 7) gerit_ID robust erzeugen oder vorhandene IDs aufbereiten.
  if ("gerit_ID" %in% names(gerit)) {
    gerit <- gerit |>
      dplyr::mutate(
        gerit_ID = suppressWarnings(as.integer(.data$gerit_ID)),
        gerit_ID = dplyr::if_else(is.na(.data$gerit_ID), dplyr::row_number(), .data$gerit_ID)
      )
  } else {
    gerit <- gerit |>
      dplyr::mutate(gerit_ID = dplyr::row_number())
  }

  # 8) Match-Hilfsspalten hinzufügen (normalisierter Name und Eindeutigkeitsflag).
  gerit |>
    dplyr::mutate(
      gerit_cleaned = normalize_text(.data$Einrichtung),
      unique_name_for_einrichtung = dplyr::if_else(
        duplicated(.data$Einrichtung) | duplicated(.data$Einrichtung, fromLast = TRUE),
        "nein",
        "ja"
      )
    )
}
