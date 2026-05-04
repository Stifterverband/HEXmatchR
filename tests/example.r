library(tidyverse)
remotes::install_github("Stifterverband/HEXmatchR")
library(HEXmatchR)

df_scraped <- read_rds("data/test_data_universitaet_fam.rds")

df_sample <- df_scraped |>
  dplyr::sample_n(size = 50)

workflow_result <- run_matching_workflow(
  name_gerit = "Johann Wolfgang Goethe-Universität Frankfurt am Main",
  df_scraped = df_sample,
  gold_data = "data/db_data_universitaet_fam.rds",
  model = "gpt-4.1-mini",
  top_k = 5,
  embedding_model = "text-embedding-3-large",
  output_dir = "matching-output-sample"
)

mismatches <- check_mismatches(workflow_result)
View(mismatches)