library(tidyverse)

lung.function <- read_csv("UKBB_spirometry_QC_blows_classified.csv")

LF_long <- lung.function %>%
  pivot_longer(all_of(matches(".+_[0-2]$")), names_to = c(".value", "blow"),
               names_pattern = "(.+)_([0-2])$")

#################################################################################

# For reproducibility another blow must be within 0.25ml of the maximum acceptable blow;
# the other blow does not have to be acceptable
repro <- function(x, acceptable, THRESHOLD=0.25) {
  max_acc <- max(x[acceptable])
  which_max_acc <- which(x == max_acc)[1]
  length(x) > 1 & any(round(abs(max_acc - x[-which_max_acc]), 10) <= THRESHOLD)
}

LF_best <- LF_long %>%
  mutate(acceptable = REJECT == 0 & biobank_derived_consistent == 0 & blow_points_ok == 0) %>%
  group_by(ID) %>%
  filter(any(acceptable)) %>%
  mutate(fev1_plus_fvc = ifelse(acceptable, round(fev1 + fvc, 10), NA)) %>%
  arrange(desc(fev1_plus_fvc), desc(pef)) %>% # ordering for pef selection
  summarise(across(c(fev1, fvc), list(best=~max(.[acceptable]), # Get maximum acceptable fev1 & fvc
                                      repro=~repro(., acceptable))), # check their reproducibility
            pass_LF_QC=fev1_repro & fvc_repro, # Blow passes QC if fev1 & fvc both pass reproducibility
            ratio_best=fev1_best/fvc_best,
            pef_best=pef[1]) %>% # select pef with highest fev1 + fvc; highest pef for ties
  filter(pass_LF_QC) %>% # Only keep blows passing QC
  select(ID, ends_with("_best")) %>%
  left_join(lung.function %>% select(ID, age_at_recruitment, sex, standing_height, EVERSMK), by="ID")

write_tsv(LF_best, "spirometry_new_QC_full_measures.txt")
