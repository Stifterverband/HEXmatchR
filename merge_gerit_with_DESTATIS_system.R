# merge_gerit_with_DESTATIS_system.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readxl)
  library(stringr)
  library(tibble)
})

if (!exists("generate_ranked_embedding_candidates", mode = "function")) {
  source("R/utils.R")
}

devtools::load_all()

# 1. DESTATIS-Klassifikationsdaten laden ---------------------------------

Fachgebiet <- read.csv2(
  "data/Fachgebiet.csv",
  header = FALSE,
  fileEncoding = "Latin1",
  colClasses = "character"
) |>
  rename(
    Fachgebiet_ID = 1,
    unknown_ID = 2,
    Fachgebiet_name = 3,
    LUF_ID = 4
  ) |>
  as_tibble()

LUF <- read.csv2(
  "data/LUF.csv",
  header = FALSE,
  fileEncoding = "Latin1",
  colClasses = "character"
) |>
  rename(
    LUF_ID = 1,
    LUF_name = 2,
    Faechergruppe_ID = 3
  ) |>
  as_tibble()

Faechergruppe <- read.csv2(
  "data/Faechergruppe.csv",
  header = FALSE,
  fileEncoding = "Latin1",
  colClasses = "character"
) |>
  rename(Faechergruppe_ID = 1, Faechergruppe_name = 2) |>
  as_tibble()

# 2. GERIT-Daten laden ----------------------------------------------------

gerit_final_data <- read_excel(
  "data/gerit_final_data.xlsx",
  col_types = "text"
)

# 3. Normalisierung -------------------------------------------------------

normalize_fach <- function(x) {
  x |>
    str_squish() |>
    str_replace_all(",\\s+und", " und") |>
    str_replace_all(",\\s+oder", " oder") |>
    str_replace_all("\\ballgemein\\b", " ") |>
    str_replace_all("\\[.*?\\]", " ") |>
    str_replace_all("[./-]", " ") |>
    str_replace_all("\\s+", " ") |>
    str_trim() |>
    tolower()
}

collapse_nonempty <- function(x, sep = "|") {
  values <- unique(stats::na.omit(as.character(x)))
  values <- values[values != ""]
  if (length(values) == 0) {
    return(NA_character_)
  }
  paste(sort(values), collapse = sep)
}

find_top_candidates <- function(
  unmatched_tbl,
  fachgebiet_tbl,
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  batch_size = 100
) {
  fachgebiet_lookup <- fachgebiet_tbl |>
    distinct(Fachgebiet_name, Fachgebiet_name_norm, LUF_ID, Faechergruppe_ID) |>
    mutate(
      Fachgebiet_name_destatis = Fachgebiet_name,
      embedding_text = purrr::map2_chr(
        Fachgebiet_name,
        Fachgebiet_name_norm,
        build_named_embedding_text
      )
    )

  unmatched_lookup <- unmatched_tbl |>
    mutate(
      Fachgebiet_name_query = Fachgebiet_name,
      embedding_text = purrr::map2_chr(
        Fachgebiet_name,
        Fachgebiet_name_norm,
        build_named_embedding_text
      )
    )

  generate_ranked_embedding_candidates(
    query_tbl = unmatched_lookup,
    candidate_tbl = fachgebiet_lookup,
    query_id_col = "Fachgebiet_name_norm",
    candidate_id_col = "LUF_ID",
    query_keep_cols = "Fachgebiet_name_query",
    candidate_keep_cols = c("Fachgebiet_name_destatis", "Faechergruppe_ID"),
    top_k = top_k,
    embedding_model = embedding_model,
    batch_size = batch_size,
    query_label = "GERIT-Fachnamen",
    candidate_label = "DESTATIS-Fachgebiete",
    ranking_label = "Kandidatenranking laeuft.",
    empty_message = "Keine offenen Fachnamen mehr fuer Embedding-Retrieval.",
    start_message = paste0(
      "Embedding-Retrieval: ", nrow(unmatched_lookup), " offene Fachnamen, ",
      nrow(fachgebiet_lookup), " DESTATIS-Fachgebiete, top_", top_k, "."
    ),
    candidate_source = "embedding",
    candidate_tiebreak_cols = "Fachgebiet_name_destatis"
  )
}

