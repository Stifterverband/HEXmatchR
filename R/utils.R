#' Null-Coalescing-Operator
#'
#' Gibt `x` zurück, es sei denn, `x` ist `NULL`, hat die Länge 0 oder
#' besteht vollständig aus `NA` – dann wird stattdessen `y` zurückgegeben.
#'
#' @param x Primärer Wert.
#' @param y Fallback-Wert, der zurückgegeben wird, wenn `x` fehlt oder `NA` ist.
#'
#' @return `x`, wenn nicht-null und nicht-leer, sonst `y`.
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    return(y)
  }
  x
}

#' Aktuellen Systembenutzernamen ermitteln
#'
#' Prüft die Umgebungsvariablen `USERNAME`, `USER` und `LOGNAME` in dieser
#' Reihenfolge und gibt den ersten nicht-leeren Wert zurück. Fällt auf
#' `"unknown"` zurück, wenn keine Variable gesetzt ist.
#'
#' @return Ein einzelner Zeichenketten-Wert mit dem Benutzernamen.
#' @noRd
current_username <- function() {
  username <- Sys.getenv("USERNAME", unset = "")

  if (identical(username, "")) {
    username <- Sys.getenv("USER", unset = "")
  }

  if (identical(username, "")) {
    username <- Sys.getenv("LOGNAME", unset = "")
  }

  username %||% "unknown"
}

#' Textfortschrittsbalken erstellen
#'
#' Kapselt [utils::txtProgressBar()] und gibt vor dem Erstellen des Balkens
#' eine Beschriftung aus. Gibt `NULL` zurück, wenn `total` `NA` oder
#' nicht-positiv ist, damit Aufrufer das Ergebnis direkt an
#' `progress_bar_update()` weitergeben können ohne zusätzlichen
#' `NULL`-Check.
#'
#' @param total Gesamtanzahl der Schritte (Ganzzahl).
#' @param label Nachricht, die vor dem Balken auf der Konsole ausgegeben
#'   wird.
#'
#' @return Ein `txtProgressBar`-Objekt oder `NULL`.
#' @noRd
progress_bar_create <- function(total, label) {
  if (is.na(total) || total <= 0) {
    return(NULL)
  }

  message(label)
  utils::txtProgressBar(min = 0, max = total, style = 3)
}

#' Textfortschrittsbalken aktualisieren
#'
#' Dünner Wrapper um [utils::setTxtProgressBar()], der nichts tut, wenn
#' `pb` `NULL` ist.
#'
#' @param pb Ein `txtProgressBar`-Objekt oder `NULL`.
#' @param value Aktueller Fortschrittswert.
#'
#' @return `NULL` unsichtbar.
#' @noRd
progress_bar_update <- function(pb, value) {
  if (!is.null(pb)) {
    utils::setTxtProgressBar(pb, value)
  }
}

#' Textfortschrittsbalken schließen
#'
#' Dünner Wrapper um [base::close()], der nichts tut, wenn `pb` `NULL` ist.
#'
#' @param pb Ein `txtProgressBar`-Objekt oder `NULL`.
#'
#' @return `NULL` unsichtbar.
#' @noRd
progress_bar_close <- function(pb) {
  if (!is.null(pb)) {
    close(pb)
  }
}

#' Eindeutige, nicht-fehlende Werte zu einer Zeichenkette zusammenführen
#'
#' Konvertiert `x` zu Zeichenketten, entfernt `NA` und leere Strings,
#' dedupliziert und verbindet die verbleibenden Werte mit `sep`. Gibt
#' `NA_character_` zurück, wenn nach dem Filtern nichts mehr übrig bleibt.
#'
#' @param x Ein Vektor beliebigen Typs.
#' @param sep Trennzeichen zwischen den zusammengeführten Werten.
#'
#' @return Eine einzelne Zeichenkette oder `NA_character_`.
#' @noRd
collapse_unique <- function(x, sep = "|") {
  values <- unique(stats::na.omit(as.character(x)))
  values <- values[values != ""]
  if (length(values) == 0) {
    return(NA_character_)
  }
  paste(values, collapse = sep)
}

#' Pipe-getrennte Zeichenkette in Tokens zerlegen
#'
#' Teilt `x` an `|` auf, trimmt Leerzeichen von jedem Teil und verwirft
#' leere Zeichenketten. Gibt einen leeren Zeichenvektor für fehlende oder
#' leere Eingaben zurück.
#'
#' @param x Eine einzelne Zeichenkette.
#'
#' @return Ein Zeichenvektor getrimmter, nicht-leerer Tokens.
#' @noRd
split_pipe <- function(x) {
  if (length(x) == 0 || is.na(x) || identical(x, "")) {
    return(character())
  }
  stringr::str_split(x, "\\|", simplify = FALSE)[[1]] |>
    stringr::str_trim() |>
    (\(values) values[values != ""])()
}

#' Semikolon-getrennte Organisationszeichenkette aufteilen
#'
#' Teilt `x` an `;` (mit optionalem Leerzeichen drum herum) auf, trimmt
#' jeden Teil und verwirft leere Zeichenketten.
#'
#' @param x Eine einzelne Zeichenkette.
#'
#' @return Ein Zeichenvektor getrimmter, nicht-leerer Tokens.
#' @noRd
split_orgs <- function(x) {
  if (length(x) == 0 || is.na(x) || identical(x, "")) {
    return(character())
  }
  stringr::str_split(x, "\\s*;\\s*", simplify = FALSE)[[1]] |>
    stringr::str_trim() |>
    (\(values) values[values != ""])()
}

#' Organisationszeichenkette aufteilen oder `NA` zurückgeben
#'
#' Wie `split_orgs()`, gibt aber `NA_character_` statt eines leeren Vektors
#' zurück, wenn die Eingabe keine Tokens liefert.
#'
#' @param x Eine einzelne Zeichenkette.
#'
#' @return Ein Zeichenvektor von Tokens oder `NA_character_`, wenn die
#'   Eingabe leer oder fehlend ist.
#' @noRd
split_orgs_or_na <- function(x) {
  values <- split_orgs(x)
  if (length(values) == 0) {
    return(NA_character_)
  }
  values
}

