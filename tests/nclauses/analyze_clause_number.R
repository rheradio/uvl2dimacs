#!/usr/bin/env Rscript
# analyze_clause_number.R — derive the clause-reduction statistics reported
# in the paper from the CSV produced by compare_clause_number.sh.
#
# Usage (from the repo root):
#   Rscript tests/nclauses/analyze_clause_number.R
#
# Expected output:
#   Backbone simplification reduces clauses in 99.09% of models (median 40.43%)
#   Tseitin transformation reduces clauses in 0.65% of models (median 83.11%)

# Locate this script's own directory so results.csv is found regardless of
# the current working directory (compare_clause_number.sh writes it here).
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
script_dir <- if (length(file_arg) > 0) dirname(normalizePath(file_arg)) else getwd()

csv_path <- file.path(script_dir, "results.csv")
if (!file.exists(csv_path)) {
  message("results.csv not found — run compare_clause_number.sh first")
  quit(status = 1)
}

d <- read.csv(csv_path, stringsAsFactors = FALSE)

# logical vectors: models where the clause count strictly decreases
backbone_reduced <- d$nclause_straightforward > d$nclause_backbone
tseitin_reduced  <- d$nclause_straightforward > d$nclause_tseitin

pct <- function(x) round(mean(x) * 100, 2)

backbone_pct_models <- pct(backbone_reduced)
tseitin_pct_models  <- pct(tseitin_reduced)

backbone_median_red <- round(median(
  (d$nclause_straightforward[backbone_reduced] -
   d$nclause_backbone[backbone_reduced]) /
  d$nclause_straightforward[backbone_reduced] * 100
), 2)

tseitin_median_red <- round(median(
  (d$nclause_straightforward[tseitin_reduced] -
   d$nclause_tseitin[tseitin_reduced]) /
  d$nclause_straightforward[tseitin_reduced] * 100
), 2)

cat(sprintf("Models analysed : %d\n\n", nrow(d)))
cat(sprintf(
  "Backbone simplification reduces clauses in %.2f%% of models (median %.2f%%)\n",
  backbone_pct_models, backbone_median_red
))
cat(sprintf(
  "Tseitin transformation reduces clauses in %.2f%% of models (median %.2f%%)\n",
  tseitin_pct_models, tseitin_median_red
))
