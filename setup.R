### Setup: install required packages

cat("=== SD3 Item Analysis Setup ===\n\n")

required_packages <- c(
  "tidyr",
  "dplyr",
  "tibble",
  "moments",
  "ggplot2",
  "ggrepel",
  "scales",
  "Hmisc",
  "psych",
  "nFactors",
  "qgraph"
)

cat("Checking and installing required packages...\n")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  Installing ", pkg, "...\n"))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  } else {
    cat(paste0("  ", pkg, " already installed.\n"))
  }
}

datafile <- file.path(getwd(), "src_data", "SD3", "data.csv")
if (!file.exists(datafile)) {
  cat("\n=== DATA DOWNLOAD REQUIRED ===\n")
  cat("Place the SD3 dataset at src_data/SD3/data.csv\n\n")
  cat("Download from:\n")
  cat("  http://openpsychometrics.org/_rawdata/SD3.zip\n\n")
  cat("Unzip and move the SD3/ folder into src_data/\n")
} else {
  cat(paste0("\nData file found: ", datafile, "\n"))
  cat(paste0("  Size: ", round(file.size(datafile) / 1024 / 1024, 2), " MB\n"))
}

cat("\nSetup complete!\n")