#' Organisationsnamen normalisieren
#'
#' Transliteriert zu ASCII, wandelt in Kleinbuchstaben um, entfernt
#' Klammerzeichen, ersetzt `&` durch `" und "`, streicht gängige deutsche
#' Strukturbezeichnungen (z. B. "Institut", "Lehrstuhl", "Fachbereich"),
#' entfernt alle weiteren nicht-alphanumerischen Zeichen und
#' bereinigt Leerzeichen.
#'
#' @param x Ein Zeichenvektor.
#'
#' @return Ein Zeichenvektor gleicher Länge wie `x` mit normalisierten
#'   Zeichenketten.
#' @noRd
normalize_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- stringr::str_to_lower(x)
  x <- stringr::str_replace_all(x, "[\\[\\]()]", " ")
  x <- stringr::str_replace_all(x, "&", " und ")
  x <- stringr::str_replace_all(
    x,
    "\\b(institut|professur|juniorprofessur|department|fachgruppe|fachbereich|seminar|klinik|abteilung|lehrstuhl|arbeitsgruppe|zentrum|arbeitsstelle|chair)\\b",
    " "
  )
  x <- stringr::str_replace_all(x, "\\bfur\\b", " ")
  x <- stringr::str_replace_all(x, "[^a-z0-9]+", " ")
  stringr::str_squish(x)
}

#' Vektor in Blöcke fester Größe aufteilen
#'
#' @param x Aufzuteilender Vektor.
#' @param chunk_size Maximale Länge jedes Blocks.
#'
#' @return Eine Liste von Vektoren mit je maximal `chunk_size` Elementen.
#' @noRd
chunk_vector <- function(x, chunk_size = 100) {
  split(x, ceiling(seq_along(x) / chunk_size))
}

#' Embedding-Eingabetext für einen GERIT-Eintrag erstellen
#'
#' Gibt den `einrichtung`-Namen zurück (oder einen leeren String,
#' wenn `NULL`).
#'
#' @param einrichtung Name der GERIT-Einrichtung.
#'
#' @return Eine einzelne Zeichenkette.
#' @noRd
build_gerit_embedding_text <- function(einrichtung) {
  einrichtung %||% ""
}

#' Embedding-Eingabetext für eine gescrapte Organisation erstellen
#'
#' Gibt `organisation` zurück, fällt auf `cleaned` zurück, und dann auf
#' einen leeren String, wenn beides fehlt.
#'
#' @param organisation Roher Organisationsname.
#' @param cleaned Normalisierter Organisationsname.
#'
#' @return Eine einzelne Zeichenkette.
#' @noRd
build_scraped_embedding_text <- function(organisation, cleaned) {
  organisation %||% cleaned %||% ""
}

#' Embedding-Eingabetext aus Primaer- und Sekundaerfeld erstellen
#'
#' Baut einen einfachen zweizeiligen Text aus einem primaeren und optional
#' normalisierten Wert. Das ist nuetzlich fuer Matching-Szenarien, die nicht
#' direkt dem GERIT/Scraping-Schema folgen.
#'
#' @param primary Primaerer Anzeigename.
#' @param secondary Sekundaerer oder normalisierter Name.
#' @param primary_label Label fuer die erste Zeile.
#' @param secondary_label Label fuer die zweite Zeile.
#'
#' @return Eine einzelne Zeichenkette.
#' @noRd
build_named_embedding_text <- function(
  primary,
  secondary = NULL,
  primary_label = "name",
  secondary_label = "normalized_name"
) {
  paste(
    paste0(primary_label, ": ", primary %||% ""),
    paste0(secondary_label, ": ", secondary %||% ""),
    sep = "\n"
  )
}

