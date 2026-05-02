### Data Preparation
### Load SD3 data, define item metadata, recode negatively keyed items,
### compute scale scores

library(tidyr)
library(dplyr)
library(tibble)

srcpath <- file.path(getwd(), "src_data", "SD3")

alldata <- read.table(file.path(srcpath, "data.csv"),
                      sep = "\t", header = TRUE, stringsAsFactors = FALSE)

### keep only item columns (M1-M9, N1-N9, P1-P9), drop country/source
itemcols <- c(paste0("M", 1:9), paste0("N", 1:9), paste0("P", 1:9))
alldata <- alldata[, itemcols]

### convert to numeric and drop rows with out-of-range values (0 = missing)
alldata <- alldata %>% mutate(across(everything(), as.numeric))
alldata <- alldata %>% filter(if_all(everything(), ~ . >= 1 & . <= 5))

currentdata <- alldata

### item metadata
items <- read.table(file.path(srcpath, "items.txt"),
                    sep = "\t", quote = "", stringsAsFactors = FALSE,
                    col.names = c("itemid", "text"))

iteminfo <- items %>%
  mutate(itemidcopy = itemid) %>%
  mutate(dimid = sub("[0-9]+$", "", itemidcopy),
         index = as.numeric(sub("^[A-Z]+", "", itemidcopy))) %>%
  select(-itemidcopy) %>%
  mutate(dimname = case_when(
    dimid == "M" ~ "Machiavellianism",
    dimid == "N" ~ "Narcissism",
    dimid == "P" ~ "Psychopathy"
  ))

### reshape to long format
itemdata <- (currentdata
  %>% rowid_to_column("userID")
  %>% mutate(userID = paste0("user_", userID))
  %>% pivot_longer(cols = -userID, names_to = "itemid", values_to = "value")
  %>% mutate(value = as.numeric(value))
)

### recode negatively keyed items (6 - value, scale is 1-5)
### Narcissism: N2 (hate attention), N6 (embarrassed by compliments), N8 (average person)
### Psychopathy: P2 (avoid dangerous situations), P7 (never in trouble with law)
reversed_items <- c("N2", "N6", "N8", "P2", "P7")

itemdata <- itemdata %>%
  mutate(value = ifelse(itemid %in% reversed_items, 6 - value, value))

### compute scale sum scores per person and dimension
dimensiondata <- (itemdata
  %>% left_join(iteminfo %>% select(itemid, dimid), by = "itemid")
  %>% group_by(userID, dimid)
  %>% summarise(score = sum(value), .groups = "drop")
)

dimensions <- sort(unique(dimensiondata$dimid))

outputpath <- file.path(getwd(), "output_data")
dir.create(outputpath, showWarnings = FALSE)
dir.create(file.path(outputpath, "itemstatistics"), showWarnings = FALSE)
dir.create(file.path(outputpath, "dimstatistics"), showWarnings = FALSE)

cat("Data preparation complete.\n")
cat(paste0("  N = ", length(unique(itemdata$userID)), " participants\n"))
cat(paste0("  ", length(unique(itemdata$itemid)), " items across ",
           length(dimensions), " dimensions\n"))
cat(paste0("  Reversed items: ", paste(reversed_items, collapse = ", "), "\n"))
