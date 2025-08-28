# Engagement Bootstrap Kit

## Quick Start
```bash
chmod +x bootstrap.sh
./bootstrap.sh ILF_ADlab --init-git
cd ILF_ADlab
set -a; source .env; set +a
# run a network scan
ops/scripts/nmap_smart.sh "$SUBNET"
# wrap any command with logging
ops/scripts/logwrap.sh enum/misc/mycmd_$(date +%s).log -- echo "hello engagement"
```
See `ops/scripts/bootstrap_readme.txt` after generating an engagement.