match_with_llm <- function(candidate_tbl, model = "gpt-4.1-mini") {
  if (nrow(candidate_tbl) == 0) {
    return(tibble())
  }

  query_tbl <- candidate_tbl |>
    distinct(Fachgebiet_name_norm, Fachgebiet_name_query)

  request_llm_candidate_decisions(
    query_tbl = query_tbl,
    candidate_tbl = candidate_tbl,
    query_id_col = "Fachgebiet_name_norm",
    candidate_group_col = "Fachgebiet_name_norm",
    model = model,
    system_prompt = paste(
      "You match German academic subject labels from GERIT to DESTATIS labels.",
      "Be conservative and return structured data only."
    ),
    prompt_builder = function(current_query, current_candidates) {
      candidate_text <- current_candidates |>
        mutate(
          line = paste0(
            candidate_rank, ". LUF_ID=", LUF_ID,
            " | Fachgebiet=", Fachgebiet_name_destatis,
            " | score=", format(round(score, 3), nsmall = 3)
          )
        ) |>
        pull(line) |>
        paste(collapse = "\n")

      paste(
        "Ordne einen GERIT-Fachnamen dem besten DESTATIS-Fachgebiet zu.",
        "Waehle `select_candidate`, wenn genau einer der Kandidaten gut passt.",
        "Waehle `no_match`, wenn keiner der Kandidaten belastbar passt.",
        "Nutze nur die angegebenen Kandidaten.",
        "Wenn du `select_candidate` waehlst, setze `selected_candidate_id` exakt auf die `LUF_ID` eines Kandidaten.",
        "Setze immer `confidence` auf einen Wert zwischen 0 und 1.",
        "Setze immer `reason` auf eine kurze Begruendung.",
        "Setze `needs_review` auf TRUE, wenn der Fall unsicher ist, sonst FALSE.",
        "",
        paste0("GERIT_Fachname: ", current_query$Fachgebiet_name_query[[1]]),
        paste0("GERIT_Fachname_normalisiert: ", current_query$Fachgebiet_name_norm[[1]]),
        "",
        "DESTATIS-Kandidaten:",
        candidate_text
      )
    },
    no_candidate_reason = "No ranked DESTATIS candidates were generated.",
    progress_message = paste0(
      "LLM-Matching: ", nrow(query_tbl), " offene Fachnamen mit Modell `",
      model, "`."
    ),
    progress_label = "LLM-Klassifikation laeuft."
  ) |>
    transmute(
      Fachgebiet_name_norm = .data$query_id,
      decision = .data$decision,
      selected_luf_id = .data$selected_candidate_id,
      confidence = .data$confidence,
      reason = .data$reason
    )
}

Fachgebiet <- Fachgebiet |>
  mutate(
    LUF_ID = stringr::str_pad(LUF_ID, width = 3, side = "left", pad = "0"),
    Fachgebiet_name_norm = normalize_fach(Fachgebiet_name)
  ) |>
  left_join(
    LUF |>
      select(LUF_ID, LUF_name, Faechergruppe_ID) |>
      distinct(),
    by = "LUF_ID"
  )

# 4. GERIT von Wide nach Long pivotieren ---------------------------------

gerit_long <- gerit_final_data |>
  pivot_longer(
    cols = starts_with("Einrichtung_Fach_"),
    names_to = "Fach_Nr",
    values_to = "Fachgebiet_name"
  ) |>
  filter(!is.na(Fachgebiet_name)) |>
  mutate(
    Fachgebiet_name = str_squish(Fachgebiet_name),
    Fachgebiet_name_mapped = Fachgebiet_name,
    Fachgebiet_name_norm = normalize_fach(Fachgebiet_name)
  )

# 5. Matching: erst exakt, dann Embeddings + LLM fuer Rest ----------------

gerit_with_fachgebiet <- gerit_long |>
  left_join(
    Fachgebiet,
    by = "Fachgebiet_name_norm",
    relationship = "many-to-many"
  ) |>
  rename(
    Fachgebiet_name = Fachgebiet_name.x,
    Fachgebiet_name_destatis = Fachgebiet_name.y
  )

unmatched_gerit <- gerit_with_fachgebiet |>
  filter(is.na(LUF_ID)) |>
  distinct(Fachgebiet_name, Fachgebiet_name_norm)

if (nrow(unmatched_gerit) > 0) {
  message("Ergaenze ", nrow(unmatched_gerit), " Fachnamen via Embeddings + LLM.")

  embedding_candidates <- find_top_candidates(
    unmatched_tbl = unmatched_gerit,
    fachgebiet_tbl = Fachgebiet,
    top_k = 5
  )

  llm_decisions <- match_with_llm(embedding_candidates)

  llm_matches <- llm_decisions |>
    filter(decision == "select_candidate", !is.na(selected_luf_id)) |>
    left_join(
      embedding_candidates |>
        select(
          Fachgebiet_name_norm,
          Fachgebiet_name_query,
          LUF_ID,
          Faechergruppe_ID,
          Fachgebiet_name_destatis,
          score
        ) |>
        distinct(),
      by = c(
        "Fachgebiet_name_norm",
        "selected_luf_id" = "LUF_ID"
      )
    ) |>
    transmute(
      Fachgebiet_name_norm = .data$Fachgebiet_name_norm,
      LUF_ID_llm = selected_luf_id,
      Faechergruppe_ID_llm = Faechergruppe_ID,
      Fachgebiet_name_destatis_llm = Fachgebiet_name_destatis,
      llm_score = score,
      llm_confidence = confidence,
      llm_reason = reason
    )

  gerit_with_fachgebiet <- gerit_with_fachgebiet |>
    left_join(llm_matches, by = "Fachgebiet_name_norm") |>
    mutate(
      LUF_ID = coalesce(LUF_ID, LUF_ID_llm),
      Faechergruppe_ID = coalesce(Faechergruppe_ID, Faechergruppe_ID_llm),
      Fachgebiet_name_destatis = coalesce(Fachgebiet_name_destatis, Fachgebiet_name_destatis_llm)
    ) |>
    select(
      -LUF_ID_llm,
      -Faechergruppe_ID_llm,
      -Fachgebiet_name_destatis_llm
    )
} else {
  embedding_candidates <- tibble()
  llm_decisions <- tibble()
}

