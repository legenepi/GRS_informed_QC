library(tidyverse)

THRESHOLD <- "0.25"

lung.function_long <- read_csv("UKBB_spirometry_QC_blows_classified_long.csv")
lung.function <- fread("/data/gen1/Jing/spirometry_quality/UKBB_spirometry_QC_blows_classified_v4.csv") %>%
  as_tibble

withdraw <- scan("/data/gen1/Jing/spirometry_quality/V2/genetic_association/withdraw_list")
lung.function <- lung.function %>%
  filter(!ID %in% withdraw)

EUR <- read_delim("/data/gen1/UKBiobank_500K/used_for_transethnic_meta/ukb_kmeans_clusters.txt")
GLI_outlier <- scan("/data/gen1/Jing/spirometry_quality/GLI_outliers.txt")
LF_EUR <- lung.function %>%
  filter(!ID %in% GLI_outlier & ID %in% EUR$sample)

LF_EUR <- LF_EUR %>%
  select(c("ID", starts_with("fev1_"), starts_with("fvc_"), starts_with("pef."),
           starts_with("REJECT_"), starts_with("biobank_derived_consistent_"),
           starts_with("blow_points_ok_"))) %>%
  pivot_longer(-ID, names_to = c(".value", "blow"), names_pattern = "(.+)[_\\.]([0-2])$")


#################################################################################

LF_EUR_blows_passing <- LF_EUR %>%
  mutate(acceptable = REJECT == 0 & biobank_derived_consistent == 0 & blow_points_ok == 0)

repro <- function(x, acceptable) {
  max_acc <- max(x[acceptable])
  which_max_acc <- which(x == max_acc)[1]
  length(x) > 1 & any(abs(max_acc - x[-which_max_acc]) <= THRESHOLD)
}

LF_tmp <- LF_EUR_blows_passing %>%
  group_by(ID) %>%
  filter(any(acceptable)) %>%
  mutate(fev1_plus_fvc = ifelse(acceptable, round(fev1 + fvc, 10), -Inf)) %>%
  arrange(desc(fev1_plus_fvc), desc(pef)) %>%
  summarise(across(c(fev1, fvc), list(best=~max(.[acceptable]),
                                      repro=~repro(., acceptable))),
            pass_LF_QC=fev1_repro & fvc_repro,
            ratio_best=fev1_best/fvc_best,
            pef_best=pef[1]) %>%
  filter(pass_LF_QC) %>%
  select(ID, ends_with("_best"))
                                           

LF_fev1_fvc_ratio_best <- LF_EUR_blows_passing %>%
  select(ID, fev1, fvc, acceptable) %>%
  pivot_longer(c(fev1, fvc), names_to = "trait") %>%
  group_by(ID, trait) %>%
  filter(any(acceptable)) %>%
  summarise(max_acc=max(value[acceptable]),
            which_max_acc=which(value == max_acc)[1],
            max_acc_repro=ifelse(length(value) > 1 &
                                   any(abs(max_acc - value[-which_max_acc]) <= THRESHOLD), 1, 0),
            .groups="drop_last") %>%
  filter(all(max_acc_repro == 1)) %>%
  ungroup %>%
  select(-max_acc_repro, -which_max_acc) %>%
  pivot_wider(names_from = trait, names_glue = "{trait}.best", values_from = max_acc) %>%
  mutate(rato.best = fev1.best/fvc.best)
  
LF_pef_best <- LF_EUR_blows_passing %>%
  group_by(ID) %>%
  filter(any(acceptable)) %>%
  mutate(fev1_plus_fvc = ifelse(acceptable, round(fev1 + fvc, 10), -Inf)) %>%
  select(ID, fev1_plus_fvc, pef) %>%
  arrange(desc(fev1_plus_fvc), desc(pef)) %>%
  slice(1) %>%
  select(ID, pef.best=pef) %>%
  ungroup

LF_best <- inner_join(LF_fev1_fvc_ratio_best, LF_pef_best, by="ID")

write_tsv(LF_best, "spirometry_new_QC_full_measures.txt")