#' OpenAI-Embeddings für einen Zeichenvektor abrufen
#'
#' Sendet `inputs` in Batches der Größe `batch_size` an den OpenAI-
#' Endpunkt `POST /v1/embeddings`, authentifiziert über die Umgebungs-
#' variable `OPENAI_API_KEY`. Bricht mit einem informativen Fehler ab,
#' wenn der Schlüssel fehlt oder nicht gesetzt ist.
#'
#' @param inputs Ein Zeichenvektor mit den zu bettenden Texten.
#' @param model OpenAI-Embedding-Modellkennung.
#' @param batch_size Anzahl der Texte pro API-Anfrage.
#' @param label Lesbare Beschriftung für die Fortschrittsbalken-Meldung.
#' @param cache_file Optionaler Pfad zu einer `.rds`-Cache-Datei. Wenn gesetzt,
#'   werden vorhandene Embeddings für dieselbe Modell-/Text-Kombination
#'   wiederverwendet und neu abgerufene Embeddings dort gespeichert.
#'
#' @return Eine Liste numerischer Vektoren, je einer pro Element von
#'   `inputs`, der das Embedding des jeweiligen Textes repräsentiert.
#' @noRd
fetch_openai_embeddings <- function(
  inputs,
  model = "text-embedding-3-large",
  batch_size = 100,
  label = "Texte",
  cache_file = NULL
) {
  load_embedding_cache <- function(path) {
    if (is.null(path) || !file.exists(path)) {
      return(tibble::tibble(
        model = character(),
        input = character(),
        embedding = list()
      ))
    }

    cache_tbl <- readRDS(path) |>
      tibble::as_tibble()

    required_cols <- c("model", "input", "embedding")
    if (!all(required_cols %in% names(cache_tbl))) {
      return(tibble::tibble(
        model = character(),
        input = character(),
        embedding = list()
      ))
    }

    cache_tbl
  }

  save_embedding_cache <- function(cache_tbl, path) {
    if (is.null(path)) {
      return(invisible(NULL))
    }

    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(cache_tbl, path)
    invisible(NULL)
  }

  api_key <- Sys.getenv("OPENAI_API_KEY")

  if (identical(api_key, "")) {
    stop("`OPENAI_API_KEY` is not set.", call. = FALSE)
  }

  if (length(inputs) == 0) {
    return(list())
  }

  inputs <- as.character(inputs)
  cache_tbl <- load_embedding_cache(cache_file)

  cached_tbl <- cache_tbl |>
    dplyr::filter(.data$model == model, .data$input %in% inputs) |>
    dplyr::distinct(.data$model, .data$input, .keep_all = TRUE)

  missing_inputs <- setdiff(unique(inputs), cached_tbl$input)
  batches <- chunk_vector(as.list(missing_inputs), chunk_size = batch_size)
  pb <- progress_bar_create(length(batches), paste0("Embeddings fuer ", label, "."))

  on.exit(progress_bar_close(pb), add = TRUE)

  fetched_tbl <- if (length(batches) == 0) {
    tibble::tibble(
      model = character(),
      input = character(),
      embedding = list()
    )
  } else {
    purrr::map_dfr(
      seq_along(batches),
      \(batch_idx) {
        response <- httr2::request("https://api.openai.com/v1/embeddings") |>
          httr2::req_headers(
            Authorization = paste("Bearer", api_key)
          ) |>
          httr2::req_body_json(
            list(
              model = model,
              input = unname(batches[[batch_idx]])
            ),
            auto_unbox = TRUE
          ) |>
          httr2::req_perform() |>
          httr2::resp_body_json(simplifyVector = FALSE)

        progress_bar_update(pb, batch_idx)

        tibble::tibble(
          model = rep(model, length(response$data)),
          input = unname(unlist(batches[[batch_idx]])),
          embedding = response$data |>
            purrr::map(\(item) as.numeric(unlist(item$embedding)))
        )
      }
    )
  }

  if (nrow(fetched_tbl) > 0) {
    cache_tbl <- dplyr::bind_rows(cache_tbl, fetched_tbl) |>
      dplyr::distinct(.data$model, .data$input, .keep_all = TRUE)
    save_embedding_cache(cache_tbl, cache_file)
  }

  embedding_tbl <- dplyr::bind_rows(cached_tbl, fetched_tbl) |>
    dplyr::distinct(.data$model, .data$input, .keep_all = TRUE)

  embedding_lookup <- stats::setNames(embedding_tbl$embedding, embedding_tbl$input)
  unname(embedding_lookup[inputs])
}

#' Kosinusähnlichkeit zwischen zwei numerischen Vektoren
#'
#' Gibt 0 zurück, wenn einer der Vektoren die Norm 0 hat, um eine Division
#' durch null zu vermeiden.
#'
#' @param x Ein numerischer Vektor.
#' @param y Ein numerischer Vektor gleicher Länge wie `x`.
#'
#' @return Ein Skalar in \eqn{[-1, 1]}.
#' @noRd
cosine_similarity <- function(x, y) {
  x <- as.numeric(unlist(x))
  y <- as.numeric(unlist(y))

  x_norm <- sqrt(sum(x * x))
  y_norm <- sqrt(sum(y * y))

  if (x_norm == 0 || y_norm == 0) {
    return(0)
  }

  sum(x * y) / (x_norm * y_norm)
}

#' Kosinusähnlichkeitstabelle zwischen Query und Kandidaten-Embeddings
#'
#' @param query_embedding Ein numerischer Vektor (das Query-Embedding).
#' @param candidate_embeddings Eine Liste numerischer Vektoren
#'   (Kandidaten-Embeddings).
#'
#' @return Ein Tibble mit den Spalten `row_id` (ganzzahliger Index in
#'   `candidate_embeddings`) und `score` (Kosinusähnlichkeit, numerisch).
#' @noRd
embedding_similarity_tbl <- function(query_embedding, candidate_embeddings) {
  tibble::tibble(
    row_id = seq_along(candidate_embeddings),
    score = purrr::map_dbl(candidate_embeddings, \(embedding) cosine_similarity(query_embedding, embedding))
  )
}

