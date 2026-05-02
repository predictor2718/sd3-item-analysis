### Scale Analysis
### Dimension descriptives, scale intercorrelations, exploratory factor analysis
### (1-, 2-, 3-factor solutions with fit comparison), parallel analysis,
### factor network, reliability

if (!exists("itemdata")) source("01_data_preparation.R")

library(ggplot2)
library(ggrepel)
library(moments)
library(psych)
library(nFactors)
library(igraph)
library(scales)

dimlookup <- iteminfo %>% select(dimid, dimname) %>% distinct()

### ── Dimension descriptive statistics ─────────────────────────────────────────

dimensionstatistics <- (dimensiondata
  %>% group_by(dimid)
  %>% summarise(
    N        = n(),
    M        = mean(score),
    SD       = sd(score),
    Skew     = skewness(score),
    Kurtosis = kurtosis(score),
    MIN      = min(score),
    MAX      = max(score),
    .groups  = "drop"
  )
  %>% left_join(dimlookup, by = "dimid")
)

cat("Dimension statistics:\n")
print(as.data.frame(dimensionstatistics), row.names = FALSE)

### ── Dimension histograms ─────────────────────────────────────────────────────

for (currentdim in dimensions) {
  currentdimname <- dimlookup$dimname[dimlookup$dimid == currentdim]

  currentdimvalues <- dimensiondata %>%
    filter(dimid == currentdim) %>%
    group_by(score) %>%
    summarise(N = n(), .groups = "drop") %>%
    mutate(rel = N / sum(N))

  p <- ggplot(currentdimvalues) +
    geom_bar(stat = "identity", aes(x = score, y = N), fill = "#1a0a4a") +
    theme_bw() +
    labs(x = "Sum Score", y = "Frequency") +
    ggtitle(currentdimname)

  ggsave(p, filename = file.path(outputpath, "dimstatistics",
                                  paste0("hist-", currentdim, ".png")),
         width = 6, height = 4)
}

cat("Dimension histograms saved.\n")

### ── Scale intercorrelation heatmap ──────────────────────────────────────────

dimensiondatamatrix <- (dimensiondata
  %>% pivot_wider(names_from = dimid, values_from = score)
  %>% select(-userID)
)

corrmatrix <- cor(as.matrix(dimensiondatamatrix))

corrdata <- (as.data.frame(corrmatrix)
  %>% rownames_to_column("dim1")
  %>% pivot_longer(cols = -dim1, names_to = "dim2", values_to = "corr")
  %>% left_join(dimlookup, by = c("dim1" = "dimid")) %>% rename(Dimension1 = dimname)
  %>% left_join(dimlookup, by = c("dim2" = "dimid")) %>% rename(Dimension2 = dimname)
)

corrplot <- ggplot(corrdata, aes(x = Dimension1, y = Dimension2, fill = corr)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", corr)), size = 4) +
  scale_fill_gradient2(low = "#2166ac", high = "#b2182b", mid = "white",
                       midpoint = 0, limit = c(-1, 1),
                       name = "Pearson\nCorrelation") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, vjust = 1, hjust = 1, size = 11),
        axis.title = element_blank()) +
  ggtitle("Scale Intercorrelations") +
  coord_fixed()

ggsave(corrplot, filename = file.path(outputpath, "dimstatistics", "dimcorrelation.png"),
       width = 6, height = 5)

cat("Correlation heatmap saved.\n")

### ── Item correlation matrix (for FA) ────────────────────────────────────────

allitemdata <- (itemdata
  %>% select(userID, itemid, value)
  %>% pivot_wider(names_from = itemid, values_from = value)
  %>% select(-userID)
  %>% select(paste0("M", 1:9), paste0("N", 1:9), paste0("P", 1:9))
)

### ── Parallel analysis & scree ───────────────────────────────────────────────

ev <- eigen(cor(allitemdata))
ap <- parallel(subject = nrow(allitemdata), var = ncol(allitemdata),
               rep = 100, cent = 0.05)
nS <- nScree(x = ev$values, aparallel = ap$eigen$qevpea)

png(file.path(outputpath, "dimstatistics", "scree.png"), width = 800, height = 600, res = 120)
plotnScree(nS)
dev.off()

cat("Scree plot saved.\n")

### ── EFA: 1, 2, and 3 factor solutions ──────────────────────────────────────
### The D-factor (dark core) debate: does 1 general factor or 3 specific ones
### better describe the data? We compare all three solutions.

