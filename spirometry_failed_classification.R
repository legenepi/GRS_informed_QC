library(tidyverse)

args <- commandArgs(T)
lung.function.file <- args[1]
derived.file <- args[2]

lung.function.df <- read_csv(lung.function.file)
derived.df <- read_csv(derived.file)

lung.function <- inner_join(lung.function.df, derived.df, by="ID") %>%
  rename_with(~str_replace(., "pef\\.([0-2])", "der.pef.\\1") %>%
                str_replace(".([0-2])$", "_\\1"))

cols_blow <- lung.function %>%
  select(matches(".+_[0-2]$")) %>%
  names

LF_long <- lung.function %>%
  pivot_longer(all_of(cols_blow), names_to = c(".value", "blow"), names_pattern = "(.+)_([0-2])$")

#### annotate blows with number of error messages
#Assign a score 1-5 for number of error messages: START, EXPFLOW, END, COUGH, REJECT
ERRORS <- c("COUGH", "EXPFLOW", "REJECT", "START", "END") 

ERROR_fns <- ERRORS %>%
  set_names %>%
  map(~paste0("~ifelse(!is.na(.) & str_detect(., \"", ., "\"), 1, 0)") %>%
        parse(text=.) %>%
        eval)

ANY_ERROR <- paste(ERRORS, collapse="|")

count_errors <- function(x) {
  str_split(x, " ") %>%
    map_int(~str_detect(., ANY_ERROR) %>%
              sum(na.rm = TRUE))
}

#### annotate blow fails manual start-of-blow QC 
# Back-extrapolated volume should be less than <5% of FVC, or 150ml, whichever is greater.
start.fun <- function(fvc, bevol) {
  ifelse(!is.na(fvc) & !is.na(bevol) & bevol < pmax(fvc*0.05*1000, 150), 0, 1)
}

#### annotate any blows with erroneous (negative) derived variables.
points.ok.fun <- function(x) {
  ifelse(x == 0, 0, 1)
}

#### consistency: Blows where the pre-derived and newly-derived values differed by 5% were excluded ####
ukb.der.consistent <- function(ukb, der) {
  !is.na(ukb) & !is.na(der) & abs(100*((ukb - der)/ukb)) <= 5
}

LF_long_QC <- LF_long %>%
  mutate(across(blow_acceptability_A, .fns=ERROR_fns, .names="{.fn}"),
         n_error=count_errors(blow_acceptability_A),
         start_blow=start.fun(fvc, bevol),
         blow_points_ok=points.ok.fun(derived.fields.error),
         biobank_derived_consistent=ifelse(ukb.der.consistent(fev1, der.fev1) &
           ukb.der.consistent(fvc, der.fvc), 0, 1))

cols_wide <- cols_blow %>%
  str_remove("_[0-2]$") %>%
  unique %>%
  c(ERRORS, "n_error", "start_blow", "blow_points_ok", "biobank_derived_consistent")

LF <- LF_long_QC %>%
  pivot_wider(names_from = blow, names_glue = "{.value}_{blow}", values_from = all_of(cols_wide))

write_csv(LF, file="UKBB_spirometry_QC_blows_classified.csv")