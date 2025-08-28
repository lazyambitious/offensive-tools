# 🚀 Quick Start – Bootstrap Kit

A lightweight kit for staying organized during engagements, labs, or CTFs.
Keeps artifacts cleanly separated.


## 1. Setup
```
chmod +x bootstrap.sh
```

## 2. Generate a New Engagement Skeleton
```
./bootstrap.sh ILF_ADlab --init-git
cd ILF_ADlab
```

## 3. Load Convenience Environment Variables
```
set -a; source .env; set +a
```

## 4. Example Scans with Smart Logging
```
ops/scripts/nmap_smart.sh "$SUBNET"
ops/scripts/cme_smart.sh smb "$SUBNET" -u "$USER" -p "$PASS" --shares
```

## 5. Wrap *Any* Command & Capture Console Output
```
ops/scripts/logwrap.sh enum/misc/mycmd_$(date +%s).log -- echo "hello"
```

---

# 📂 Structure

```
ILF_ADlab/
├── enum/{nmap,ldap,smb,sniff,misc}
├── creds/{hashes,cracked,keys}
├── loot/{files,sysvol,dumps}
├── ops/{bins,scripts,shell}
├── notes/{ops.md,findings.md,todo.md}
├── rpt/{screenshots,timeline.md,draft.md}
├── tmp/
├── .env
└── .gitignore
```

---

# 🤔 Why These Choices?

- **Short names** = faster typing during ops  
  (enum, creds, loot, ops, rpt, tmp)

- **Separation of Concerns**  
  - enum/ = raw facts (re-runnable, parsable)  
  - creds/ = authentication artifacts (single source of truth)  
  - loot/ = client data (easy to sanitize/handoff)  
  - ops/ = your tooling (scrubbable)  
  - notes/, rpt/ = narrative + evidence for reporting  

- **tee + native output** = keep structured tool outputs + console logs for reports/timelines

---

# 🛠️ Included Helpers

### ops/scripts/nmap_smart.sh
- Saves -oA outputs to enum/nmap/  
- Console log (*_console.txt) with timestamps

### ops/scripts/cme_smart.sh
- Wraps CrackMapExec for SMB/WinRM  
- Logs to enum/smb/ with timestamped filenames

### ops/scripts/logwrap.sh
- Generic tee wrapper  
```
logwrap.sh enum/misc/run_$(date +%s).log -- <your command>
```

### .env
- Stores domain, DC IP, user, pass, subnet  
```
set -a; source .env; set +a
```

### .gitignore
- Excludes sensitive artifacts (creds, loot, dumps, screenshots, tmp)  
- Keeps Markdown notes & parsable nmap outputs  

---

# 📑 Templates You Can Lean On

- notes/ops.md – living ops log (syllabus-style sections)  
- notes/findings.md – rolling finding list with evidence links  
- notes/todo.md – bite-sized tasks (don’t lose threads)  
- rpt/timeline.md – timestamped actions (report-ready)  
- rpt/draft.md – structure for the final write-up  