fa1 <- fa(allitemdata, nfactors = 1, rotate = "none",    fm = "ml")
fa2 <- fa(allitemdata, nfactors = 2, rotate = "oblimin", fm = "ml")
fa3 <- fa(allitemdata, nfactors = 3, rotate = "oblimin", fm = "ml")

fitcomparison <- data.frame(
  Factors = c(1, 2, 3),
  RMSEA   = c(fa1$RMSEA[1], fa2$RMSEA[1], fa3$RMSEA[1]),
  TLI     = c(fa1$TLI,      fa2$TLI,      fa3$TLI),
  BIC     = c(fa1$BIC,      fa2$BIC,      fa3$BIC),
  CFI     = c(fa1$CFI,      fa2$CFI,      fa3$CFI)
)

cat("\nEFA Fit Comparison (1 vs 2 vs 3 factors):\n")
print(fitcomparison, row.names = FALSE, digits = 3)

### ── Factor loadings: 3-factor solution heatmap ─────────────────────────────

dim_colors <- c(M = "#E07B39", N = "#5B8ED6", P = "#5AAF6A")

factor_dim_map3 <- (as.data.frame(unclass(fa3$loadings))
  %>% rownames_to_column("itemid")
  %>% left_join(iteminfo %>% select(itemid, dimid), by = "itemid")
  %>% pivot_longer(cols = starts_with("ML"), names_to = "factor", values_to = "loading")
  %>% group_by(factor, dimid)
  %>% summarise(mean_abs = mean(abs(loading)), .groups = "drop")
  %>% group_by(factor)
  %>% slice_max(mean_abs, n = 1)
  %>% select(factor, mapped_dimid = dimid)
)

factor_label_map3 <- factor_dim_map3 %>%
  left_join(dimlookup, by = c("mapped_dimid" = "dimid")) %>%
  select(factor, factor_label = dimname)

fcal3_heatmap <- (as.data.frame(unclass(fa3$loadings))
  %>% rownames_to_column("itemid")
  %>% left_join(iteminfo %>% select(itemid, dimid, index), by = "itemid")
  %>% pivot_longer(cols = starts_with("ML"), names_to = "factor", values_to = "loading")
  %>% left_join(factor_label_map3, by = "factor")
  %>% arrange(dimid, index)
  %>% mutate(itemid = factor(itemid, levels = rev(unique(itemid))))
  %>% mutate(factor_label = factor(factor_label,
       levels = unique(factor_label[order(factor)])))
)

heatmap3 <- ggplot(fcal3_heatmap, aes(x = factor_label, y = itemid, fill = loading)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.2f", loading)),
            size = 2.8,
            colour = ifelse(abs(fcal3_heatmap$loading) > 0.4, "white", "grey30")) +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b",
                       midpoint = 0, limit = c(-0.7, 0.9),
                       oob = squish, name = "Loading") +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 8), panel.grid = element_blank()) +
  labs(x = "Factor (3-factor solution)", y = NULL) +
  ggtitle("Factor Loadings Heatmap — 3 Factors (Oblimin)")

ggsave(heatmap3, filename = file.path(outputpath, "dimstatistics", "fa_heatmap_3f.png"),
       width = 6, height = 9)

### ── Factor loadings: 1-factor solution (D-factor) ─────────────────────────

fcal1 <- (as.data.frame(unclass(fa1$loadings))
  %>% rownames_to_column("itemid")
  %>% rename(D = ML1)
  %>% left_join(iteminfo %>% select(itemid, dimid, dimname, index), by = "itemid")
  %>% arrange(dimid, index)
  %>% mutate(itemid = factor(itemid, levels = rev(unique(itemid))))
)

dfactor_plot <- ggplot(fcal1, aes(x = D, y = itemid, fill = dimname)) +
  geom_bar(stat = "identity", colour = "white", linewidth = 0.2) +
  scale_fill_manual(values = c(Machiavellianism = "#E07B39",
                               Narcissism = "#5B8ED6",
                               Psychopathy = "#5AAF6A")) +
  geom_vline(xintercept = 0, linewidth = 0.5) +
  theme_bw() +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "Loading on D-factor", y = NULL, fill = "Dimension") +
  ggtitle("1-Factor Solution: Dark Core (D-factor)")

ggsave(dfactor_plot,
       filename = file.path(outputpath, "dimstatistics", "fa_dfactor.png"),
       width = 7, height = 8)

cat("Factor loadings heatmap (3-factor) and D-factor plot saved.\n")

### ── Item correlation network ────────────────────────────────────────────────

item_corr <- cor(allitemdata)

