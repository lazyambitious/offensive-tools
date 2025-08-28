#!/usr/bin/env bash
# engagement-bootstrap: create a clean, short-name directory structure for an engagement/lab/ctf
# Usage:
#   ./bootstrap.sh ACME_Q3  or  ./bootstrap.sh ILF_ADlab --init-git
set -euo pipefail

ENG_NAME="${1:-}"
if [[ -z "${ENG_NAME}" ]]; then
  echo "Usage: $0 <engagement_name> [--init-git]"
  exit 1
fi

INIT_GIT=0
if [[ "${2:-}" == "--init-git" ]]; then
  INIT_GIT=1
fi

# Short, lowercase folder names for fast typing
ROOT_DIR="${ENG_NAME}"
DIRS=(
  "enum/nmap"
  "enum/ldap"
  "enum/smb"
  "enum/sniff"
  "enum/misc"
  "creds/hashes"
  "creds/cracked"
  "creds/keys"
  "loot/files"
  "loot/sysvol"
  "loot/dumps"
  "ops/bins"
  "ops/scripts"
  "ops/shell"
  "notes"
  "rpt/screenshots"
  "tmp"
)

mkdir -p "${ROOT_DIR}"
pushd "${ROOT_DIR}" >/dev/null

for d in "${DIRS[@]}"; do
  mkdir -p "$d"
done

# Seed .env
cat > .env <<'EOF'
# Engagement environment variables (optional convenience)
# Load with:  set -a; source .env; set +a
ENG_NAME=__ENG_NAME__
DOMAIN=example.local
DC_IP=192.0.2.10
USER=operator
PASS='ChangeMe!'
SUBNET=192.0.2.0/24
EOF
sed -i "s/__ENG_NAME__/${ENG_NAME}/" .env

# Seed notes/ files from templates
cat > notes/ops.md <<'EOF'
# 📝 Engagement Ops Log – {{ENG_NAME}}

## 📌 Context
- Client / Lab: 
- Date (start): 
- Operator: 
- Scope / Rules of Engagement: 

---

## ⏱️ Timeline Log

### Day 1 – Recon
- **HH:MM** – Started passive sniffing with Wireshark (`enum/sniff/pcap1.pcap`).
- **HH:MM** – Responder (-A) captured NetNTLMv2 from <ip> → saved `creds/hashes/ntlmv2_<date>.txt`.
- **HH:MM** – fping sweep on <subnet> → <count> hosts → `enum/misc/fping.txt`.

### Day 2 – Active Enum
- **HH:MM** – Nmap scan of DC (<ip>) `-sV -p 88,135,139,389,445,636,3268,3389 -oA enum/nmap/dc` (+ console log).
- **HH:MM** – Kerbrute userenum → <count> valid users → `enum/misc/valid_users.txt`.
- **HH:MM** – AS-REP roast: <user> → `creds/hashes/asrep_<user>.txt`.

### Day 3 – Cred Cracking & Validation
- **HH:MM** – hashcat crack (`-m 18200` or `-m 5600`) → cracked: `<user>:<pass>` → `creds/cracked/hashcat_cracked.txt`.
- **HH:MM** – CME validate SMB/WinRM across subnet → `enum/smb/cme_<date>.txt`.

### Day 4 – Credentialed Enum
- **HH:MM** – ldapsearch/bloodhound-python collections.
- **HH:MM** – SYSVOL/GPP review, SPN discovery.

---

## 📋 Findings (running list)
- Domain(s):
- DC(s):
- Valid users: (see `enum/.../valid_users.txt`)
- Cracked creds:
  - user: pass
- Weaknesses observed:
  - LLMNR enabled
  - AS-REP allowed for: <list>
  - Legacy hosts: <hosts>

---

## ✅ Next Steps
- BloodHound collection with <user>.
- Kerberoast SPN users.
- Search SYSVOL for GPP cpasswords.

EOF

cat > notes/findings.md <<'EOF'
# 📋 Findings – {{ENG_NAME}}

## Domain Overview
- Domain: 
- Forest: 
- Trusts: 

## Credential Findings
- Captured hashes (see `creds/hashes/`)
- Cracked credentials (see `creds/cracked/`)

## Service & Exposure
- SMB open on: 
- RDP open on: 
- WinRM open on: 

## Misconfigurations
- LLMNR/NBT-NS enabled
- AS-REP users
- Kerberoastable SPNs
- GPP cpasswords
- LAPS delegation issues

## Evidence
- Screenshots: `rpt/screenshots/`
- Logs: `enum/*` (refer to specific file paths)

EOF

