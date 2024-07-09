library(tidyverse)
library(rspiro) 

args <- commandArgs(TRUE)
argc <- length(args)

LF_file <- args[1]
ethnicity <- ifelse(argc > 1, as.integer(args[2]), 1)

LF <- read_tsv(LF_file)

# Arguments to rspiro function zscore_GLI

# age         Age in years
# height      Height in meters
# gender	    Gender (1 = male, 2 = female) or a factor with two levels (first = male). Default is 1.
# ethnicity	  Ethnicity (1 = Caucasian, 2 = African-American, 3 = NE Asian, 4 = SE Asian, 5 = Other/mixed). Default is 1.
# FEV1	      Forced Expiratory Volume in 1 second (lt)
# FVC	        Forced Vital Capacity (lt)
# FEV1FVC	    FEV1 / FVC 


# Set up the required variables in the correct units for Z score calculation
LF_outliers <- LF %>%
  mutate(age = age_at_recruitment,
         gender = 2 - sex,
         height = standing_height / 100,
         fev1_zscore = zscore_GLI(age, height, gender, ethnicity, FEV1=fev1_best),
         fvc_zscore = zscore_GLI(age, height, gender, ethnicity, FVC=fvc_best),
         ratio_zscore = zscore_GLI(age, height, gender, ethnicity, FEV1FVC=ratio_best),
         max_zscore = pmax(abs(fev1_zscore), abs(fvc_zscore), abs(ratio_zscore)),
         outlier = max_zscore > 5)
  