# 🧹 CleanRoom

**CleanRoom** is a lightweight bootstrap tool for offensive security operators.  
It sets up a **clean, shallow, and consistent directory skeleton** for engagements, labs, or CTFs — so you can stop worrying about file sprawl and stay focused on the operation.  

> First script you run. Zero overhead. Instant structure.  

---

## ✨ Features

- **Portable & minimal** — POSIX-`sh`, no dependencies beyond coreutils.  
- **Shallow, intuitive structure** — no 5-deep paths; easy to remember.  
- **Profiles** — extend base skeleton with optional AD or Web directories.  
- **Safe by default** — won’t clobber existing files unless `--force`.  
- **Optional Git init** — add versioning and a sane `.gitignore`.  
- **Seeded notes & report stubs** — operators can start documenting immediately.  

---

## 📂 Directory Layout

The generated skeleton (base + optional profiles):
```sh
<ENG_NAME>/
├─ enum/           # Recon & discovery artifacts
│ ├─ net/          # Sweeps, port scans, host discovery
│ ├─ ad/           # [optional] LDAP, CME, BloodHound (AD profile)
│ └─ web/          # [optional] Web recon/enum (Web profile)
│
├─ creds/          # Credential materials
│ ├─ hashes/       # NTLM/kerberoast/etc
│ ├─ cracked/      # Cracker results (hashcat/john)
│ └─ keys/         # id_rsa, API keys, jwt, kirbi, etc.
│
├─ data/           # Files you acquire
│ ├─ files/        # Drops, downloads
│ ├─ dumps/        # Memory/db dumps, pcaps
│ └─ sysvol/       # GPO/scripts pulls [AD profile]
│
├─ ops/            # Engagement-specific
│ └─ tools/        # Tools, PoCs, wordlists, exploits
│
├─ notes/          # Working notes
│ ├─ ops.md        # Daybook / commands / gotchas
│ ├─ findings.md   # Leads, vuln evidence, creds linkage
│ └─ todo.md       # Short task queue
│
├─ rpt/            # Reporting artifacts
│ ├─ screenshots/
│ └─ timeline.md
│
├─ tmp/            # Scratch space (safe to purge)
│
├─ .env            # Engagement vars (DOMAIN, USER, SUBNET, etc.)
├─ .gitignore      # Ignore sensitive/large artifacts (if --init-git)
└─ README.md       # Skeleton usage notes
```

---

## 🚀 Usage

Basic
```sh
./cleanroom.sh MyEngagement
```

With profiles
```sh
# Create with AD + Web subfolders
./cleanroom.sh CorpNet --profile ad,web
```

With Git init
```sh
./cleanroom.sh CTF-01 --init-git

Options
--profile X     Comma list: ad, web, all, none (default: none)
--init-git      Initialize a git repo with a sane .gitignore
--force         Overwrite existing files / reuse directory
--dry-run       Show actions without creating
--quiet         Suppress info output
-h, --help      Show help
```

## ⚡ Quick Start Workflow
### 1) Generate skeleton
```sh
./cleanroom.sh ACME-Red --profile ad,web --init-git
```

### 2) Load environment helpers
```sh
cd ACME-Red
set -a; . ./.env; set +a
```

### 3) Drop custom tools into ops/tools/ (added to PATH)

### 4) Save artifacts directly into structured dirs
```sh
nmap -sV -Pn "$SUBNET" -oA "enum/net/nmap_$(date -u +%Y%m%d_%H%M%S)"
cme smb "$SUBNET" -u "$USER" -p "$PASS" --shares | tee "enum/ad/cme_shares.log"
httpx -l hosts.txt -json -o "enum/web/httpx.json"
```

---

## 🛡️ Conventions
- Artifacts live close to their domain (enum/net, enum/web, data/dumps, etc).
- Engagement-specific tools (wordlists, PoCs, wrappers) go in ops/tools.
- Documentation first: keep running notes in notes/ops.md and notes/findings.md.
- Scratch safely: put temporary files in tmp/ — safe to wipe.
- Keep secrets local: .env is created with chmod 600 and is ignored by git.

---

## 📌 Example Profiles
- **Base (always)**: enum/net, creds, data/files, ops/tools, notes, rpt, tmp.
- **AD profile**: adds enum/ad + data/sysvol.
- **Web profile**: adds enum/web.

---

## 🧾 License
MIT — do what you want, but credit appreciated.

---
> CleanRoom: Start every engagement in a clean, organized workspace.