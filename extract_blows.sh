#!/bin/bash

. RAP.config

dx mkdir -p $DEST

if ! dx ls ${DEST}/blows_i0_fields.txt 2> /dev/null; then
    dx upload --destination ${DEST}/ blows_i0_fields.txt 
fi

dx run table-exporter \
    -idataset_or_cohort_or_dashboard=$DATASET \
    -ientity="participant" \
    -ifield_names_file_txt="${DEST}/blows_i0_fields.txt" \
    -icoding_option=RAW \
    -iheader_style=FIELD-NAME \
    -ioutput_format=TSV \
    -ioutput="blows_i0" \
    --destination $DEST \
    --instance-type mem2_ssd2_x16 \
    --name extract_blows \
    --brief -y
