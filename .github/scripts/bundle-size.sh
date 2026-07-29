#!/usr/bin/env bash
# Renders size.tsv against baseline.tsv as a markdown table on stdout.
# Each TSV line is: <key>\t<bytes>\t<label>. Rows with no baseline print "—".
#
# stdout rather than writing $GITHUB_STEP_SUMMARY directly, so one render can
# feed both the job summary and a PR comment via tee.
#
# Usage: bundle-size.sh "<section title>"   (run from the dir holding size.tsv)
set -euo pipefail

touch baseline.tsv

echo "### $1"
echo
echo "| Artifact | This build | Baseline | Δ |"
echo "|---|---|---|---|"
# Keyed on FILENAME rather than the usual NR==FNR: with an empty baseline
# (first run, or an evicted cache) NR==FNR stays true through size.tsv and
# would load it as its own baseline, reporting every delta as zero.
awk -F'\t' '
  FILENAME == "baseline.tsv" { base[$1] = $2; next }
  {
    d = ($2 > 4194304) ? 1048576 : 1024; u = (d == 1024) ? "KiB" : "MiB"
    if (!($1 in base)) { printf "| %s | %.1f %s | — | — |\n", $3, $2/d, u; next }
    o = base[$1]
    printf "| %s | %.1f %s | %.1f %s | %+.1f %s (%+.2f%%) |\n", \
      $3, $2/d, u, o/d, u, ($2-o)/d, u, 100*($2-o)/o
  }
' baseline.tsv size.tsv
