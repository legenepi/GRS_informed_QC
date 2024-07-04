library(tidyverse)

rap_data <- read_csv("RAP_extracted_data.csv")

field_names <- read_tsv("RAP_LF_fields_colnames.txt",
                        col_names = c("FIELD_ID", "FIELD_DESC", "FIELD_NAME")) 

names(rap_data) <- rap_data %>%
  names %>%
  as_tibble_col(column_name = 'FIELD_ID') %>%
  left_join(field_names) %>%
  pull(FIELD_NAME)

write_csv(rap_data, "lung_function_data.csv")