#' Gerankte Kandidaten via Embeddings generisch erzeugen
#'
#' Bettet Query- und Kandidatentexte ein, berechnet Kosinusaehnlichkeiten und
#' gibt pro Query die top-`k` Kandidaten mit Rang zurueck.
#'
#' @param query_tbl Tibble mit Query-Zeilen.
#' @param candidate_tbl Tibble mit Kandidaten-Zeilen.
#' @param query_id_col Name der Query-ID-Spalte.
#' @param candidate_id_col Name der Kandidaten-ID-Spalte.
#' @param query_text_col Name der Spalte mit Query-Embedding-Texten.
#' @param candidate_text_col Name der Spalte mit Kandidaten-Embedding-Texten.
#' @param query_keep_cols Zusaetzliche Query-Spalten, die im Ergebnis erhalten
#'   bleiben sollen.
#' @param candidate_keep_cols Zusaetzliche Kandidaten-Spalten, die im Ergebnis
#'   erhalten bleiben sollen.
#' @param top_k Maximale Anzahl zurueckgegebener Kandidaten pro Query.
#' @param embedding_model OpenAI-Embedding-Modellkennung.
#' @param batch_size Anzahl der Texte pro Embedding-API-Anfrage.
#' @param query_label Lesbare Beschriftung fuer Query-Embeddings.
#' @param candidate_label Lesbare Beschriftung fuer Kandidaten-Embeddings.
#' @param ranking_label Nachricht fuer den Ranking-Fortschritt.
#' @param empty_message Nachricht, wenn keine offenen Querys vorliegen.
#' @param start_message Nachricht vor dem Retrieval; kann `NULL` sein.
#' @param candidate_source Wert fuer die Ergebnisspalte `candidate_source`.
#' @param candidate_tiebreak_cols Zusaetzliche Kandidatenspalten zur stabilen
#'   Sortierung bei Score-Gleichstand.
#' @param candidate_embedding_cache_file Optionaler Pfad zu einer `.rds`-
#'   Cache-Datei fuer Kandidaten-Embeddings. Query-Embeddings werden bewusst
#'   nicht gecacht, weil sie typischerweise laufabhaengig sind.
#'
#' @return Ein Tibble mit Query-/Kandidaten-IDs, `score`, `candidate_rank`,
#'   `candidate_source` und den angeforderten Zusatzspalten.
#' @noRd
generate_ranked_embedding_candidates <- function(
  query_tbl,
  candidate_tbl,
  query_id_col,
  candidate_id_col,
  query_text_col = "embedding_text",
  candidate_text_col = "embedding_text",
  query_keep_cols = character(),
  candidate_keep_cols = character(),
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  batch_size = 100,
  query_label = "Queries",
  candidate_label = "Candidates",
  ranking_label = "Kandidatenranking laeuft.",
  empty_message = "Keine offenen Eintraege mehr fuer Embedding-Retrieval.",
  start_message = NULL,
  candidate_source = "embedding",
  candidate_tiebreak_cols = character(),
  candidate_embedding_cache_file = NULL
) {
  query_tbl <- tibble::as_tibble(query_tbl)
  candidate_tbl <- tibble::as_tibble(candidate_tbl)

  if (nrow(query_tbl) == 0) {
    message(empty_message)
    return(tibble::tibble())
  }

  if (!is.null(start_message)) {
    message(start_message)
  }

  query_embeddings <- fetch_openai_embeddings(
    inputs = query_tbl[[query_text_col]],
    model = embedding_model,
    batch_size = batch_size,
    label = query_label
  )

  candidate_embeddings <- fetch_openai_embeddings(
    inputs = candidate_tbl[[candidate_text_col]],
    model = embedding_model,
    batch_size = batch_size,
    label = candidate_label,
    cache_file = candidate_embedding_cache_file
  )

  ranking_pb <- progress_bar_create(nrow(query_tbl), ranking_label)
  on.exit(progress_bar_close(ranking_pb), add = TRUE)

  query_lookup <- query_tbl |>
    dplyr::select(dplyr::all_of(c(query_id_col, query_keep_cols))) |>
    dplyr::mutate(.query_row_id = dplyr::row_number())

  candidate_lookup <- candidate_tbl |>
    dplyr::select(dplyr::all_of(c(candidate_id_col, candidate_keep_cols))) |>
    dplyr::mutate(row_id = dplyr::row_number())

  purrr::map_dfr(
    seq_len(nrow(query_tbl)),
    \(idx) {
      result <- embedding_similarity_tbl(
        query_embedding = query_embeddings[[idx]],
        candidate_embeddings = candidate_embeddings
      ) |>
        dplyr::left_join(candidate_lookup, by = "row_id") |>
        dplyr::mutate(.query_row_id = idx) |>
        dplyr::left_join(query_lookup, by = ".query_row_id") |>
        dplyr::arrange(dplyr::desc(.data$score), dplyr::across(dplyr::all_of(candidate_tiebreak_cols))) |>
        dplyr::slice_head(n = top_k) |>
        dplyr::mutate(
          candidate_rank = dplyr::row_number(),
          candidate_source = candidate_source
        ) |>
        dplyr::select(
          dplyr::all_of(c(query_id_col, query_keep_cols, candidate_id_col, candidate_keep_cols)),
          "score",
          "candidate_rank",
          "candidate_source"
        )

      progress_bar_update(ranking_pb, idx)
      result
    }
  )
}

#' Semesterbezeichnungen in Kurzcode umwandeln
#'
#' Gibt `"w"` für Zeichenketten, die den Buchstaben `"w"` enthalten
#' (Wintersemester), und `"s"` für alle anderen zurück.
#'
#' @param x Ein Zeichenvektor mit Semesterbezeichnungen.
#'
#' @return Ein Zeichenvektor aus `"w"` oder `"s"` Werten, gleiche Länge
#'   wie `x`.
#' @noRd
semester_to_code <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  purrr::map_chr(
    x,
    \(value) {
      letters <- stringr::str_split(stringr::str_to_lower(value), "", simplify = TRUE)
      if ("w" %in% letters) "w" else "s"
    }
  )
}

#' Jüngstes verfügbares Semester in einem Data Frame finden
#'
#' Bestimmt den maximalen Wert von `jahr` und den vorherrschenden Semester-
#' Kurzcode (`"w"` / `"s"`) in diesem Jahr.
#'
#' @param data Ein Data Frame mit einer numerisch umwandelbaren `jahr`-
#'   Spalte und einer Semester-Spalte.
#' @param semester_col Name der Spalte mit den Semesterbezeichnungen.
#'
#' @return Eine Liste mit den Elementen `latest_year` (numerisch) und
#'   `semester_in_latest_year` (`"w"` oder `"s"`).
#' @noRd
find_latest_semester <- function(data, semester_col = "semester") {
  years <- suppressWarnings(as.numeric(data$jahr))
  latest_year <- max(years, na.rm = TRUE)
  latest_semester <- data |>
    dplyr::mutate(.jahr = years) |>
    dplyr::filter(.jahr == latest_year) |>
    dplyr::pull(dplyr::all_of(semester_col)) |>
    semester_to_code()
  list(
    latest_year = latest_year,
    semester_in_latest_year = if ("w" %in% latest_semester) "w" else "s"
  )
}

#' Verwendetes Trennzeichen in einer Organisationsspalte erkennen
#'
#' Prüft, ob die Spalte `" ; "` oder `"|"` als Mehrfachorganisations-
#' Trennzeichen verwendet. Bricht mit einem Fehler ab, wenn beide Trennzeichen
#' vorkommen. Gibt `"none"` zurück, wenn keines gefunden wird.
#'
#' @param x Ein Zeichenvektor (z. B. die Organisationsspalte).
#'
#' @return Einer der Werte `" ; "`, `"|"` oder `"none"`.
#' @noRd
detect_separator <- function(x) {
  values <- stats::na.omit(as.character(x))
  has_semicolon <- any(stringr::str_detect(values, stringr::fixed(" ; ")))
  has_pipe <- any(stringr::str_detect(values, stringr::fixed("|")))
  if (has_semicolon && has_pipe) {
    stop("Organisation values use both ' ; ' and '|'. Please standardize the separator first.", call. = FALSE)
  }
  if (has_semicolon) {
    return(" ; ")
  }
  if (has_pipe) {
    return("|")
  }
  "none"
}