cat > notes/todo.md <<'EOF'
# ✅ TODO – {{ENG_NAME}}
- [ ] Passive capture (Wireshark, Responder -A)
- [ ] Host sweep (fping)
- [ ] Service scan (nmap_smart.sh)
- [ ] User enum (kerbrute)
- [ ] Policy enum (CME --pass-pol)
- [ ] Spray (kerbrute/CME)
- [ ] Credentialed enum (ldapsearch/BloodHound)
- [ ] Kerberoast / AS-REP roast
- [ ] Lateral movement (WinRM/RDP)
- [ ] Evidence collection (screenshots, logs)

EOF

# Seed reporting files
cat > rpt/timeline.md <<'EOF'
# 🕒 Timeline – {{ENG_NAME}}
> Use concise, time-stamped entries. Link files where possible.

- YYYY-MM-DD HH:MM – Action → Evidence: `path/to/file`
- YYYY-MM-DD HH:MM – Finding → Evidence: `path/to/file`

EOF

cat > rpt/draft.md <<'EOF'
# Report Draft – ${ENG_NAME}

## Executive Summary (to be completed)
- Scope:
- High-level findings:
- Risk rating:

## Narrative Summary (tie back to timeline.md)
- Overview of approach
- Key milestones
- Business impact

## Technical Findings (link evidence from rpt/screenshots)
- Finding 1
- Finding 2

## Recommendations
- Priority fixes
- Hardening guidance
EOF

# .gitignore (optional, safe defaults)
cat > .gitignore <<'EOF'
# Avoid committing sensitive artifacts
creds/
loot/
rpt/screenshots/
enum/**/*.pcap
*.kirbi
*.bin
*.dmp
*.log
tmp/
# Allow templates and text reports
!notes/*.md
!rpt/*.md
!enum/**/*.xml
!enum/**/*.nmap
!enum/**/*.gnmap
EOF

# Helper scripts
cat > ops/scripts/logwrap.sh <<'EOF'
#!/usr/bin/env bash
# logwrap: run a command and store stdout to a dated log file while printing to console.
# Usage: logwrap <out_file> -- <command> [args...]
set -euo pipefail
OUT="${1:-}"; shift || true
if [[ -z "${OUT}" || "${1:-}" != "--" ]]; then
  echo "Usage: $0 <out_file> -- <command> [args...]"
  exit 1
fi
shift
mkdir -p "$(dirname "$OUT")"
# Capture both stdout and stderr. Preserve exit code.
( "$@" ) 2>&1 | tee "$OUT"
exit ${PIPESTATUS[0]}
EOF
chmod +x ops/scripts/logwrap.sh

cat > ops/scripts/nmap_smart.sh <<'EOF'
#!/usr/bin/env bash
# nmap_smart: convenience wrapper that saves structured (-oA) and console log via tee.
# Usage: nmap_smart <target> [nmap args...]
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target> [nmap args...]"
  exit 1
fi
TARGET="$1"; shift || true
STAMP="$(date +%Y%m%d_%H%M%S)"
BASE="enum/nmap/${TARGET//\//_}_${STAMP}"
mkdir -p enum/nmap
# Default args if none provided
ARGS="${*:- -sV -Pn -T4}"
echo "[*] nmap $ARGS $TARGET"
nmap $ARGS -oA "$BASE" "$TARGET" | tee "${BASE}_console.txt"
echo "[*] Output base: $BASE"
EOF
chmod +x ops/scripts/nmap_smart.sh

cat > ops/scripts/cme_smart.sh <<'EOF'
#!/usr/bin/env bash
# cme_smart: wrap CrackMapExec, timestamp output to enum/smb and tee console
# Usage: cme_smart smb <target or subnet> -u USER -p PASS [extra args]
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <proto> <target> [CME args]"
  exit 1
fi
PROTO="$1"; TARGET="$2"; shift 2
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="enum/smb/cme_${PROTO}_${TARGET//\//_}_${STAMP}.txt"
mkdir -p enum/smb
crackmapexec "$PROTO" "$TARGET" "$@" | tee "$OUT"
echo "[*] Saved: $OUT"
EOF
chmod +x ops/scripts/cme_smart.sh

cat > ops/scripts/bootstrap_readme.txt <<'EOF'
Quick Helpers
-------------
1) Source environment:
   set -a; source .env; set +a

2) Run a smart nmap scan:
   ops/scripts/nmap_smart.sh "$SUBNET"

3) Wrap any command and capture logs:
   ops/scripts/logwrap.sh enum/misc/mycmd_$(date +%s).log -- <your command>

4) CrackMapExec with logging:
   ops/scripts/cme_smart.sh smb "$SUBNET" -u "$USER" -p "$PASS" --shares
EOF

# Optional git init with safe defaults
if [[ $INIT_GIT -eq 1 ]]; then
  git init -q
  git config user.name "operator"
  git config user.email "operator@example.com"
fi

popd >/dev/null
echo "[+] Created engagement skeleton: ${ROOT_DIR}"