### build igraph from correlation matrix (only edges |r| >= 0.1)
adj <- item_corr
diag(adj) <- 0
adj[abs(adj) < 0.1] <- 0
g <- graph_from_adjacency_matrix(adj, mode = "undirected", weighted = TRUE, diag = FALSE)

set.seed(42)
layout_coords <- layout_with_fr(g)
node_df <- data.frame(
  x     = layout_coords[, 1],
  y     = layout_coords[, 2],
  label = colnames(item_corr)
) %>%
  left_join(iteminfo %>% select(itemid, dimname), by = c("label" = "itemid"))

edges_df <- as_data_frame(g, what = "edges") %>%
  left_join(node_df %>% select(label, x, y), by = c("from" = "label")) %>%
  rename(x_from = x, y_from = y) %>%
  left_join(node_df %>% select(label, x, y), by = c("to" = "label")) %>%
  rename(x_to = x, y_to = y) %>%
  mutate(edge_color = ifelse(weight > 0, "#b2182b", "#2166ac"),
         alpha       = scales::rescale(abs(weight), to = c(0.1, 0.9)))

dim_colors <- c(Machiavellianism = "#E07B39", Narcissism = "#5B8ED6", Psychopathy = "#5AAF6A")

network_plot <- ggplot() +
  geom_segment(data = edges_df,
               aes(x = x_from, y = y_from, xend = x_to, yend = y_to,
                   color = edge_color, alpha = alpha, linewidth = abs(weight)),
               show.legend = FALSE) +
  scale_color_identity() +
  scale_linewidth(range = c(0.3, 2.5)) +
  geom_point(data = node_df, aes(x = x, y = y, fill = dimname),
             shape = 21, size = 8, color = "white", stroke = 0.5) +
  scale_fill_manual(values = dim_colors) +
  geom_text(data = node_df, aes(x = x, y = y, label = label),
            size = 2.5, fontface = "bold", color = "white") +
  theme_void() +
  theme(legend.position = "bottom",
        plot.title = element_text(hjust = 0.5, size = 13, face = "bold"),
        plot.margin = margin(10, 10, 10, 10)) +
  labs(fill = NULL, alpha = NULL, linewidth = NULL) +
  ggtitle("Item Correlation Network — Short Dark Triad")

ggsave(network_plot, filename = file.path(outputpath, "dimstatistics", "fa_network.png"),
       width = 10, height = 9)

cat("Network plot saved.\n")

### ── Reliability ──────────────────────────────────────────────────────────────

reltable <- data.frame(dimid = character(), Dimension = character(),
                       N = numeric(), Cronbach = numeric(),
                       Cronbach_st = numeric(), SplitHalf = numeric())

for (currentdim in dimensions) {
  currentdimname <- dimlookup$dimname[dimlookup$dimid == currentdim]

  currentitemdata <- (itemdata
    %>% left_join(iteminfo %>% select(itemid, dimid), by = "itemid")
    %>% filter(dimid == currentdim)
    %>% select(userID, itemid, value)
    %>% pivot_wider(names_from = itemid, values_from = value)
    %>% select(-userID)
  )

  ca <- psych::alpha(currentitemdata)
  sh <- splitHalf(currentitemdata)

  reltable <- reltable %>% add_row(
    dimid       = currentdim,
    Dimension   = currentdimname,
    N           = nrow(currentitemdata),
    Cronbach    = ca$total$raw_alpha,
    Cronbach_st = ca$total$std.alpha,
    SplitHalf   = sh$maxrb
  )
}

cat("\nReliability:\n")
print(as.data.frame(reltable), row.names = FALSE)

reltable_long <- reltable %>%
  pivot_longer(cols = c(Cronbach, Cronbach_st, SplitHalf),
               names_to = "Typ", values_to = "rel")

reliability_labels <- c(
  Cronbach    = "Cronbach's α",
  Cronbach_st = "Cronbach's α (std.)",
  SplitHalf   = "Split-Half"
)

relplot <- ggplot(reltable_long, aes(x = Dimension, y = rel, colour = Typ)) +
  geom_point(size = 3.5) +
  theme_bw() +
  scale_y_continuous(breaks = seq(0.1, 1, 0.1), limits = c(0.1, 1)) +
  scale_colour_discrete(labels = reliability_labels) +
  labs(x = NULL, y = "Reliability Coefficient", colour = "Method") +
  ggtitle("Internal Consistency and Split-Half Reliability")

ggsave(relplot, filename = file.path(outputpath, "dimstatistics", "reliability.png"),
       width = 8, height = 5)

cat("Reliability plot saved.\n")
cat("\nAll analyses complete. Outputs in output_data/\n")