#' Jaccard-Token-Überlappung zweier Zeichenketten
#'
#' Tokenisiert beide Zeichenketten anhand von Leerzeichen und berechnet
#' den Anteil gemeinsamer eindeutiger Tokens an der Gesamtmenge eindeutiger
#' Tokens beider Zeichenketten.
#'
#' @param a Eine einzelne Zeichenkette.
#' @param b Eine einzelne Zeichenkette.
#'
#' @return Ein numerischer Skalar zwischen 0 und 1.
#' @noRd
token_overlap <- function(a, b) {
  a_tokens <- unique(stringr::str_split(a, "\\s+", simplify = FALSE)[[1]])
  b_tokens <- unique(stringr::str_split(b, "\\s+", simplify = FALSE)[[1]])
  a_tokens <- a_tokens[a_tokens != ""]
  b_tokens <- b_tokens[b_tokens != ""]
  if (length(a_tokens) == 0 || length(b_tokens) == 0) {
    return(0)
  }
  shared <- length(intersect(a_tokens, b_tokens))
  shared / length(unique(c(a_tokens, b_tokens)))
}

#' Wert sicher zu einer einzelnen Ganzzahl konvertieren
#'
#' Wandelt `x` in Integer um und unterdrückt dabei Konvertierungswarnungen.
#' Gibt `NA_integer_` zurück, wenn das Ergebnis leer oder `NA` ist.
#'
#' @param x Ein Wert, der zu Integer konvertiert werden kann.
#'
#' @return Eine einzelne Ganzzahl oder `NA_integer_`.
#' @noRd
safe_integer <- function(x) {
  value <- suppressWarnings(as.integer(x))
  if (length(value) == 0 || is.na(value)) {
    return(NA_integer_)
  }
  value[[1]]
}

#' Benanntes Element mit Fallback-Standard extrahieren
#'
#' Funktioniert sowohl mit Listen (nach Name) als auch mit einzeiligen
#' Data Frames (nach Spaltenname). Gibt `default` zurück, wenn `x`
#' `NULL` ist, der Name nicht existiert oder der extrahierte Wert leer ist.
#'
#' @param x Eine Liste oder ein einzeiliger Data Frame.
#' @param name Zu extrahierendes Element oder Spaltenname.
#' @param default Rückgabewert bei fehlgeschlagener Extraktion.
#'
#' @return Der extrahierte Wert oder `default`.
#' @noRd
pluck_or_default <- function(x, name, default = NULL) {
  if (is.null(x)) {
    return(default)
  }

  if (is.data.frame(x) && name %in% names(x)) {
    value <- x[[name]]
    if (length(value) == 0) {
      return(default)
    }
    return(value[[1]])
  }

  if (is.list(x) && !is.null(names(x)) && name %in% names(x)) {
    value <- x[[name]]
    if (length(value) == 0) {
      return(default)
    }
    return(value)
  }

  default
}

