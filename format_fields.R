library(tidyverse)

#Smoking initiation (123,890 ever smoked vs 151,706 never smoked) was inferred
#using answers from questionnaire. Never smokers are those individuals who do
#not smoke at present and never smoked in the past [code 1239=0 & 1249=4] or do
#not smoke at present, smoked occasionally or just tried once or twice in the
#past, but had less than 100 smokes in their lifetime [1239=0 &1249=2/3 &
#2644=0]. Ever smokers include current smokers (who smoke at present, on most or
#all days or occasionally [1239=1/2]), previous smokers (who do not smoke at
#present and smoked on most or all days in the past [1239=0 &1249=1] or do not
#smoke at present, smoked occasionally or just tried once or twice in the past,
#and had more than 100 smokes in their lifetime [1239=0 &1249=2/3 & 2644=1]) and
#individuals who smoked on most/all days or occasionally in the past, and smoked
#more than 100 times in their life, but prefer not to answer about current
#smoking [1239=-3 & 1249=1 or 1239=-3 & 1249=2 & 2644=1].

rap_data <- read_csv("RAP_extracted_data.csv") %>%
  mutate(EVERSMK = NA,
         EVERSMK = ifelse(
           (p1239_i0 == 0 & p1249_i0 == 4) |
             (p1239_i0 == 0 & p1249_i0 %in% c(2, 3) & p2644_i0 == 0),
           0, EVERSMK),
         EVERSMK = ifelse(
           p1239_i0 %in% c(1, 2) |
             (p1239_i0 == 0 & p1249_i0 == 1) | 
             (p1239_i0 == 0 & p1249_i0 %in% c(2,3) & p2644_i0 == 1) |
             (p1239_i0 == -3 & (p1249_i0 == 1 | (p1249_i0 == 2 & p2644_i0 == 1))),
           1, EVERSMK))

field_names <- read_tsv("RAP_LF_fields_colnames.txt",
                        col_names = c("FIELD_ID", "FIELD_DESC", "FIELD_NAME")) 

names(rap_data) <- rap_data %>%
  names %>%
  as_tibble_col(column_name = 'FIELD_ID') %>%
  inner_join(field_names) %>%
  pull(FIELD_NAME) %>%
  c(., "EVERSMK")

write_csv(rap_data, "lung_function_data.csv")