# 6. LUF- und Faechergruppen-Namen ergaenzen ------------------------------

gerit_with_fachgebiet <- gerit_with_fachgebiet |>
  left_join(
    LUF |>
      select(LUF_ID, LUF_name, Faechergruppe_ID) |>
      distinct(),
    by = "LUF_ID",
    suffix = c("", "_from_luf")
  ) |>
  mutate(
    LUF_name = coalesce(na_if(LUF_name, ""), LUF_name_from_luf),
    Faechergruppe_ID = coalesce(Faechergruppe_ID, Faechergruppe_ID_from_luf)
  ) |>
  select(-LUF_name_from_luf, -Faechergruppe_ID_from_luf) |>
  left_join(Faechergruppe, by = "Faechergruppe_ID")

# 7. Diagnose -------------------------------------------------------------

still_unmatched <- gerit_with_fachgebiet |>
  filter(is.na(LUF_ID)) |>
  distinct(Fachgebiet_name) |>
  arrange(Fachgebiet_name)

if (nrow(still_unmatched) > 0) {
  message("Nicht gematchte Fachnamen: ", nrow(still_unmatched))
  print(still_unmatched, n = Inf)
} else {
  message("Alle Faecher erfolgreich gematcht.")
}

multi_luf <- gerit_with_fachgebiet |>
  filter(!is.na(LUF_ID)) |>
  group_by(Einrichtung, Einrichtung_url, HS) |>
  summarise(
    n_LUFs = n_distinct(LUF_ID),
    LUF_IDs = collapse_nonempty(LUF_ID),
    LUF_Namen = collapse_nonempty(LUF_name, sep = "; "),
    .groups = "drop"
  )

message("Nur einem LUF zugehoerig: ", sum(multi_luf$n_LUFs == 1))
message("Mehr als einem LUF zugehoerig: ", sum(multi_luf$n_LUFs > 1))

# 8. Ergebnisobjekt -------------------------------------------------------

gerit_fachgebiet_long <- gerit_with_fachgebiet |>
  select(
    Einrichtung,
    Einrichtung_url,
    HS,
    path,
    Fach_Nr,
    Fachgebiet_name,
    Fachgebiet_name_mapped,
    Fachgebiet_name_destatis,
    LUF_ID,
    LUF_name,
    Faechergruppe_ID,
    Faechergruppe_name
  )

gerit_fachgebiet_wide <- gerit_fachgebiet_long |>
  group_by(Einrichtung, Einrichtung_url, HS, path) |>
  summarise(
    LUF_IDs = collapse_nonempty(LUF_ID),
    LUF_Namen = collapse_nonempty(LUF_name, sep = "; "),
    Faechergruppen_IDs = collapse_nonempty(Faechergruppe_ID),
    Faechergruppen = collapse_nonempty(Faechergruppe_name, sep = "; "),
    .groups = "drop"
  )

fach_cols <- paste0("Einrichtung_Fach_", 1:6)
missing_fach_cols <- setdiff(fach_cols, names(gerit_final_data))
for (missing_col in missing_fach_cols) {
  gerit_final_data[[missing_col]] <- NA_character_
}

gerit_destatis_data <- gerit_final_data |>
  left_join(
    gerit_fachgebiet_wide,
    by = intersect(c("Einrichtung", "Einrichtung_url", "HS", "path"), names(gerit_final_data))
  ) |>
  transmute(
    Hochschul_Name = .data$HS,
    Gerit_Orga = .data$Einrichtung,
    Fachgebiet_Gerit_1 = .data$Einrichtung_Fach_1,
    Fachgebiet_Gerit_2 = .data$Einrichtung_Fach_2,
    Fachgebiet_Gerit_3 = .data$Einrichtung_Fach_3,
    Fachgebiet_Gerit_4 = .data$Einrichtung_Fach_4,
    Fachgebiet_Gerit_5 = .data$Einrichtung_Fach_5,
    Fachgebiet_Gerit_6 = .data$Einrichtung_Fach_6,
    LUF_IDs = .data$LUF_IDs,
    LUF_Namen = .data$LUF_Namen,
    Faechergruppen_IDs = .data$Faechergruppen_IDs,
    Faechergruppen = .data$Faechergruppen
  )

message("gerit_fachgebiet_long: ", nrow(gerit_fachgebiet_long), " Zeilen")
message("gerit_destatis_data: ", nrow(gerit_destatis_data), " Zeilen")

library(readr)
write_rds(gerit_destatis_data, "data/GERIT_DESTATIS_data.rds")
