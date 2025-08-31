#!/usr/bin/env sh
# -----------------------------------------------------------------------------
# CleanRoom v1.0.0 — minimal, portable engagement skeleton bootstrap
# -----------------------------------------------------------------------------
# Creates a clean, shallow directory layout for offensive-security engagements,
# CTFs, and labs. No logging layer. Profiles add optional folders (AD/Web).
#
# Usage:
#   cleanroom.sh <ENG_NAME> [--profile ad,web|all|none] [--init-git]
#                [--force] [--dry-run] [--quiet] [-h|--help]
#
# Examples:
#   ./cleanroom.sh CorpNet --profile ad,web --init-git
#   ./cleanroom.sh CTF-01
# -----------------------------------------------------------------------------

# --- Strict mode (portable) ---------------------------------------------------
set -eu

VERSION="1.0.0"

# --- Defaults -----------------------------------------------------------------
ENG_NAME=""
PROFILES="none"    # base only by default
INIT_GIT=0
FORCE=0
DRYRUN=0
QUIET=0

# --- IO helpers ---------------------------------------------------------------
say() { [ "$QUIET" -eq 1 ] && return 0; printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

# --- Usage --------------------------------------------------------------------
usage() {
  cat <<EOF
CleanRoom v$VERSION
Creates a clean, shallow directory skeleton for offensive security engagements.

USAGE:
  $(basename "$0") <ENG_NAME> [options]

OPTIONS:
  --profile X   Comma list: ad, web, all, none (default: none)
  --init-git    Initialize a git repo and write a sane .gitignore
  --force       Overwrite existing files / reuse existing directory
  --dry-run     Print actions without creating files
  --quiet       Suppress informational output
  -h, --help    Show this help

EXAMPLES:
  $(basename "$0") CorpNet-Red --profile ad,web --init-git
  $(basename "$0") CTF-01
EOF
}

# --- Parse CLI ----------------------------------------------------------------
if [ "$#" -eq 0 ]; then usage; exit 1; fi

while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --init-git) INIT_GIT=1 ;;
    --force)    FORCE=1 ;;
    --dry-run)  DRYRUN=1 ;;
    --quiet)    QUIET=1 ;;
    --profile)
      shift || die "--profile requires a value"
      PROFILES="${1:-}"
      ;;
    --profile=*)
      PROFILES="${1#--profile=}"
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      if [ -z "$ENG_NAME" ]; then
        ENG_NAME="$1"
      else
        die "Unexpected argument: $1"
      fi
      ;;
  esac
  shift || true
done

[ -n "$ENG_NAME" ] || die "ENG_NAME is required. See --help."

# --- Profiles -----------------------------------------------------------------
PROFILE_AD=0
PROFILE_WEB=0

normalize_profiles() {
  case "$PROFILES" in
    all)  PROFILE_AD=1; PROFILE_WEB=1; return 0 ;;
    none|"") PROFILE_AD=0; PROFILE_WEB=0; return 0 ;;
  esac

  rest="$PROFILES"
  while [ -n "$rest" ]; do
    item="${rest%%,*}"
    [ "$rest" = "$item" ] && rest="" || rest="${rest#*,}"
    case "$item" in
      ad)  PROFILE_AD=1 ;;
      web) PROFILE_WEB=1 ;;
      "" ) : ;;
      *)   die "Unsupported profile: $item (use ad, web, all, or none)" ;;
    esac
  done
}

normalize_profiles

# --- FS helpers ---------------------------------------------------------------
do_mkdir() {
  rel="$1"
  if [ "$DRYRUN" -eq 1 ]; then
    say "[dry-run] mkdir -p $ENG_NAME/$rel"
    return 0
  fi
  mkdir -p "$ENG_NAME/$rel"
}

write_file() {
  rel="$1"
  if [ "$DRYRUN" -eq 1 ]; then
    say "[dry-run] create $ENG_NAME/$rel"
    # Still consume stdin to keep caller semantics correct
    # shellcheck disable=SC2034
    tmp_sink=$(cat >/dev/null)
    return 0
  fi
  abs="$ENG_NAME/$rel"
  if [ -e "$abs" ] && [ "$FORCE" -ne 1 ]; then
    say "exists: $rel (use --force to overwrite)"
    # consume heredoc to avoid broken pipe
    cat >/dev/null
    return 0
  fi
  parent=$(dirname "$abs")
  [ -d "$parent" ] || mkdir -p "$parent"
  tmp="$abs.tmp.$$"
  cat > "$tmp"
  mv "$tmp" "$abs"
}

safe_touch() {
  rel="$1"
  if [ "$DRYRUN" -eq 1 ]; then
    say "[dry-run] touch $ENG_NAME/$rel"
    return 0
  fi
  abs="$ENG_NAME/$rel"
  parent=$(dirname "$abs")
  [ -d "$parent" ] || mkdir -p "$parent"
  [ -e "$abs" ] || : > "$abs"
}

chmod_600_if_exists() {
  rel="$1"
  [ "$DRYRUN" -eq 1 ] && { say "[dry-run] chmod 600 $ENG_NAME/$rel"; return 0; }
  [ -e "$ENG_NAME/$rel" ] && chmod 600 "$ENG_NAME/$rel" 2>/dev/null || true
}

# --- Guard existing directory -------------------------------------------------
if [ -d "$ENG_NAME" ] && [ "$FORCE" -ne 1 ]; then
  die "Directory '$ENG_NAME' already exists. Use --force to reuse."
fi

say "==> CleanRoom v$VERSION: creating '$ENG_NAME' (ad=$PROFILE_AD, web=$PROFILE_WEB)"

# --- Create base skeleton -----------------------------------------------------
do_mkdir "enum/net"
[ "$PROFILE_AD"  -eq 1 ] && do_mkdir "enum/ad"
[ "$PROFILE_WEB" -eq 1 ] && do_mkdir "enum/web"

do_mkdir "creds/hashes"
do_mkdir "creds/cracked"
do_mkdir "creds/keys"

do_mkdir "data/files"
do_mkdir "data/dumps"
[ "$PROFILE_AD" -eq 1 ] && do_mkdir "data/sysvol"

do_mkdir "ops/tools"

do_mkdir "notes"
do_mkdir "rpt/screenshots"
do_mkdir "tmp"

# --- Seed .env ---------------------------------------------------------------
write_file ".env" <<'EOF'
# CleanRoom: engagement environment
# Load with:  set -a; . ./.env; set +a
ENG_NAME=""
DOMAIN=""
DC_IP=""
SUBNET=""
USER=""
PASS=""
# Optional helpers
PROXY=""
RHOST=""
LHOST=""

# Put engagement tools at front of PATH (safe even if empty)
if [ -d "./ops/tools" ]; then
  case ":$PATH:" in
    *":$PWD/ops/tools:"*) : ;;
    *) PATH="$PWD/ops/tools:$PATH" ;;
  esac
fi
EOF
chmod_600_if_exists ".env"

# --- Seed README inside engagement -------------------------------------------
write_file "README.md" <<'EOF'
# CleanRoom — Engagement Skeleton

A clean, shallow directory layout for offensive-security engagements, CTFs, and labs.

## Quick Start
```sh
# Load env helpers in this directory:
set -a; . ./.env; set +a
