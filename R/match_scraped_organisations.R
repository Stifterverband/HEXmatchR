#' Gescrapte Organisationen mit GERIT-Einrichtungen matchen
#'
#' Orchestriert die vollständige Matching-Pipeline: extrahiert eindeutige
#' Werte aus der gescrapten Spalte `organisation`, matched sie gegen
#' `Einrichtung` aus den vorbereiteten GERIT-Daten, generiert
#' Embedding-Kandidaten, führt LLM-basiertes Matching durch und fügt die
#' Ergebnisse in die ursprünglichen gescrapten Daten ein.
#'
#' @param df_scraped Gescrapter Kursdaten-Data-Frame.
#' @param df_gerit Vorbereitete GERIT-Daten aus [prepare_gerit_data()].
#' @param organisation_col Spalte in `df_scraped` mit den Organisationsnamen.
#' @param year_col Spalte in `df_scraped` mit der Jahresangabe.
#' @param semester_col Spalte in `df_scraped` mit der Semesterangabe.
#' @param model OpenAI-Modell für `ellmer::chat_openai()`.
#' @param top_k Anzahl der GERIT-Kandidaten, die pro Organisation an das
#'   LLM übergeben werden.
#' @param embedding_model OpenAI-Embedding-Modell für den Kandidatenabruf.
#' @param embedding_batch_size Batch-Größe für Embedding-Anfragen.
#' @param review_confidence Unterer Schwellenwert, unterhalb dessen ein
#'   Fall zur Review weitergeleitet wird.
#'
#' @details
#' Der in den Kandidaten enthaltene `score` stammt aus dem Embedding-
#' Retrieval und dient nur dazu, Kandidaten nach semantischer Aehnlichkeit
#' zu sortieren. Die finale Match-Entscheidung trifft das LLM im Schritt
#' [match_organisations_with_llm()] auf Basis der Kandidatenliste,
#' Bezeichnungen und des Prompts.
#'
#' Unsicherheit wird in der Praxis ueber `review_confidence` gesteuert:
#' Entscheidungen unterhalb des Schwellenwerts (oder ohne Konfidenz) werden
#' als Review-Faelle markiert.
#'
#' @return Eine Liste mit den Elementen:
#'   \describe{
#'     \item{`organisation_matches`}{Organisationsebene-Tibble mit allen
#'       befüllten Match-Spalten.}
#'     \item{`candidates`}{Kandidaten-Tibble aus dem Embedding-Retrieval.}
#'     \item{`llm_decisions`}{Rohe LLM-Entscheidungen als Tibble.}
#'     \item{`df_scraped_matched`}{Vollständiger gescrapter Data Frame mit
#'       zurückgefügten Match-Spalten.}
#'   }
#'
#' @export
match_scraped_organisations <- function(
  df_scraped,
  df_gerit,
  organisation_col = "organisation",
  year_col = "jahr",
  semester_col = "semester",
  model = "gpt-4.1-mini",
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  embedding_batch_size = 100,
  review_confidence = 0.65
) {
  organisation_tbl <- extract_scraped_organisations(
    df_scraped = df_scraped,
    organisation_col = organisation_col,
    year_col = year_col,
    semester_col = semester_col
  )
  message(
    "Organisationen extrahiert: ", nrow(organisation_tbl),
    " eindeutige Werte aus der Scraping-Spalte `organisation`."
  )

  organisation_tbl <- apply_deterministic_matches(
    df_scraped = organisation_tbl,
    candidate_tbl = NULL,
    df_gerit = df_gerit
  )

  candidate_tbl <- generate_embedding_candidates(
    df_scraped = organisation_tbl,
    df_gerit = df_gerit,
    top_k = top_k,
    embedding_model = embedding_model,
    batch_size = embedding_batch_size
  )

  llm_result <- match_organisations_with_llm(
    df_scraped = organisation_tbl,
    candidate_tbl = candidate_tbl,
    df_gerit = df_gerit,
    model = model,
    review_confidence = review_confidence
  )

  message(
    "Matching-Zwischenstand: ",
    sum(llm_result$scraped$matched == "yes", na.rm = TRUE), " gematcht, ",
    sum(llm_result$scraped$needs_review, na.rm = TRUE), " in Review, ",
    sum(llm_result$scraped$matched == "no", na.rm = TRUE), " offen."
  )

  df_scraped_matched <- join_matches_back_to_scraped(
    df_scraped = df_scraped,
    organisation_matches = llm_result$scraped,
    organisation_col = organisation_col
  )

  list(
    organisation_matches = llm_result$scraped,
    candidates = candidate_tbl,
    llm_decisions = llm_result$decisions,
    df_scraped_matched = df_scraped_matched
  )
}
