#!/usr/bin/env sh
# -----------------------------------------------------------------------------
# DNSweep v1.0.0 — minimal, portable DNS subdomain enumerator (POSIX sh)
#
# What it does
#   - Resolves a list of (sub)domains across common RR types (A,AAAA,MX,NS,TXT,CNAME,SOA,SRV)
#   - Writes per-host text files and a consolidated TSV of findings
#   - (Optional) Attempts AXFR against authoritative NS for the base domain
#
# Requirements
#   - dig (from bind-utils / dnsutils)
#
# Usage
#   DNSweep.sh [-r RESOLVER] [-t TYPES] [-o OUTDIR] [--axfr] DOMAIN SUBDOMAINS_FILE
#
#   DOMAIN           Base zone (e.g., example.com)
#   SUBDOMAINS_FILE  File with subdomains (one per line). Lines can be short labels
#                    (e.g., "www") and will be expanded to FQDNs using DOMAIN.
#                    Fully-qualified names are also accepted as-is.
#
# Options
#   -r RESOLVER   Use specific resolver (e.g., 1.1.1.1). Default: system resolver
#   -t TYPES      Comma-separated RR types (default: A,AAAA,MX,NS,TXT,CNAME,SOA,SRV)
#   -o OUTDIR     Output directory (default: dns/run_YYYYmmdd_HHMMSS)
#   --axfr        Attempt zone transfer against authoritative NS for DOMAIN
#   -h | --help   Show help
#
# Examples
#   ./DNSweep.sh -r 1.1.1.1 corp.example.com subs.txt
#   ./DNSweep.sh --axfr -t A,AAAA,TXT example.org subdomains.txt
#
# Output layout
#   OUTDIR/
#     findings.tsv            # tab-delimited: fqdn<TAB>type<TAB>value
#     hosts/<fqdn>.txt        # per-host, grouped by type
#     axfr/<ns>.zone          # only if --axfr and transfer succeeds
# -----------------------------------------------------------------------------

set -eu

# --- defaults -----------------------------------------------------------------
RESOLVER=""
TYPES="A,AAAA,MX,NS,TXT,CNAME,SOA,SRV"
OUTDIR=""
DO_AXFR=0

# --- helpers ------------------------------------------------------------------
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '1,120p' "$0" | sed 's/^# \{0,1\}//' | sed '1,3d; /^set -eu/q'
  exit 0
}

nowstamp() { date -u +%Y%m%d_%H%M%S; }

need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

sanitize_name() { printf '%s' "$1" | tr '/: ' '___'; }

trim_cr() { tr -d '\r'; }

# --- parse args ---------------------------------------------------------------
DOMAIN=""
SUBFILE=""
while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    -h|--help) usage ;;
    -r) shift || die "-r needs value"; RESOLVER="$1" ;;
    -t) shift || die "-t needs value"; TYPES="$1" ;;
    -o) shift || die "-o needs value"; OUTDIR="$1" ;;
    --axfr) DO_AXFR=1 ;;
    --) shift; break ;;
    -* ) die "Unknown option: $
