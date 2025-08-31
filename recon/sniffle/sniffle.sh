#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# sniffle.sh — Passive network recon capture (portable, minimal, accurate)
# ------------------------------------------------------------------------------
# Modes:
#   bcast   → Broadcast/Multicast discovery (ARP, NBNS/137, mDNS/5353, LLMNR/5355)
#   ad-core → Core AD signals (Kerberos/88, LDAP/389, SMB/445, RPC/135/139, GC/3268/3269, kpasswd/464, ADWS/9389)
#   dns     → DNS only (53/udp,tcp)
#   all     → Everything (ip or ip6) — use short durations or rotation
#
# Artifacts per run:
#   enum/sniff/run_<UTC_TS>[_TAG]/pcap/...
#   enum/sniff/run_<UTC_TS>[_TAG]/summary.log   (live-decoded highlights)
#
# Requirements: tcpdump, awk, date, mkdir, sh
# Optional: timeout(1) (GNU) or gtimeout (macOS coreutils)
#
# Usage:
#   sniffle.sh [--mode MODE] [--iface IFACE] [--secs N]
#              [--rotate-secs N] [--max-mb N]
#              [--outroot DIR] [--tag NAME]
#              [--quiet] [--dry-run] [-h|--help]
#
# Examples:
#   sudo ./sniffle.sh --mode bcast --secs 60
#   sudo ./sniffle.sh --mode ad-core --iface eth0 --rotate-secs 300
#   sudo ./sniffle.sh --mode dns --tag labA
# ------------------------------------------------------------------------------

set -eu

VERSION="1.0.0"

# ---------------------------- defaults ----------------------------------------
MODE="bcast"          # bcast | ad-core | dns | all
IFACE=""              # auto-detect if empty
SECS=""               # duration in seconds (uses timeout/gtimeout if present)
ROTATE_SECS=""        # tcpdump -G rotation (seconds per file)
MAX_MB=""             # tcpdump -C rotation (max MB per file)
OUTROOT="enum/sniff"  # base output root
TAG=""                # optional label suffix
QUIET=0
DRYRUN=0

# ------------------------------ helpers ---------------------------------------
say() { [ "$QUIET" -eq 1 ] && return 0; printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }
now_utc() { date -u +%Y%m%d_%H%M%S; }

usage() {
  sed -n '1,120p' "$0" | sed 's/^# \{0,1\}//' | sed '1,3d; /^set -eu/q'
  exit 0
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

detect_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    printf '%s' "timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    printf '%s' "gtimeout"
  else
    printf '%s' ""
  fi
}

detect_iface() {
  # Try ip(8) first (Linux)
  if command -v ip >/dev/null 2>&1; then
    ip -o link show 2>/dev/null \
      | awk -F': ' '$2 !~ /lo/ {print $2; exit 0}'
    return 0
  fi
  # macOS/BSD ifconfig -l gives space-separated list; prefer non-lo0
  if command -v ifconfig >/dev/null 2>&1; then
    IFLIST=$((ifconfig -l 2>/dev/null || true) | tr ' ' '\n' | awk '$0!~/^lo0$/ {print; exit 0}')
    if [ -n "$IFLIST" ]; then
      printf '%s' "$IFLIST"
      return 0
    fi
    # Fallback parse
    ifconfig 2>/dev/null | awk -F: '/flags=/{gsub(/^[ \t]+/,"",$1); if ($1!="lo0"){print $1; exit 0}}'
    return 0
  fi
  # Last resort
  printf '%s' "eth0"
}

mkoutdir() {
  ts=$(now_utc)
  suffix=""
  [ -n "$TAG" ] && suffix="_$TAG"
  RUN_DIR="$OUTROOT/run_${ts}${suffix}"
  PCAP_DIR="$RUN_DIR/pcap"
  mkdir -p "$PCAP_DIR"
  SUMMARY="$RUN_DIR/summary.log"
}

