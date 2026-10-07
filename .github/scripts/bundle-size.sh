#!/usr/bin/env bash
# Renders size.tsv against baseline.tsv as a markdown table on stdout.
# Each TSV line is: <key>\t<bytes>\t<label>. Rows with no baseline print "—".
#
# stdout rather than writing $GITHUB_STEP_SUMMARY directly, so one render can
# feed both the job summary and a PR comment via tee.
#
# Usage: bundle-size.sh "<section title>"   (run from the dir holding size.tsv)
#
# WARN_KEYS (space-separated row keys, optional) marks those rows ⚠️ when they
# grow by more than 2% or 25 KiB. A highlight only: nothing fails on it.
set -euo pipefail

touch baseline.tsv

echo "### $1"
echo
echo "| Artifact | This build | Baseline | Δ |"
echo "|---|---|---|---|"
# Keyed on FILENAME rather than the usual NR==FNR: with an empty baseline
# (first run, or an evicted cache) NR==FNR stays true through size.tsv and
# would load it as its own baseline, reporting every delta as zero.
awk -F'\t' -v warn_keys="${WARN_KEYS:-}" '
  BEGIN { n = split(warn_keys, k, " "); for (i = 1; i <= n; i++) warn[k[i]] = 1 }
  FILENAME == "baseline.tsv" { base[$1] = $2; next }
  {
    d = ($2 > 4194304) ? 1048576 : 1024; u = (d == 1024) ? "KiB" : "MiB"
    if (!($1 in base)) { printf "| %s | %.1f %s | — | — |\n", $3, $2/d, u; next }
    o = base[$1]
    flag = ($1 in warn && ($2-o > 25600 || 100*($2-o)/o > 2)) ? " ⚠️" : ""
    printf "| %s | %.1f %s | %.1f %s | %+.1f %s (%+.2f%%)%s |\n", \
      $3, $2/d, u, o/d, u, ($2-o)/d, u, 100*($2-o)/o, flag
  }
' baseline.tsv size.tsv
