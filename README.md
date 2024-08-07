# Spirometry quality control of lung function traits in UK Biobank
## Introduction

GRS_informed_QC is a series of R scripts for a RAP pipeline to get the QC'ed lung function in any UK Biobank project starting from the available fields on the RAP using the newly defined QC criteria.

### Authors
Nick Shrine,  Jing Chen, Victoria E. Jackson

## Requirements
* R with tidyverse
* [`dx-toolkit`](https://github.com/dnanexus/dx-toolkit)

## Instructions
The commands can be run in a local Linux environment or in a RAP cloud_workstation instance.
You should run all commands in the same directory to which you checked out the code in this repository.

#### Set up your RAP environment
1. Log into your UK Biobank RAP project with `dx login`
2. Edit `RAP.config` to select your RAP project dataset and the output directory for the lung function phenotypes.
3. Set your current RAP directory to the directory `DIR` you specified in `RAP.config` with `dx cd DIR`

#### Extract the required UK Biobank lung function fields
Run the script `./extract_LF_fields.sh` which will extract the lung function quantitative traits and related fields specified in `RAP_LF_fields_colnames.txt` to the file `RAP_extracted_data.csv` in the RAP project directory specified in `RAP.config`.

#### Extract the UK Biobank spirometry blow curve data
Run the script `./extract_blows.sh` which will extract the blow curve data for the first visit (instance 0) to the file `blows_i0.tsv` in the RAP project directory specified in `RAP.config` 

#### Format the column names of the RAP extracted lung function fields
1. Download the lung function data `dx download RAP_extracted_data.csv` to the same directory where you checked out this code.
2. Run `Rscript format_fields.R` which will read the downloaded data, format the column names and write the result to `lung_function_data.csv`

#### Create the variables derived from the blow curves
1. Download the blow curve data `dx download blows_i0.tsv`
2. Run `Rscript clean_curve_derived_variables.R blows_i0.tsv` which will process the blow curve data and save derived variables to `blows_i0_clean_curve_derived_variables.csv`.

The blow curve data by default is processed in chunks of 10,000 rows at a time, you can alter this depending on memory usage by specifying an additional argument e.g. to change to 5,000 rows at a time do:

`Rscript clean_curve_derived_variables.R blows_i0.tsv 5000`

#### Annotate the blows with their quality control classifications
Run `Rscript spirometry_failed_classification.R lung_function_data.csv blows_i0_clean_curve_derived_variables.csv` which will output the blow data with QC classifications to `UKBB_spirometry_QC_blows_classified.csv`.

#### Apply the quality control criteria as described in the paper
Run `Rscript spirometry_new_QC_full_measures.R` which will output the quality controlled lung function quantitative traits to `spirometry_new_QC_full_measures.txt`.

#### Further quality control
You may want to apply further quality control such as excluding samples whose percent predicted lung function are outliers according to GLI-2012 (Global Lung Initiative; Quanjer et al. 2012 <doi:10.1183/09031936.00080312>). We have provided example code to do this `GLI_outliers.R` which uses the [rspiro R package](https://cran.r-project.org/web//packages/rspiro/index.html).

The GLI code requires ancestries to be assigned to the samples (you would most likely want to divide samples by ancestry before running association on the lung function phenotypes anyway). Assigned ancestries for UK Biobank samples are available as a returned data set from the [Pan UKBB project](https://biobank.ndph.ox.ac.uk/ukb/dset.cgi?id=2442). 

### Reference
Genetic risk score-informed re-evaluation of spirometry quality control to maximise power in genetic association studies of lung function

Jing Chen, Nick Shrine, Abril G Izquierdo, Anna Guyatt, Henry Völzke, Stephanie London, Ian P Hall, Frank Dudbridge, SpiroMeta Consortium, CHARGE Consortium, Louise V Wain, Martin D Tobin, Catherine John

https://doi.org/10.1101/2024.07.31.24311269