#' Kandidatenauswahl per LLM generisch anfragen
#'
#' Baut fuer jede Query aus einer Kandidatenmenge einen Prompt, fragt ein
#' OpenAI-Modell per `ellmer::chat_openai()` ab und gibt die rohen
#' strukturierten Entscheidungen als Tibble zurueck.
#'
#' @param query_tbl Tibble mit Query-Zeilen.
#' @param candidate_tbl Tibble mit Kandidaten-Zeilen.
#' @param query_id_col Name der Query-ID-Spalte.
#' @param candidate_group_col Spalte in `candidate_tbl`, ueber die Kandidaten
#'   einer Query zugeordnet werden.
#' @param model OpenAI-Modellname.
#' @param temperature Optionaler Temperaturwert fuer `ellmer::chat_openai()`.
#'   `NULL` laesst die Voreinstellung des Modells bzw. Pakets unveraendert.
#' @param response_format Optionales JSON-Schema bzw. Response-Format fuer
#'   strukturierte Modellantworten.
#' @param system_prompt System-Prompt fuer das Modell.
#' @param prompt_builder Funktion `(query_row, candidates) -> string`.
#' @param no_candidate_reason Begruendungstext, wenn keine Kandidaten vorliegen.
#' @param progress_message Nachricht vor dem LLM-Lauf.
#' @param progress_label Beschriftung des Fortschrittsbalkens.
#'
#' @return Ein Tibble mit `query_id`, `decision`, `selected_candidate_id`,
#'   `confidence`, `reason` und `needs_review`.
#' @noRd
request_llm_candidate_decisions <- function(
  query_tbl,
  candidate_tbl,
  query_id_col,
  candidate_group_col = query_id_col,
  model = "gpt-4.1-mini",
  temperature = NULL,
  response_format = NULL,
  system_prompt,
  prompt_builder,
  no_candidate_reason = "No ranked candidates were generated.",
  progress_message = NULL,
  progress_label = "LLM-Klassifikation laeuft."
) {
  query_tbl <- tibble::as_tibble(query_tbl)
  candidate_tbl <- tibble::as_tibble(candidate_tbl)

  if (nrow(query_tbl) == 0) {
    return(tibble::tibble())
  }

  if (!is.null(progress_message)) {
    message(progress_message)
  }

  decision_type <- ellmer::type_object(
    decision = ellmer::type_enum(
      c("select_candidate", "no_match"),
      "How the query should be matched."
    ),
    selected_candidate_id = ellmer::type_string("Candidate ID when selecting a candidate.", required = FALSE),
    confidence = ellmer::type_number("Confidence between 0 and 1."),
    reason = ellmer::type_string("Short rationale."),
    needs_review = ellmer::type_boolean("Whether a human should still review the case.")
  )

  llm_pb <- progress_bar_create(nrow(query_tbl), progress_label)
  on.exit(progress_bar_close(llm_pb), add = TRUE)

  purrr::map_dfr(
    seq_len(nrow(query_tbl)),
    \(idx) {
      query_row <- query_tbl[idx, , drop = FALSE]
      query_id <- query_row[[query_id_col]][[1]]

      candidates <- candidate_tbl |>
        dplyr::filter(.data[[candidate_group_col]] == query_id) |>
        dplyr::arrange(.data$candidate_rank)

      if (nrow(candidates) == 0) {
        progress_bar_update(llm_pb, idx)
        return(tibble::tibble(
          query_id = query_id,
          decision = "no_match",
          selected_candidate_id = NA_character_,
          confidence = NA_real_,
          reason = no_candidate_reason,
          needs_review = TRUE
        ))
      }

      prompt <- prompt_builder(query_row, candidates)

      chat_args <- list(
        system_prompt = system_prompt,
        model = model,
        echo = "none"
      )

      chat_formals <- tryCatch(
        names(formals(ellmer::chat_openai)),
        error = function(...) character()
      )

      if (!is.null(temperature) && "temperature" %in% chat_formals) {
        chat_args$temperature <- temperature
      }

      if (!is.null(response_format) && "response_format" %in% chat_formals) {
        chat_args$response_format <- response_format
      }

      chat <- do.call(ellmer::chat_openai, chat_args)

      decision <- chat$chat_structured(prompt, type = decision_type)

      selected_candidate_id <- pluck_or_default(decision, "selected_candidate_id", NA_character_)
      if (is.na(selected_candidate_id) || identical(selected_candidate_id, "")) {
        selected_candidate_id <- pluck_or_default(decision, "selected_gerit_id", NA_character_)
      }
      if (is.na(selected_candidate_id) || identical(selected_candidate_id, "")) {
        selected_candidate_id <- pluck_or_default(decision, "selected_luf_id", NA_character_)
      }

      progress_bar_update(llm_pb, idx)

      tibble::tibble(
        query_id = query_id,
        decision = pluck_or_default(decision, "decision", "no_match") %||% "no_match",
        selected_candidate_id = as.character(selected_candidate_id),
        confidence = suppressWarnings(as.numeric(pluck_or_default(decision, "confidence", NA_real_))),
        reason = pluck_or_default(decision, "reason", "") %||% "",
        needs_review = isTRUE(pluck_or_default(decision, "needs_review", FALSE))
      )
    }
  )
}

#' Leeres Tibble mit Match-Ergebnisspalten erstellen
#'
#' Erzeugt ein Tibble mit `n` Zeilen, vorbelegt mit `NA` bzw. `"no"` für
#' alle Spalten, in die die Matching-Pipeline schreibt. Bereit zum Anhängen
#' an eine frisch extrahierte Organisationstabelle.
#'
#' @param n Anzahl der Zeilen.
#'
#' @return Ein Tibble mit den Spalten `gerit_ID`, `gerit_organisation`,
#'   `LUF_IDs`, `matched`, `match_type`, `match_confidence`, `match_reason`
#'   und `needs_review`.
#' @noRd
empty_match_columns <- function(n) {
  fachgebiet_cols <- stats::setNames(
    rep(list(rep(NA_character_, n)), 6),
    paste0("Fachgebiet_Gerit_", 1:6)
  )

  tibble::tibble(
    gerit_ID = rep(NA_integer_, n),
    gerit_organisation = rep(NA_character_, n),
    gerit_cleaned = rep(NA_character_, n),
    Faechergruppen = rep(NA_character_, n),
    Faechergruppen_IDs = rep(NA_character_, n),
    LUF_IDs = rep(NA_character_, n),
    LUF_Namen = rep(NA_character_, n),
    !!!fachgebiet_cols,
    matched = rep("no", n),
    match_type = rep(NA_character_, n),
    match_confidence = rep(NA_real_, n),
    match_reason = rep(NA_character_, n),
    needs_review = rep(FALSE, n)
  )
}

#' Standardisierten Matching-Ausgabedateinamen erstellen
#'
#' @param who_matched Benutzername der Person, die das Matching durchgeführt hat.
#' @param when_matched Datum des Matching-Durchlaufs (`Date`-Objekt oder
#'   umwandelbarer String).
#' @param matching_iteration Iterations-Tag (z. B. `"erstkodierung"`).
#'
#' @return Eine einzelne Zeichenkette mit dem Dateinamen (ohne Verzeichnispfad).
#' @noRd
build_matching_filename <- function(who_matched, when_matched, matching_iteration) {
  paste0(
    "matching_data_",
    who_matched,
    "_",
    as.character(when_matched),
    "#",
    matching_iteration,
    ".rds"
  )
}

#' Im Matching-Ausgabedateinamen kodierte Metadaten lesen
#'
#' Extrahiert den Iterations-Tag (Abschnitt nach `#` und vor `.rds`) und
#' das ISO-Datum aus dem Dateinamen.
#'
#' @param path Vollständiger oder relativer Pfad zu einer Matching-`.rds`-Datei.
#'
#' @return Eine Liste mit den Elementen `path`, `filename` (Zeichenkette),
#'   `tag` (Zeichenkette, `"unknown"` wenn fehlend) und
#'   `when_matched` (Date).
#' @noRd
parse_matching_metadata <- function(path) {
  file <- basename(path)
  tag <- stringr::str_match(file, "#([^\\.]+)\\.rds$")[, 2]
  date_text <- stringr::str_match(file, "(\\d{4}-\\d{2}-\\d{2})")[, 2]
  list(
    path = path,
    filename = file,
    tag = ifelse(is.na(tag), "unknown", tag),
    when_matched = as.Date(date_text)
  )
}

