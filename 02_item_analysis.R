### Item Analysis
### Descriptive item statistics, item histograms, corrected item-total
### correlations, difficulty-discrimination plots

if (!exists("itemdata")) source("01_data_preparation.R")

library(ggplot2)
library(ggrepel)
library(scales)

### ── Item statistics ──────────────────────────────────────────────────────────

itemstatistics <- (itemdata
  %>% left_join(iteminfo %>% select(itemid, dimid), by = "itemid")
  %>% group_by(userID, dimid)
  %>% mutate(dimvalue = sum(value))
  %>% ungroup()
  %>% group_by(itemid)
  %>% summarise(
    N       = n(),
    M       = mean(value),
    SD      = sd(value),
    MIN     = min(value),
    MAX     = max(value),
    TotCorr = cor(value, dimvalue - value),
    .groups = "drop"
  )
  %>% mutate(P = M / 5)
)

cat("Item statistics:\n")
print(as.data.frame(itemstatistics), row.names = FALSE)

### ── Item histograms ──────────────────────────────────────────────────────────

itemhistvalues <- (itemdata
  %>% group_by(itemid, value)
  %>% summarise(N = n(), .groups = "drop_last")
  %>% mutate(rel = N / sum(N))
  %>% ungroup()
)

for (currentitemid in unique(itemdata$itemid)) {
  currentitemvalues <- itemhistvalues %>% filter(itemid == currentitemid)
  itemcontent <- iteminfo$text[iteminfo$itemid == currentitemid]

  p <- ggplot(data = currentitemvalues) +
    geom_bar(stat = "identity", aes(x = value, y = rel), fill = "#1a0a4a") +
    theme_bw() +
    labs(x = "Response", y = "Relative Frequency") +
    scale_y_continuous(labels = percent_format()) +
    scale_x_continuous(breaks = 1:5,
                       labels = c("1\nDisagree", "2", "3\nNeutral", "4", "5\nAgree")) +
    ggtitle(paste0(currentitemid, ": ", itemcontent))

  ggsave(p, filename = file.path(outputpath, "itemstatistics",
                                  paste0("hist-", currentitemid, ".png")),
         width = 7, height = 4)
}

cat("Item histograms saved.\n")

### ── Difficulty-discrimination plots (per dimension) ──────────────────────────

quadY <- function(a, x) a * x^2 + (-a) * x

quadReg <- function(x, y, amin = -4, amax = -0.01, h = 0.01) {
  possible_as <- seq(amin, amax, h)
  errors <- sapply(possible_as, function(a) mean((y - quadY(a, x))^2))
  possible_as[which.min(errors)]
}

dimlookup <- iteminfo %>% select(dimid, dimname) %>% distinct()

for (currentdim in dimensions) {
  currentdimname <- dimlookup$dimname[dimlookup$dimid == currentdim]

  currentdimitemdata <- (itemstatistics
    %>% left_join(iteminfo %>% select(itemid, dimid), by = "itemid")
    %>% filter(dimid == currentdim)
    %>% select(itemid, P, TotCorr)
  )

  paraLine <- data.frame(x = seq(0, 1, 0.01))
  paraLine$y <- quadY(
    quadReg(currentdimitemdata$P, currentdimitemdata$TotCorr),
    paraLine$x
  )

  p <- ggplot(currentdimitemdata, aes(x = P, y = TotCorr)) +
    geom_line(data = paraLine, aes(x = x, y = y), color = "#4CAF50", linewidth = 0.8) +
    geom_point(size = 2.5) +
    geom_label_repel(aes(label = itemid), size = 3, max.overlaps = 20) +
    theme_bw() +
    labs(x = "Item Difficulty (P)", y = "Corrected Item-Total Correlation") +
    ggtitle(paste0(currentdimname, " (", currentdim, ")"))

  ggsave(p, filename = file.path(outputpath, "itemstatistics",
                                  paste0("totCorr-", currentdim, ".png")),
         width = 7, height = 5)
  ggsave(p, filename = file.path(outputpath, "itemstatistics",
                                  paste0("totCorr-", currentdim, ".pdf")),
         width = 7, height = 5)
}

cat("Difficulty-discrimination plots saved.\n")
