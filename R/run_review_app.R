
#' Shiny-Review-App starten
#'
#' Startet eine interaktive Shiny-Anwendung, die jeden Review-Fall einzeln
#' präsentiert. Der Reviewer kann einen GERIT-Kandidaten wählen, den Fall
#' als kein Match markieren oder überspringen. Die App schließt sich, wenn
#' der Reviewer auf "Fertig"
#' klickt, und gibt die ausgefüllte Entscheidungstabelle zurück.
#' Benötigt die Pakete `shiny` und `DT`.
#'
#' @param review_cases Ausgabe von [prepare_review_cases()].
#' @param df_gerit Vorbereitete GERIT-Daten aus [prepare_gerit_data()].
#' @param reviewed_by Optionaler Reviewer-Name, der in der Spalte
#'   `reviewed_by` der zurückgegebenen Entscheidungstabelle gespeichert
#'   wird.
#'
#' @return Eine Liste mit dem Element `decisions`: ein Tibble mit je einer
#'   Zeile pro reviewtem Fall und den Spalten `scraped_ID`, `organisation`,
#'   `review_decision`, `selected_gerit_id`, `review_comment`,
#'   `reviewed_at` und `reviewed_by`.
#'
#' @export
run_review_app <- function(review_cases, df_gerit, reviewed_by = current_username()) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Package `shiny` is required for `run_review_app()`.", call. = FALSE)
  }
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("Package `DT` is required for `run_review_app()`.", call. = FALSE)
  }

  review_tbl <- tibble::as_tibble(review_cases$review_cases)
  candidate_tbl <- tibble::as_tibble(review_cases$candidate_choices)
  decisions_tbl <- tibble::as_tibble(review_cases$decisions)

  ui <- shiny::fluidPage(
    shiny::titlePanel("HEXmatchR Review"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::verbatimTextOutput("case_status"),
        shiny::radioButtons(
          "review_decision",
          "Entscheidung",
          choiceNames = list(
            "GERIT-Kandidaten waehlen",
            "Kein Match",
            "Ueberspringen"
          ),
          choiceValues = c(
            "select_other_candidate",
            "mark_no_match",
            "skip"
          )
        ),
        shiny::uiOutput("candidate_selector_ui"),
        shiny::actionButton("save_next", "Speichern und weiter"),
        shiny::actionButton("previous_case", "Zurueck"),
        shiny::actionButton("next_case", "Weiter"),
        shiny::actionButton("done_review", "Fertig")
      ),
      shiny::mainPanel(
        shiny::h4("Aktueller Fall"),
        shiny::tableOutput("current_case_tbl"),
        shiny::h4("Top-K-Kandidaten"),
        DT::dataTableOutput("candidate_table"),
        shiny::h4("Bisherige Entscheidungen"),
        DT::dataTableOutput("decision_table")
      )
    )
  )

  server <- function(input, output, session) {
    current_index <- shiny::reactiveVal(1L)
    decisions_rv <- shiny::reactiveVal(decisions_tbl)

    current_case <- shiny::reactive({
      review_tbl[current_index(), , drop = FALSE]
    })

    current_candidates <- shiny::reactive({
      candidate_tbl |>
        dplyr::filter(.data$scraped_ID == current_case()$scraped_ID[[1]])
    })

    current_decision_row <- shiny::reactive({
      decisions_rv() |>
        dplyr::filter(.data$scraped_ID == current_case()$scraped_ID[[1]]) |>
        dplyr::slice(1)
    })

    output$case_status <- shiny::renderText({
      paste(
        "Fall", current_index(), "von", nrow(review_tbl), "\n",
        "Fachgruppe Scraping:", current_case()$organisation[[1]]
      )
    })

    output$current_case_tbl <- shiny::renderTable({
      top_candidate <- current_candidates() |>
        dplyr::arrange(dplyr::desc(.data$score), .data$candidate_rank) |>
        dplyr::slice(1)

      current_case() |>
        dplyr::transmute(
          scraping_orga = .data$organisation,
          gerit_orga = dplyr::coalesce(top_candidate$Einrichtung[[1]] %||% NA_character_, .data$gerit_organisation),
          score = dplyr::coalesce(top_candidate$score[[1]] %||% NA_real_, .data$match_confidence)
        )
    }, rownames = FALSE)

    output$candidate_table <- DT::renderDataTable({
      current_candidates() |>
        dplyr::select(
          "candidate_rank",
          "Einrichtung",
          "score"
        )
    }, options = list(pageLength = 10, scrollX = TRUE))

    output$decision_table <- DT::renderDataTable({
      decisions_rv() |>
        dplyr::filter(!is.na(.data$review_decision)) |>
        dplyr::transmute(
          scraped_ID = .data$scraped_ID,
          scraping_orga = .data$organisation,
          review_decision = .data$review_decision,
          selected_gerit_id = .data$selected_gerit_id,
          reviewed_at = .data$reviewed_at,
          reviewed_by = .data$reviewed_by
        )
    }, options = list(pageLength = 10, scrollX = TRUE))

    output$candidate_selector_ui <- shiny::renderUI({
      if (!identical(input$review_decision, "select_other_candidate")) {
        return(NULL)
      }

      choices <- current_candidates() |>
        dplyr::transmute(value = as.character(.data$gerit_ID), label = .data$candidate_label)

      shiny::selectInput(
        "selected_candidate",
        "GERIT-Kandidaten waehlen",
        choices = stats::setNames(choices$value, choices$label)
      )
    })

    sync_current_decision <- function() {
      decisions_now <- decisions_rv()
      row_id <- match(current_case()$scraped_ID[[1]], decisions_now$scraped_ID)

      decisions_now[row_id, ] <- tibble::tibble(
        scraped_ID = current_case()$scraped_ID[[1]],
        organisation = current_case()$organisation[[1]],
        review_decision = input$review_decision,
        selected_gerit_id = safe_integer(input$selected_candidate),
        review_comment = NA_character_,
        reviewed_at = Sys.time(),
        reviewed_by = reviewed_by %||% NA_character_
      )

      decisions_rv(decisions_now)
    }

    save_current_decision <- function(move_next = FALSE) {
      sync_current_decision()

      if (move_next) {
        if (current_index() < nrow(review_tbl)) {
          current_index(current_index() + 1L)
        } else {
          shiny::stopApp(list(decisions = decisions_rv()))
        }
      }
    }

    shiny::observe({
      decision_row <- current_decision_row()

      shiny::updateRadioButtons(
        session,
        "review_decision",
        selected = decision_row$review_decision[[1]] %||% "select_other_candidate"
      )
    })

    shiny::observe({
      if (!identical(input$review_decision, "select_other_candidate")) {
        return()
      }

      selected_candidate <- current_decision_row()$selected_gerit_id[[1]]
      if (is.na(selected_candidate)) {
        selected_candidate <- current_candidates()$gerit_ID[[1]] %||% NA_integer_
      }

      shiny::updateSelectInput(
        session,
        "selected_candidate",
        selected = as.character(selected_candidate)
      )
    })

    shiny::observeEvent(
      list(
        input$review_decision,
        input$selected_candidate
      ),
      {
        sync_current_decision()
      },
      ignoreInit = TRUE
    )

    shiny::observeEvent(input$save_next, {
      save_current_decision(move_next = TRUE)
    })

    shiny::observeEvent(input$previous_case, {
      sync_current_decision()
      if (current_index() > 1) {
        current_index(current_index() - 1L)
      }
    })

    shiny::observeEvent(input$next_case, {
      sync_current_decision()
      if (current_index() < nrow(review_tbl)) {
        current_index(current_index() + 1L)
      }
    })

    shiny::observeEvent(input$done_review, {
      save_current_decision(move_next = FALSE)
      shiny::stopApp(list(decisions = decisions_rv()))
    })
  }

  shiny::runApp(shiny::shinyApp(ui, server))
}
