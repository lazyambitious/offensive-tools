#!/usr/bin/env bash
# tcpenum.sh — Passive AD enumeration helper built around tcpdump
# Place under: ops/scripts/tcpenum.sh
#
# Modes:
#   bcast    -> ARP/MDNS/NBNS broadcast & multicast discovery
#   ad-core  -> Kerberos/LDAP/SMB focus (88/389/445)
#   dns      -> DNS focus (53) (captures SRV queries e.g., _ldap._tcp.dc._msdcs)
#   all      -> Unfiltered (short windows only; large pcaps)
#
# Examples:
#   ./tcpenum.sh bcast --secs 300
#   ./tcpenum.sh ad-core --iface ens224 --secs 900 --tag ILF_ADlab
#   ./tcpenum.sh dns --secs 180 --quiet
#
# Outputs:
#   enum/sniff/<mode>_<ts>[_<tag>].pcap
#   enum/sniff/<mode>_<ts>[_<tag>].summary.log
#
# Notes:
# - Runs two tcpdump processes: one writes pcap, one prints decoded lines for quick parsing.
# - Requires: bash, tcpdump, grep, awk, date, timeout (coreutils), ip
# - Designed for headless SSH/tmux use. No active probing. Capture-only.

set -Eeuo pipefail

VERSION="0.2.0"

# ---------- Defaults ----------
MODE="${1:-}"
IFACE=""
SECS=600
TAG=""
QUIET=0
DRYRUN=0
OUTDIR="enum/sniff"
NOTES_FILE="notes/findings.md"

# ---------- Helpers ----------
usage() {
  cat <<EOF
tcpenum.sh v${VERSION} — passive AD enumeration via tcpdump

Usage: $0 <bcast|ad-core|dns|all> [--iface IFACE] [--secs N] [--tag TAG] [--quiet] [--dry-run] [--outdir DIR]
Options:
  --iface IFACE   Capture interface (auto-detect if omitted)
  --secs N        Capture duration in seconds (default: ${SECS})
  --tag TAG       Engagement tag appended to filenames (no spaces)
  --outdir DIR    Output directory for pcaps and summaries (default: ${OUTDIR})
  --quiet         Reduce console output
  --dry-run       Show resolved settings and filters, do not capture
  -h, --help      This help

Examples:
  $0 bcast --secs 300
  $0 ad-core --iface ens224 --secs 900 --tag ILF_ADlab
  $0 dns --secs 120
EOF
}

log() { [ "$QUIET" -eq 1 ] || echo -e "[$(date +'%F %T')] $*"; }
err() { echo -e "[!] $*" >&2; }

require_bin() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }
}

autodetect_iface() {
  # Choose first UP non-loopback interface with an IPv4 address
  local cand
  # shellcheck disable=SC2086
  cand=$(ip -o -4 addr show | awk '!/ lo /{print $2}' | head -n1 || true)
  if [[ -n "${cand:-}" ]]; then
    echo "$cand"
    return 0
  fi
  # Fallback: first UP non-loopback link
  cand=$(ip -o link show up | awk -F': ' '$2!="lo"{print $2}' | head -n1 || true)
  [[ -n "${cand:-}" ]] && { echo "$cand"; return 0; }
  return 1
}

resolve_filter() {
  case "$MODE" in
    bcast)   echo '(broadcast or multicast) or (udp port 137) or (udp port 5353)' ;;
    ad-core) echo 'port 88 or port 389 or port 445' ;;
    dns)     echo 'port 53' ;;
    all)     echo '' ;;
    *)       err "Unknown mode: '$MODE'"; usage; exit 1 ;;
  esac
}

safe_tag() {
  # strip spaces and unsafe chars
  echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_-'
}

# ---------- Parse Args ----------
if [[ -z "$MODE" ]] || [[ "$MODE" == "-h" ]] || [[ "$MODE" == "--help" ]]; then
  usage; exit 0
fi
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iface) IFACE="${2:-}"; shift 2 ;;
    --secs)  SECS="${2:-}"; shift 2 ;;
    --tag)   TAG="$(safe_tag "${2:-}")"; shift 2 ;;
    --outdir) OUTDIR="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

# ---------- Pre-flight ----------
require_bin tcpdump
require_bin ip
require_bin awk
require_bin grep
require_bin timeout

if [[ -z "${IFACE}" ]]; then
  IFACE="$(autodetect_iface || true)"
  [[ -z "${IFACE}" ]] && { err "Could not auto-detect a capture interface. Use --iface."; exit 1; }
fi

# Validate iface exists and is up
if ! ip link show "$IFACE" >/dev/null 2>&1; then
  err "Interface '$IFACE' not found."; exit 1
fi
if ! ip link show up | grep -qE "^\d+:\s*${IFACE}:"; then
  log "Warning: interface '$IFACE' is not marked UP; proceeding anyway."
fi

mkdir -p "$OUTDIR"

FILTER="$(resolve_filter)"
TS="$(date +'%Y-%m-%d_%H-%M-%S')"
BASE="${MODE}_${TS}"
[[ -n "$TAG" ]] && BASE="${BASE}_${TAG}"
PCAP="${OUTDIR}/${BASE}.pcap"
SUM="${OUTDIR}/${BASE}.summary.log"

if [[ "$MODE" == "all" && "$SECS" -gt 600 ]]; then
  log "Note: 'all' mode can generate large files. Consider --secs <= 600. (Current: ${SECS}s)"
fi