filter_for_mode() {
  case "$MODE" in
    bcast)
      # ARP, NBNS(137/udp), mDNS(5353), LLMNR(5355), general broadcast/multicast
      printf '%s' '(arp or (udp port 137) or (udp port 5353) or (udp port 5355) or broadcast or multicast)'
      ;;
    ad-core)
      # Kerberos 88, LDAP 389, SMB 445, RPC 135/139, GC 3268/3269, kpasswd 464, ADWS 9389
      printf '%s' '(tcp port 88 or udp port 88 or tcp port 389 or udp port 389 or tcp port 445 or tcp port 135 or tcp port 139 or tcp port 464 or tcp port 3268 or tcp port 3269 or tcp port 9389)'
      ;;
    dns)
      printf '%s' '(udp port 53 or tcp port 53)'
      ;;
    all)
      printf '%s' '(ip or ip6)'
      ;;
    *)
      die "Unknown mode: $MODE (use bcast|ad-core|dns|all)"
      ;;
  esac
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "sniffle needs root privileges. Re-run as root or with sudo."
  fi
}

# ------------------------------ parse CLI -------------------------------------
[ "$#" -eq 0 ] && usage

while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    -h|--help) usage ;;
    --mode) shift || die "--mode requires value"; MODE="$1" ;;
    --iface) shift || die "--iface requires value"; IFACE="$1" ;;
    --secs)  shift || die "--secs requires value"; SECS="$1" ;;
    --rotate-secs) shift || die "--rotate-secs requires value"; ROTATE_SECS="$1" ;;
    --max-mb) shift || die "--max-mb requires value"; MAX_MB="$1" ;;
    --outroot) shift || die "--outroot requires value"; OUTROOT="$1" ;;
    --tag) shift || die "--tag requires value"; TAG="$1" ;;
    --quiet) QUIET=1 ;;
    --dry-run) DRYRUN=1 ;;
    --) shift; break ;;
    -* ) die "Unknown option: $1" ;;
    *  ) die "Unexpected argument: $1" ;;
  esac
  shift || true
done

# ------------------------------ preflight -------------------------------------
need tcpdump
need awk
require_root

[ -n "$IFACE" ] || IFACE="$(detect_iface)"
[ -n "$IFACE" ] || die "Could not auto-detect an interface; use --iface IFACE"

FILTER="$(filter_for_mode)"
mkoutdir

say "==> Sniffle v$VERSION"
say "    mode:        $MODE"
say "    iface:       $IFACE"
say "    filter:      $FILTER"
say "    out:         $RUN_DIR"
[ -n "$SECS" ] && say "    duration:    ${SECS}s"
[ -n "$ROTATE_SECS" ] && say "    rotate-secs: $ROTATE_SECS"
[ -n "$MAX_MB" ] && say "    max-mb:      $MAX_MB"

if [ "$DRYRUN" -eq 1 ]; then
  say "[dry-run] would start capture and quicklook"
  exit 0
fi

# ------------------------------ build commands --------------------------------
PCAP_BASENAME="$PCAP_DIR/sniffle"
PCAP_OUT="$PCAP_BASENAME.pcap" # default if no rotation
TD_ROTATE_ARGS=""
TD_SIZE_ARGS=""
TD_TIMEFMT_ARGS=""

if [ -n "$ROTATE_SECS" ]; then
  # Use strftime in -w when -G is given; tcpdump will expand it
  TD_ROTATE_ARGS="-G $ROTATE_SECS"
  TD_TIMEFMT_ARGS="-w ${PCAP_BASENAME}.%Y%m%d_%H%M%S.pcap"
else
  TD_TIMEFMT_ARGS="-w $PCAP_OUT"
fi

if [ -n "$MAX_MB" ]; then
  TD_SIZE_ARGS="-C $MAX_MB"
fi

TIMEOUT_BIN="$(detect_timeout)"
RUN_WITH_TIMEOUT=""
if [ -n "$SECS" ] && [ -n "$TIMEOUT_BIN" ]; then
  RUN_WITH_TIMEOUT="$TIMEOUT_BIN $SECS"
elif [ -n "$SECS" ] && [ -z "$TIMEOUT_BIN" ]; then
  say "(!) 'timeout' not found; will run until manually interrupted (Ctrl-C)."
fi

# tcpdump decode stream for quicklook
SUMMARY_DECODER="tcpdump -i \"$IFACE\" -l -nn -vv -tttt -s 0 \"$FILTER\""

