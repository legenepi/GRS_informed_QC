#!/bin/bash

. RAP.config

dx mkdir -p $DEST

if dx ls ${DEST}/RAP_LF_fields.txt 2> /dev/null; then
    dx rm ${DEST}/RAP_LF_fields.txt
fi

dx upload --destination ${DEST}/ RAP_LF_fields.txt 

dx run table-exporter \
    -idataset_or_cohort_or_dashboard=$DATASET \
    -ientity="participant" \
    -ifield_names_file_txt="${DEST}/RAP_LF_fields.txt" \
    -iheader_style=FIELD-NAME \
    -icoding_option=RAW \
    -ioutput="RAP_extracted_data" \
    --destination $DEST \
    --name extract_fields \
    --brief -y
