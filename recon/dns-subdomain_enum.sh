#!/bin/bash

# ────────────────────────────────────────────────────────────────
# DNS Subdomain Enumerator with Record Queries + AXFR
# Description: Queries all major DNS records and attempts AXFR
# Author: @threatzilla
# Example: ./dns-subdomain_enum.sh <resolver_ip> <subdomains.txt>
# ────────────────────────────────────────────────────────────────

RESOLVER="$1"
SUBFILE="$2"
OUTDIR="dns_results_$(date +%Y%m%d_%H%M%S)"
RECORD_TYPES=("A" "AAAA" "MX" "NS" "TXT" "CNAME" "SOA")

# ───── Input Validation ─────
if [[ -z "$RESOLVER" || -z "$SUBFILE" ]]; then
  echo "Usage: $0 <resolver_ip> <subdomain_file>"
  exit 1
fi

if [[ ! -f "$SUBFILE" ]]; then
  echo "[!] Subdomain file '$SUBFILE' not found."
  exit 1
fi

mkdir -p "$OUTDIR"
touch "$OUTDIR/quick_results.txt"

echo "[*] Starting DNS enumeration using resolver: $RESOLVER"
echo "[*] Output directory: $OUTDIR"
echo "[*] Total subdomains: $(wc -l < "$SUBFILE")"
echo "────────────────────────────────────────────────────────"

# ───── Main Loop ─────
while read -r SUB; do
  echo -e "\n[+] Enumerating: $SUB"
  SUB_OUT="$OUTDIR/${SUB}.txt"
  touch "$SUB_OUT"

  echo "[$SUB]" >> "$OUTDIR/quick_results.txt"

  # Per-record DNS queries
  for TYPE in "${RECORD_TYPES[@]}"; do
    echo "    → Querying $TYPE"
    RESULT=$(dig @"$RESOLVER" "$SUB" "$TYPE" +short)

    if [[ -n "$RESULT" ]]; then
      echo -e "\n--- $TYPE RECORD ---" >> "$SUB_OUT"
      echo "$RESULT" >> "$SUB_OUT"
      echo "    [+] Found $TYPE records" | tee -a "$SUB_OUT"
      echo "  • $TYPE record(s) found" >> "$OUTDIR/quick_results.txt"
    else
      echo "    [ ] No $TYPE records" >> "$SUB_OUT"
    fi
  done

  # Attempt AXFR
  echo "    → Attempting AXFR..."
  AXFR_RESULT=$(dig AXFR @"$RESOLVER" "$SUB")

  if echo "$AXFR_RESULT" | grep -qi "Transfer failed"; then
    echo "    [!] Zone transfer failed" >> "$SUB_OUT"
  elif echo "$AXFR_RESULT" | grep -qi "XFR size"; then
    ZONE_FILE="$OUTDIR/${SUB}_zone_transfer.txt"
    echo "$AXFR_RESULT" > "$ZONE_FILE"
    echo "    [+] Zone transfer successful!" | tee -a "$SUB_OUT"
    echo "  • Zone Transfer SUCCESS — saved to: $(basename "$ZONE_FILE")" >> "$OUTDIR/quick_results.txt"
  elif echo "$AXFR_RESULT" | grep -qi "SOA"; then
    ZONE_FILE="$OUTDIR/${SUB}_zone_transfer.txt"
    echo "$AXFR_RESULT" > "$ZONE_FILE"
    echo "    [+] Partial zone transfer detected" | tee -a "$SUB_OUT"
    echo "  • Partial Zone Transfer (check manually): $(basename "$ZONE_FILE")" >> "$OUTDIR/quick_results.txt"
  else
    echo "    [ ] AXFR attempt inconclusive" >> "$SUB_OUT"
  fi

  echo "" >> "$OUTDIR/quick_results.txt"
done < "$SUBFILE"

echo -e "\n[✔] Enumeration complete. See results in: $OUTDIR"
echo "[📋] Quick summary: $OUTDIR/quick_results.txt"