# tcpdump writer for pcap
WRITER_CMD="tcpdump -i \"$IFACE\" -s 0 -nn -U $TD_ROTATE_ARGS $TD_SIZE_ARGS $TD_TIMEFMT_ARGS \"$FILTER\""

# ------------------------------ start processes --------------------------------
# Start summary (decoder) → AWK
SUMMARY_LOG="$SUMMARY"
: > "$SUMMARY_LOG"

awk_quicklook='
{
  line=$0
  ts=$1" "$2
  # Basic tags by port/service hints
  if (line ~ / 53:/ || line ~ / DNS / || line ~ /\? /) {
    # try to extract query name (very heuristic)
    qn=""
    if (match(line, /\? ([^ ]+)/, m)) { qn=m[1] }
    tag="DNS"
    if (line ~ / SRV / || line ~ /_kerberos|_ldap|_msdcs|_gc\./) { tag="DNS-SRV" }
    printf("[%s] %-9s %s\n", ts, tag, (qn!=""?qn:line)) >> "'"$SUMMARY_LOG"'"
    next
  }
  if (line ~ / 137:/ || line ~ /NBNS/ || line ~ /NetBIOS/)     { printf("[%s] %-9s %s\n", ts, "NBNS", line) >> "'"$SUMMARY_LOG"'" ; next }
  if (line ~ / 5355/ || line ~ /LLMNR/)                       { printf("[%s] %-9s %s\n", ts, "LLMNR", line) >> "'"$SUMMARY_LOG"'" ; next }
  if (line ~ / 5353/ || line ~ /mDNS/)                        { printf("[%s] %-9s %s\n", ts, "mDNS", line) >> "'"$SUMMARY_LOG"'" ; next }
  if (line ~ / 88:/ || line ~ /kerberos/i)                    { printf("[%s] %-9s %s\n", ts, "KERBEROS", line) >> "'"$SUMMARY_LOG"'" ; next }
  if (line ~ / 389:/ || line ~ /ldap/i)                       { printf("[%s] %-9s %s\n", ts, "LDAP", line) >> "'"$SUMMARY_LOG"'" ; next }
  if (line ~ / 445:/ || line ~ /SMB/ || line ~ /smb/i)        { printf("[%s] %-9s %s\n", ts, "SMB", line) >> "'"$SUMMARY_LOG"'" ; next }
  if (line ~ /^ARP| ARP / || line ~ / who-has /)              { printf("[%s] %-9s %s\n", ts, "ARP", line) >> "'"$SUMMARY_LOG"'" ; next }
  # default
  printf("[%s] %-9s %s\n", ts, "OTHER", line) >> "'"$SUMMARY_LOG"'"
}'

# Run decoder (background)
# shellcheck disable=SC2086
sh -c "$SUMMARY_DECODER" 2>/dev/null | awk "$awk_quicklook" &
PID_DEC=$!

# Run pcap writer (foreground or under timeout)
# shellcheck disable=SC2086
if [ -n "$RUN_WITH_TIMEOUT" ]; then
  sh -c "$RUN_WITH_TIMEOUT $WRITER_CMD" &
else
  sh -c "$WRITER_CMD" &
fi
PID_WRITER=$!

cleanup() {
  # Try graceful termination
  [ -n "${PID_DEC:-}" ] && kill "$PID_DEC" 2>/dev/null || true
  [ -n "${PID_WRITER:-}" ] && kill "$PID_WRITER" 2>/dev/null || true
  wait 2>/dev/null || true
  say ""
  say "==> Sniffle run complete"
  say "    Run dir : $RUN_DIR"
  say "    Summary : $SUMMARY_LOG"
  if [ -n "$ROTATE_SECS" ] || [ -n "$MAX_MB" ]; then
    say "    PCAPs   : $PCAP_DIR/"
  else
    say "    PCAP    : $PCAP_OUT"
  fi
}
trap cleanup INT TERM EXIT

# ------------------------------ wait ------------------------------------------
wait "$PID_WRITER" 2>/dev/null || true
# Decoder may still be running; give it a moment then cleanup triggers on EXIT
sleep 1
exit 0