log "Mode:      ${MODE}"
log "Iface:     ${IFACE}"
log "Duration:  ${SECS}s"
log "Filter:    ${FILTER:-<none>}"
log "Out (pcap):    ${PCAP}"
log "Out (summary): ${SUM}"
[[ -n "$TAG" ]] && log "Tag:       ${TAG}"
[[ "$DRYRUN" -eq 1 ]] && { log "Dry run requested. Exiting."; exit 0; }

# ---------- Signal handling ----------
TCPDUMP_PCAP_PID=""
TCPDUMP_PRINT_PID=""
cleanup() {
  local code=$?
  [[ -n "$TCPDUMP_PCAP_PID" ]] && kill "$TCPDUMP_PCAP_PID" 2>/dev/null || true
  [[ -n "$TCPDUMP_PRINT_PID" ]] && kill "$TCPDUMP_PRINT_PID" 2>/dev/null || true
  wait "$TCPDUMP_PCAP_PID" 2>/dev/null || true
  wait "$TCPDUMP_PRINT_PID" 2>/dev/null || true
  if [[ $code -eq 124 ]]; then
    log "Capture window (${SECS}s) completed."
  else
    log "Capture stopped (signal or completion)."
  fi
  log "Saved: $PCAP"
  log "Saved: $SUM"
}
trap cleanup EXIT INT TERM

# ---------- Start capture ----------
# 1) Raw pcap writer (packet-buffered with -U). Use timeout to bound duration.
# 2) Parallel line-decoder for quick parsing into summary (no -w, human-readable).
# Both use identical BPF filter for determinism.

# Start pcap writer
if [[ -n "$FILTER" ]]; then
  timeout "${SECS}" sudo tcpdump -i "$IFACE" -U -s0 -nn $FILTER -w "$PCAP" >/dev/null 2>&1 &
else
  timeout "${SECS}" sudo tcpdump -i "$IFACE" -U -s0 -nn -w "$PCAP" >/dev/null 2>&1 &
fi
TCPDUMP_PCAP_PID=$!

# Prepare summary header
{
  echo "===== tcpenum summary ====="
  echo "start: $(date +'%F %T')"
  echo "mode:  ${MODE}"
  echo "iface: ${IFACE}"
  echo "secs:  ${SECS}"
  echo "tag:   ${TAG:-<none>}"
  echo "filter: ${FILTER:-<none>}"
  echo "file:  ${PCAP}"
  echo "----------------------------"
} > "$SUM"

# Quick-look parser: read decoded lines and extract useful hints conservatively.
quicklook_parser() {
  # Reads decoded tcpdump lines on stdin. Emits structured hints.
  # We’re conservative to avoid noisy false positives.
  awk '
  BEGIN{
    tz_cmd="date +\"%F %T\""
  }
  function nowts(){
    cmd=tz_cmd; cmd | getline d; close(cmd); return d
  }
  {
    line=$0

    # DNS SRV queries for LDAP/DC (likely DC discovery)
    if (line ~ /DNS/ && line ~ /_ldap\._tcp/){
      print nowts(),"[DNS-SRV] ", line
      next
    }

    # Kerberos (AS-REQ / AS-REP / TGS-REQ) — usernames often present in clear in req
    if (line ~ /kerberos/ || line ~ /krb5/ || line ~ /88/){
      if (line ~ /AS-REQ|AS-REP|TGS-REQ|krb/){
        print nowts(),"[KERB]    ", line
        next
      }
    }

    # NBNS / NetBIOS Name Service
    if (line ~ /NBNS|NetBIOS-NS|udp 137/){
      print nowts(),"[NBNS]    ", line
      next
    }

    # SMB/CIFS interest (445/tcp)
    if (line ~ /445/ && line ~ /Flags/){
      print nowts(),"[SMB]     ", line
      next
    }

    # ARP who-has discovery
    if (line ~ /^ARP,/ || line ~ /ARP, Request who-has/){
      print nowts(),"[ARP]     ", line
      next
    }

    # mDNS multicast 5353
    if (line ~ /mdns/ || line ~ /5353/){
      if (line ~ /_services|_ldap|_kerberos/){
        print nowts(),"[mDNS]    ", line
        next
      }
    }
  }'
}

# Start printable decoder (line-buffered with -l) to feed the parser into summary
# Note: use -tttt for full timestamped decode lines; parser prepends its own ts as well.
if [[ -n "$FILTER" ]]; then
  timeout "${SECS}" sudo tcpdump -i "$IFACE" -nn -s0 -l -vvv $FILTER 2>/dev/null | quicklook_parser >>"$SUM" &
else
  timeout "${SECS}" sudo tcpdump -i "$IFACE" -nn -s0 -l -vvv 2>/dev/null | quicklook_parser >>"$SUM" &
fi
TCPDUMP_PRINT_PID=$!

log "Capturing... (CTRL-C to stop early)"
wait "$TCPDUMP_PCAP_PID" || true
wait "$TCPDUMP_PRINT_PID" || true

# Footer
{
  echo "----------------------------"
  echo "end:   $(date +'%F %T')"
  echo "===== end ====="
} >> "$SUM"

# Optional: append top signals to notes (commented; enable if desired)
# {
#   echo -e "\n### tcpenum (${MODE}) $(date +'%F %T')"
#   echo "- PCAP: \`${PCAP}\`"
#   echo "- Summary: \`${SUM}\`"
#   echo "- Candidate DC/DNS lines:"
#   grep "\[DNS-SRV\]" "$SUM" | head -n 10 | sed "s/^/  - /"
#   echo "- Kerberos hints:"
#   grep "\[KERB\]" "$SUM" | head -n 10 | sed "s/^/  - /"
# } >> "$NOTES_FILE" 2>/dev/null || true

exit 0
