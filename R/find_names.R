#' Verfügbare GERIT-Hochschulnamen auflisten
#'
#' Liest die Spalte `Hochschul_Name` (oder `HS` in alten Dateien) aus der
#' GERIT-`.rds`-Datei und gibt alle eindeutigen Namen alphabetisch sortiert aus.
#'
#' @param gerit_file Pfad zur GERIT-`.rds`-Datei.
#'
#' @return Ein Tibble mit einer Spalte `name_gerit`; wird ausgegeben und
#'   unsichtbar zurückgegeben.
#'
#' @export
find_names <- function(gerit_file = "data/GERIT_DESTATIS_data.rds") {
  if (!file.exists(gerit_file)) {
    stop(paste0("GERIT-Datei nicht gefunden: ", gerit_file, "."), call. = FALSE)
  }

  gerit <- readRDS(gerit_file) |>
    tibble::as_tibble()

  name_col <- if ("Hochschul_Name" %in% names(gerit)) {
    "Hochschul_Name"
  } else if ("HS" %in% names(gerit)) {
    "HS"
  } else {
    stop("GERIT-Datei muss `Hochschul_Name` oder `HS` enthalten.", call. = FALSE)
  }

  gerit |>
    dplyr::transmute(name_gerit = as.character(.data[[name_col]])) |>
    dplyr::filter(!is.na(.data$name_gerit), .data$name_gerit != "") |>
    dplyr::distinct(.data$name_gerit) |>
    dplyr::arrange(.data$name_gerit) |>
    print(n = Inf)
}
