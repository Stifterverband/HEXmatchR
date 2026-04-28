# remotes::install_git("http://srv-data01:30080/hex/hex-gerit/HEXmatchR")
library(HEXmatchR)
library(readr)
library(dplyr)
devtools::load_all()

df_scraped <- read_rds("data/test_data_universitaet_fam.rds")

set.seed(123)
df_sample <- df_scraped |>
  dplyr::sample_n(size = 200)

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

glimpse(mismatches)