#' Nächsten Matching-Iterations-Tag bestimmen
#'
#' Durchsucht `existing_matching_path` nach `.rds`-Dateien, liest den
#' jüngsten Iterations-Tag und gibt den nächsten Tag in der Abfolge zurück:
#' `"erstkodierung"` → `"zweitkodierung"` → `"update"`.
#'
#' @param existing_matching_path Pfad zu einem Verzeichnis mit früheren
#'   Matching-Ausgabedateien, oder `NULL`.
#'
#' @return Eine einzelne Zeichenkette: `"erstkodierung"`,
#'   `"zweitkodierung"` oder `"update"`.
#' @noRd
next_matching_iteration <- function(existing_matching_path = NULL) {
  if (is.null(existing_matching_path) || !dir.exists(existing_matching_path)) {
    return("erstkodierung")
  }
  files <- list.files(existing_matching_path, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) == 0) {
    return("erstkodierung")
  }
  metadata <- purrr::map(files, parse_matching_metadata) |>
    tibble::tibble(info = _) |>
    tidyr::unnest_wider(info)
  latest_tag <- metadata |>
    dplyr::arrange(dplyr::desc(when_matched), filename) |>
    dplyr::slice(1) |>
    dplyr::pull(tag)
  dplyr::case_when(
    latest_tag == "erstkodierung" ~ "zweitkodierung",
    latest_tag == "zweitkodierung" ~ "update",
    TRUE ~ "update"
  )
}

#' Match-Datensatz in die Matching-Ergebnistabelle eintragen
#'
#' Aktualisiert alle Match-bezogenen Spalten von `scraped_tbl` in der Zeile
#' `row_id` mit den Werten aus `match_record`.
#'
#' @param scraped_tbl Das zu aktualisierende Organisationsebene-Tibble.
#' @param row_id Ganzzahliger Zeilenindex, der aktualisiert werden soll.
#' @param match_record Eine benannte Liste mit Werten für alle Match-Spalten.
#'
#' @return Das aktualisierte `scraped_tbl`-Tibble.
#' @noRd
apply_match_record <- function(scraped_tbl, row_id, match_record) {
  columns <- c(
    "gerit_ID", "gerit_organisation", "gerit_cleaned",
    paste0("Fachgebiet_Gerit_", 1:6),
    "Faechergruppen", "Faechergruppen_IDs", "LUF_IDs", "LUF_Namen", "matched", "match_type",
    "match_confidence", "match_reason", "needs_review"
  )
  for (column in columns) {
    if (!column %in% names(scraped_tbl)) {
      scraped_tbl[[column]] <- NA
    }
    scraped_tbl[[column]][row_id] <- match_record[[column]] %||% NA
  }
  scraped_tbl
}

#' Match-Datensatz durch Nachschlagen einer GERIT-ID erstellen
#'
#' Ruft den GERIT-Eintrag für `gerit_id` aus `df_gerit` ab und erzeugt
#' eine benannte Match-Datensatz-Liste mit Kernfeldern.
#'
#' @param df_gerit Vorbereitete GERIT-Daten aus [prepare_gerit_data()].
#' @param gerit_id Ganzzahlige GERIT-ID, die nachgeschlagen werden soll.
#' @param match_type Zeichenketten-Tag für die Match-Strategie
#'   (z. B. `"direct"`, `"llm"`).
#' @param confidence Numerischer Konfidenzwert zwischen 0 und 1.
#' @param reason Menschenlesbarer Begründungstext.
#' @param needs_review Logisch; ob der Match zur manuellen Prüfung
#'   markiert werden soll.
#'
#' @return Eine benannte Liste mit allen Match-Datensatz-Feldern.
#' @noRd
lookup_match_from_gerit <- function(df_gerit, gerit_id, match_type, confidence, reason, needs_review = FALSE) {
  row <- df_gerit |>
    dplyr::filter(.data$gerit_ID == gerit_id) |>
    dplyr::slice(1)
  if (nrow(row) == 0) {
    stop("Unknown GERIT ID selected during matching.", call. = FALSE)
  }
  list(
    gerit_ID = row$gerit_ID[[1]],
    gerit_organisation = row$Einrichtung[[1]],
    gerit_cleaned = row$gerit_cleaned[[1]] %||% NA_character_,
    Fachgebiet_Gerit_1 = row$Fachgebiet_Gerit_1[[1]] %||% NA_character_,
    Fachgebiet_Gerit_2 = row$Fachgebiet_Gerit_2[[1]] %||% NA_character_,
    Fachgebiet_Gerit_3 = row$Fachgebiet_Gerit_3[[1]] %||% NA_character_,
    Fachgebiet_Gerit_4 = row$Fachgebiet_Gerit_4[[1]] %||% NA_character_,
    Fachgebiet_Gerit_5 = row$Fachgebiet_Gerit_5[[1]] %||% NA_character_,
    Fachgebiet_Gerit_6 = row$Fachgebiet_Gerit_6[[1]] %||% NA_character_,
    Faechergruppen = row$Faechergruppen[[1]] %||% NA_character_,
    Faechergruppen_IDs = row$Faechergruppen_IDs[[1]] %||% NA_character_,
    LUF_IDs = row$LUF_IDs[[1]] %||% NA_character_,
    LUF_Namen = row$LUF_Namen[[1]] %||% NA_character_,
    matched = "yes",
    match_type = match_type,
    match_confidence = confidence,
    match_reason = reason,
    needs_review = needs_review
  )
}

