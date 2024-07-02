suppressMessages(library(tidyverse))

args <- commandArgs(TRUE)
argc <- length(args)

blows_file <- args[1]
size <- ifelse(argc > 1, as.integer(args[2]), 10000)

derive_variables <- function(x, pos) {
  blows <- x %>%
    rename_all(~str_replace(., "p3066_i0", "blow") %>%
                 str_replace("p3060_i0", "time") %>%
                 str_replace("p3061_i0", "ordering") %>%
                 str_replace("p3065_i0", "acceptability"))
  
  blows_long <- blows %>%
    pivot_longer(cols=-eid, names_to = c(".value", "array"), names_pattern = '(.+)_(a.)') %>%
    drop_na %>%
    separate(blow, c("blow", "n_points", "vol"), sep=",", extra = "merge") 
  
  # blows_info <- blows_long %>%
  #   select(-vol) %>%
  #   mutate(n_points=as.integer(n_points))
  
  blows_data <- blows_long %>%
    select(eid, blow=array, vol) %>% 
    separate_longer_delim(vol, delim=",") %>%
    group_by(eid, blow) %>%
    mutate(vol=as.integer(vol),
           volume=vol/1000,
           measure=1:n(),
           time=(measure - 1)/100)
  
  blows_data_der <- blows_data %>%
    mutate(inst.flow=c(0, diff(vol))/0.01,
           vol_l=c(rep.int(0, 4), vol[1:(n() - 4)]),
           vol_u=c(vol[5:n()], rep(0,4)),
           flow=ifelse(measure > 4 & measure <= n() - 4,
                       (vol_u - vol_l)/0.08,
                       inst.flow),
           pfmax = max(inst.flow) * 60/1000, # Instantaneous peak flow rate
           flow.max = max(flow), 
           pef = 60 * flow.max/1000, # Measure of PEF
           pefmeasure = min(measure[flow == flow.max]), # Measure of PEF
           peftime = min(time[flow == flow.max]), # Time of PEF
           pefvol = vol[time == peftime], # Volume at PEF
           zero.measure = pefmeasure - round(100 * pefvol/flow.max), # Estimated new time zero
           bxvol = ifelse(measure <= zero.measure, 0,
                          ifelse(measure <= pefmeasure,
                                 pefvol - 0.01 * flow.max * (pefmeasure - measure),
                                 vol)),
           bevol = ifelse(zero.measure[1] > 0, vol[ measure == zero.measure ], 0),
           zero.time = ifelse(zero.measure[1] > 0, time[ measure == zero.measure], 0),
           bxflow = ifelse(time < zero.time, 0,
                           ifelse(time < peftime, flow.max, flow)),
           bx.time = time - zero.time) %>%
    select(-vol_l, -vol_u)
  
  derived <- blows_data_der %>%
    summarise(fetime = sum(time > zero.time) * 0.01,
              femeasure = sum(measure > zero.measure) + 1,
              fvc = max(volume[time > zero.time]),
              fetvol = vol[measure == femeasure],
              fev1 = ifelse(fetime >= 1, volume[which.min(abs(bx.time - 1.0))], NA),
              end0.5flow = (fetvol - mean(bxvol[measure == femeasure - 50], na.rm = TRUE))/0.5,
              end1flow = (fetvol - mean(bxvol[measure == femeasure - 100], na.rm = TRUE))/1.0,
              end2flow = (fetvol - mean(bxvol[measure == femeasure - 200], na.rm = TRUE))/2.0,
              end10vol = sum(!is.na(bxvol) & bxvol >= (fvc * 1000) - 10),
              end25vol = sum(!is.na(bxvol) & bxvol >= (fvc * 1000) - 25),
              end50vol = sum(!is.na(bxvol) & bxvol >= (fvc * 1000) - 50),
              vol.25.a = max(bxvol[bxvol < 0.25 * fvc * 1000]),
              time.25.a = first(time[bxvol == vol.25.a]),
              flow.25.a = first(flow[bxvol == vol.25.a]),
              vol.25.b = min(bxvol[bxvol >= 0.25 * fvc * 1000]),
              time.25.b = first(time[bxvol == vol.25.b]),
              flow.25.b = first(flow[bxvol == vol.25.b]),
              fef.25.fvc = (flow.25.a + flow.25.b)/2,
              int.25.fvc = time.25.a +
                ((vol.25.b - (0.25 * fvc * 1000))/(vol.25.b - vol.25.a)) * (time.25.b - time.25.a),
              vol.75.a = max(bxvol[bxvol < 0.75 * fvc * 1000]),
              time.75.a = first(time[bxvol == vol.75.a]),
              flow.75.a = first(flow[bxvol == vol.75.a]),
              vol.75.b = min(bxvol[bxvol >= 0.75 * fvc * 1000]),
              time.75.b = first(time[bxvol == vol.75.b]),
              flow.75.b = first(flow[bxvol == vol.75.b]),
              fef.75.fvc = (flow.75.a + flow.75.b)/2,
              int.75.fvc = time.75.a +
                ((vol.75.b - (0.75 * fvc * 1000))/(vol.75.b - vol.75.a)) * (time.75.b - time.75.a),
              fef.25.75 = (0.5 * fvc * 1000)/(int.75.fvc - int.25.fvc),
              pfmax=pfmax[1],
              peftime=peftime[1],
              pefvol=pefvol[1],
              pef=pef[1],
              zero.time=zero.time[1],
              bevol=bevol[1],
              derived.fields.error=c(fef.25.fvc, fef.75.fvc, fef.25.75, pefvol, fetvol, bevol) %>%
                map_lgl(~( . < 0)) %>%
                any(na.rm = TRUE),
              across(c(fef.25.fvc, fef.75.fvc, fef.25.75, pefvol, fetvol, bevol),
                     ~if(derived.fields.error) { NA } else {.}),
              .groups = "drop")
  
  derived %>%
    mutate(blow=str_remove(blow, "a") %>% as.integer) %>%
    select(ID=eid, blow, der.fev1=fev1, der.fvc=fvc, pfmax, pef, fef.25.fvc, fef.75.fvc, fef.25.75,
           peftime, pefvol, zero.time, bevol, fetime, fetvol, end0.5flow, end1flow, end2flow,
           end10vol, end25vol, end50vol, derived.fields.error) %>%
    pivot_longer(c(-ID, -blow)) %>%
    mutate(name=paste(name, blow, sep=".")) %>%
    select(-blow) %>%
    pivot_wider(names_from = name, values_from = value)
}

curve_derived <- read_tsv_chunked(blows_file,
                                  DataFrameCallback$new(derive_variables),
                                  chunk_size = size,
                                  show_col_types = FALSE)

out <- blows_file %>%
  str_remove(".tsv") %>%
  paste0("_clean_curve_derived_variables.csv")

write_csv(curve_derived, out)
