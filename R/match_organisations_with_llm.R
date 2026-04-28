#' Fachgebiete per LLM (OpenAI via ellmer) matchen
#'
#' Erstellt fuer jedes noch nicht gematchte gescrapte Fachgebiet einen
#' strukturierten Prompt aus den top-k Kandidaten und befragt das
#' LLM nach dem besten Treffer oder keinem Match. Review-Faelle werden nur
#' fuer wirklich unsichere Entscheidungen markiert: bei fehlender Konfidenz
#' oder unter `review_confidence`.
#'
#' @param df_scraped Ausgabe von [extract_scraped_organisations()] nachdem
#'   deterministische Matches angewendet wurden.
#' @param candidate_tbl Ausgabe von [generate_embedding_candidates()].
#' @param df_gerit Ausgabe von [prepare_gerit_data()].
#' @param model OpenAI-Modellname fuer `ellmer::chat_openai()`.
#' @param review_confidence Numerischer Schwellenwert; LLM-Entscheidungen
#'   darunter werden fuer Review markiert.
#' @param temperature Numerischer Wert zwischen 0 und 1 fuer die
#'   Zufaelligkeit des LLM. Standard: 0 fuer deterministische Ausgaben.
#'
#' @details
#' Wie OpenAI hier die Match-Entscheidung trifft:
#' - Das Modell sieht pro Organisation nur die top-k Kandidaten aus dem
#'   Embedding-Retrieval (inklusive `embedding_score`).
#' - Es darf ausschliesslich zwischen zwei Entscheidungen waehlen:
#'   `select_candidate` oder `no_match`.
#' - Bei `select_candidate` muss `selected_candidate_id` exakt eine
#'   erlaubte `gerit_ID` aus der Kandidatenliste sein.
#' - Die Antwort wird ueber ein striktes JSON-Schema validiert, damit keine
#'   anderen Entscheidungswerte oder zusaetzlichen Felder auftreten.
#'
#' Wie Unsicherheit behandelt wird:
#' - Das Modell gibt eine `confidence` im Bereich \[0, 1\] zur eigenen
#'   Entscheidung an.
#' - Ein Fall wird als unsicher fuer Review markiert, wenn
#'   `confidence < review_confidence` oder `confidence` fehlt.
#' - Das vom Modell gelieferte Feld `needs_review` wird ebenfalls
#'   beruecksichtigt; die Pipeline setzt Review aber in jedem Fall, sobald
#'   die Konfidenz unter dem Schwellenwert liegt.
#' - `review_confidence` ist damit der praktische Punkt, ab dem die
#'   automatische Entscheidung als nicht ausreichend sicher gilt.
#'
#' @return Eine Liste mit den Elementen:
#'   \describe{
#'     \item{`scraped`}{Aktualisiertes Fachgebiets-Tibble mit
#'       eingetragenen LLM-Matches.}
#'     \item{`decisions`}{Tibble der rohen LLM-Entscheidungen, eine Zeile
#'       pro verarbeitetem Fachgebiet.}
#'   }
#'
#' @export
match_organisations_with_llm <- function(
  df_scraped,
  candidate_tbl,
  df_gerit,
  model = "gpt-4.1-mini",
  review_confidence = 0.65,
  temperature = 0
) {

  # ---------------------------------------------------------------------------
  # JSON-Schema fuer strukturierte OpenAI-Ausgaben.
  # Mit `strict = TRUE` und `additionalProperties = FALSE` kann das Modell
  # keine unerwarteten Felder oder Entscheidungswerte produzieren.
  # ---------------------------------------------------------------------------
  response_format <- list(
    type = "json_schema",
    json_schema = list(
      name   = "org_match",
      strict = TRUE,
      schema = list(
        type = "object",
        properties = list(
          decision = list(
            type = "string",
            enum = list("select_candidate", "no_match"),
            description = "Entweder 'select_candidate' wenn ein Kandidat klar passt, oder 'no_match'."
          ),
          selected_candidate_id = list(
            type        = c("integer", "null"),
            description = "Die gerit_id des ausgewaehlten Kandidaten. Nur bei 'select_candidate' belegt, sonst null."
          ),
          confidence = list(
            type        = "number",
            minimum     = 0,
            maximum     = 1,
            description = "Zuversicht in die Entscheidung (0-1)."
          ),
          reason = list(
            type        = "string",
            description = "Kurze Begruendung der Entscheidung."
          ),
          needs_review = list(
            type        = "boolean",
            description = "Ob der Fall manuell geprueft werden sollte."
          )
        ),
        required             = list("decision", "selected_candidate_id", "confidence", "reason", "needs_review"),
        additionalProperties = FALSE
      )
    )
  )

  # ---------------------------------------------------------------------------
  # Baut den deutschsprachigen Prompt fuer ein Fachgebiet und seine Kandidaten.
  # Die erlaubten GERIT-IDs werden explizit aufgelistet, damit das Modell keine
  # Halluzinationen ausserhalb des vorgegebenen Kandidatensets produziert.
  # ---------------------------------------------------------------------------
  build_prompt <- function(org_row, candidates) {
    extra_lines <- character()

    if ("no_courses" %in% names(org_row)) {
      extra_lines <- c(extra_lines, paste0("Anzahl Kurse: ", org_row$no_courses[[1]]))
    }

    # Explizite Whitelist der erlaubten IDs
    valid_ids <- paste(candidates$gerit_ID, collapse = ", ")

    candidate_text <- candidates |>
      dplyr::mutate(
        zeile = paste0(
          "- gerit_id=", .data$gerit_ID,
          " | einrichtung=", .data$Einrichtung,
          " | embedding_score=", format(round(.data$score, 3), nsmall = 3)
        )
      ) |>
      dplyr::pull(.data$zeile) |>
      paste(collapse = "\n")

    paste(
      "Ordne das gescrapte Fachgebiet genau einem passenden DESTATIS-Fachgebiet zu.",
      "Waehle 'select_candidate', wenn ein Kandidat klar und belastbar passt.",
      "Waehle 'no_match', wenn kein Kandidat belastbar passt.",
      "",
      paste0("Erlaubte gerit_id-Werte: ", valid_ids),
      "Jede andere ID ist ungueltig. Waehle in diesem Fall 'no_match'.",
      "",
      "Setze 'selected_candidate_id' exakt auf eine der obigen erlaubten gerit_id-Werte,",
      "oder auf null wenn du 'no_match' waehlst.",
      "",
      "Kalibriere 'confidence' anhand dieser Beispiele:",
      "- 0.95: Bezeichnung ist identisch oder nur orthografisch abweichend (z.B. 'Informatik' = 'Informatik (B.Sc.)')",
      "- 0.75: Klare inhaltliche Ueberschneidung, aber unterschiedliche Granularitaet (z.B. 'Wirtschaftsinformatik' vs. 'Informationsmanagement')",
      "- 0.45: Verwandtes Oberfach, aber kein eindeutiger Treffer (z.B. 'Ingenieurwissenschaften' vs. 'Maschinenbau')",
      "- 0.10: Thematisch unverwandt oder kein Kandidat inhaltlich passend",
      "",
      paste0("Fachgebiet: ", org_row$organisation[[1]]),
      paste0("Bereinigtes Fachgebiet: ", org_row$cleaned[[1]]),
      extra_lines,
      "",
      "DESTATIS-Kandidaten:",
      candidate_text
    )
  }

  # ---------------------------------------------------------------------------
  # Leitet nur aus der Konfidenz ab, ob ein Fall in die Review soll.
  # ---------------------------------------------------------------------------
  resolve_review_flag <- function(needs_review, confidence) {
    is.na(confidence) ||
      (!is.na(confidence) && confidence < review_confidence)
  }

  # ---------------------------------------------------------------------------
  # Uebersetzt eine einzelne LLM-Entscheidung in einen Match-Record.
  # ---------------------------------------------------------------------------
  build_llm_record <- function(decision_row) {
    candidate_ids <- candidate_tbl |>
      dplyr::filter(.data$scraped_ID == decision_row$scraped_ID[[1]]) |>
      dplyr::pull("gerit_ID")

    decision_final    <- decision_row$decision_final[[1]]
    selected_gerit_id <- decision_row$selected_gerit_id[[1]]
    confidence        <- decision_row$confidence[[1]]
    reason            <- decision_row$reason[[1]]
    review_flag       <- decision_row$review_flag[[1]]

    switch(
      decision_final,
      select_candidate = {
        if (!selected_gerit_id %in% candidate_ids) {
          not_match_record(
            "LLM hat eine GERIT-ID ausserhalb der Kandidatenmenge gewaehlt.",
            needs_review = TRUE
          )
        } else {
          lookup_match_from_gerit(
            df_gerit     = df_gerit,
            gerit_id     = selected_gerit_id,
            match_type   = "llm",
            confidence   = confidence,
            reason       = reason,
            needs_review = review_flag
          )
        }
      },
      no_match = not_match_record(reason, needs_review = review_flag),
      not_match_record("Unerwartete LLM-Entscheidung.", needs_review = TRUE)
    )
  }

  # ---------------------------------------------------------------------------
  # Ergaenzt fehlende LLM-Felder mit pragmatischen Fallbacks.
  # ---------------------------------------------------------------------------
  enrich_decisions <- function(decisions_tbl) {
    candidate_lookup <- candidate_tbl |>
      dplyr::select(.data$scraped_ID, .data$gerit_ID, .data$score) |>
      dplyr::rename(selected_gerit_id = .data$gerit_ID, candidate_score = .data$score)

    decisions_tbl |>
      dplyr::left_join(candidate_lookup, by = c("scraped_ID", "selected_gerit_id")) |>
      dplyr::mutate(
        confidence = dplyr::coalesce(.data$confidence, .data$candidate_score),
        reason = dplyr::if_else(
          .data$reason == "" & .data$decision == "select_candidate" & !is.na(.data$selected_gerit_id),
          "LLM hat nicht entschieden.",
          .data$reason
        ),
        reason = dplyr::if_else(
          .data$reason == "" & .data$decision == "no_match",
          "Kein passender Kandidat: Keiner der vorgelegten DESTATIS-Kandidaten passt inhaltlich belastbar zum Fachgebiet.",
          .data$reason
        )
      ) |>
      dplyr::select(-.data$candidate_score)
  }

  # ---------------------------------------------------------------------------
  # Hauptlogik: nur offene Fachgebiete verarbeiten.
  # ---------------------------------------------------------------------------
  remaining <- df_scraped |>
    dplyr::filter(.data$matched == "no")

  if (nrow(remaining) == 0) {
    message("LLM-Schritt uebersprungen: keine offenen Fachgebiete.")
    return(list(scraped = df_scraped, decisions = tibble::tibble()))
  }

  decisions <- request_llm_candidate_decisions(
    query_tbl         = remaining,
    candidate_tbl     = candidate_tbl,
    query_id_col      = "scraped_ID",
    candidate_group_col = "scraped_ID",
    model             = model,
    temperature       = temperature,
    response_format   = response_format,
    system_prompt     = paste(
      "Du ordnest gescrapte Fachgebiete passenden DESTATIS-Fachgebieten zu.",
      "Antworte ausschliesslich als strukturierte Daten gemaess dem vorgegebenen JSON-Schema.",
      "Nutze nur die vorgelegten Kandidaten und uebernimm ihre IDs exakt.",
      "Setze 'selected_candidate_id' immer auf null wenn du 'no_match' waehlst."
    ),
    prompt_builder      = build_prompt,
    no_candidate_reason = "Es wurden keine geeigneten GERIT-Kandidaten erzeugt.",
    progress_message    = paste0(
      "LLM-Matching: ", nrow(remaining), " offene Fachgebiete mit Modell `",
      model, "`."
    ),
    progress_label = "LLM-Klassifikation laeuft."
  ) |>
    dplyr::transmute(
      scraped_ID        = .data$query_id,
      decision          = .data$decision,
      selected_gerit_id = purrr::map_int(.data$selected_candidate_id, safe_integer),
      confidence        = .data$confidence,
      reason            = dplyr::coalesce(.data$reason, ""),
      needs_review      = .data$needs_review
    ) |>
    enrich_decisions() |>
    dplyr::mutate(
      review_flag = purrr::map2_lgl(.data$needs_review, .data$confidence, resolve_review_flag),
      decision_final = .data$decision
    )

  # ---------------------------------------------------------------------------
  # Entscheidungen in die Match-Tabelle zurueckschreiben.
  # ---------------------------------------------------------------------------
  df_scraped <- purrr::reduce(
    split(decisions, seq_len(nrow(decisions))),
    .init = df_scraped,
    .f = function(scraped_tbl, decision_row) {
      row_id <- match(decision_row$scraped_ID[[1]], scraped_tbl$scraped_ID)

      record <- tryCatch(
        build_llm_record(decision_row),
        error = \(err) {
          not_match_record(
            paste0("LLM-Entscheidung konnte nicht verarbeitet werden: ", conditionMessage(err)),
            needs_review = TRUE
          )
        }
      )

      apply_match_record(scraped_tbl, row_id, record)
    }
  )

  message(
    "LLM fertig: ",
    sum(df_scraped$matched == "yes", na.rm = TRUE), " gematcht, ",
    sum(df_scraped$needs_review, na.rm = TRUE), " in Review."
  )

  list(scraped = df_scraped, decisions = decisions)
}