#' Kein-Match-Datensatz erstellen
#'
#' Erstellt einen Match-Datensatz-Liste, bei der alle Kernfelder `NA`
#' sind und `matched` auf `"no"` gesetzt ist. Setzt `match_type` auf
#' `"review"` wenn `needs_review = TRUE`, sonst auf `"not_matchable"`.
#'
#' @param reason Menschenlesbarer Begründungstext.
#' @param needs_review Logisch; ob der Fall zur manuellen Prüfung markiert
#'   werden soll.
#'
#' @return Eine benannte Liste mit allen Match-Datensatz-Feldern.
#' @noRd
not_match_record <- function(reason, needs_review = TRUE) {
  list(
    gerit_ID = NA_integer_,
    gerit_organisation = NA_character_,
    gerit_cleaned = NA_character_,
    Fachgebiet_Gerit_1 = NA_character_,
    Fachgebiet_Gerit_2 = NA_character_,
    Fachgebiet_Gerit_3 = NA_character_,
    Fachgebiet_Gerit_4 = NA_character_,
    Fachgebiet_Gerit_5 = NA_character_,
    Fachgebiet_Gerit_6 = NA_character_,
    Faechergruppen = NA_character_,
    Faechergruppen_IDs = NA_character_,
    LUF_IDs = NA_character_,
    LUF_Namen = NA_character_,
    matched = "no",
    match_type = if (needs_review) "review" else "not_matchable",
    match_confidence = NA_real_,
    match_reason = reason,
    needs_review = needs_review
  )
}

#' Organisationsebene-Matches in die vollständigen gescrapten Kursdaten zurückführen
#'
#' Zerlegt Mehrfachorganisationszeilen (semikolongetrennt), schlägt jedes
#' Organisationsstück in `organisation_matches` nach und aggregiert die
#' Ergebnisse zurück auf die ursprüngliche Zeilengranularität. Wenn alle
#' Komponenten einer Zeile gematcht sind, wird `matched` auf `"yes"` gesetzt;
#' bei nur teilweisen Treffern auf `"partial"`, bei keinen Treffern auf `"no"`.
#'
#' @param df_scraped Vollständiger gescrapter Kursdaten-Data-Frame.
#' @param organisation_matches Organisationsebene-Match-Tabelle,
#'   typischerweise `llm_result$scraped` aus [match_scraped_organisations()].
#' @param organisation_col Spalte in `df_scraped` mit den Organisationsnamen.
#'
#' @return `df_scraped` mit eingefügten Match-Spalten.
#' @noRd
join_matches_back_to_scraped <- function(df_scraped, organisation_matches, organisation_col = "organisation") {
  df_scraped <- tibble::as_tibble(df_scraped)
  organisation_matches <- tibble::as_tibble(organisation_matches)

  colnames(df_scraped) <- stringr::str_to_lower(colnames(df_scraped))
  organisation_col <- stringr::str_to_lower(organisation_col)

  if (!organisation_col %in% colnames(df_scraped)) {
    stop("The scraped data must contain the configured organisation column.", call. = FALSE)
  }

  names(df_scraped)[names(df_scraped) == organisation_col] <- "organisation"

  match_lookup <- organisation_matches |>
    dplyr::select(
      "organisation",
      "gerit_ID",
      "gerit_organisation",
      "gerit_cleaned",
      dplyr::any_of(paste0("Fachgebiet_Gerit_", 1:6)),
      "Faechergruppen",
      dplyr::any_of("Faechergruppen_IDs"),
      "LUF_IDs",
      dplyr::any_of("LUF_Namen"),
      "matched",
      "match_type",
      "match_confidence",
      "match_reason",
      "needs_review"
    )

  long_matches <- df_scraped |>
    dplyr::mutate(
      scraped_row_id = dplyr::row_number(),
      organisation = as.character(.data$organisation),
      organisation_piece = purrr::map(.data$organisation, split_orgs_or_na)
    ) |>
    tidyr::unnest_longer(.data$organisation_piece, values_to = "organisation_piece") |>
    dplyr::left_join(
      match_lookup,
      by = c("organisation_piece" = "organisation")
    )

  aggregated_matches <- long_matches |>
    dplyr::group_by(.data$scraped_row_id) |>
    dplyr::summarise(
      gerit_ID = collapse_unique(as.character(.data$gerit_ID)),
      gerit_organisation = collapse_unique(.data$gerit_organisation),
      Fachgebiet_Gerit_1 = collapse_unique(.data$Fachgebiet_Gerit_1),
      Fachgebiet_Gerit_2 = collapse_unique(.data$Fachgebiet_Gerit_2),
      Fachgebiet_Gerit_3 = collapse_unique(.data$Fachgebiet_Gerit_3),
      Fachgebiet_Gerit_4 = collapse_unique(.data$Fachgebiet_Gerit_4),
      Fachgebiet_Gerit_5 = collapse_unique(.data$Fachgebiet_Gerit_5),
      Fachgebiet_Gerit_6 = collapse_unique(.data$Fachgebiet_Gerit_6),
      Faechergruppen = collapse_unique(.data$Faechergruppen, sep = "|"),
      Faechergruppen_IDs = collapse_unique(.data$Faechergruppen_IDs, sep = "|"),
      LUF_IDs = collapse_unique(.data$LUF_IDs, sep = "|"),
      LUF_Namen = collapse_unique(.data$LUF_Namen, sep = "|"),
      matched_components = sum(.data$matched == "yes", na.rm = TRUE),
      total_components = dplyr::n(),
      matched = dplyr::case_when(
        .data$matched_components == .data$total_components & .data$total_components > 0 ~ "yes",
        .data$matched_components > 0 ~ "partial",
        TRUE ~ "no"
      ),
      match_type = collapse_unique(.data$match_type),
      match_confidence = if (all(is.na(.data$match_confidence))) NA_real_ else min(.data$match_confidence, na.rm = TRUE),
      match_reason = collapse_unique(.data$match_reason),
      needs_review = any(.data$needs_review, na.rm = TRUE) || any(.data$matched != "yes", na.rm = TRUE),
      .groups = "drop"
    )

  df_scraped |>
    dplyr::mutate(
      scraped_row_id = dplyr::row_number(),
      organisation = as.character(.data$organisation)
    ) |>
    dplyr::left_join(aggregated_matches, by = "scraped_row_id") |>
    dplyr::select(-.data$scraped_row_id)
}
