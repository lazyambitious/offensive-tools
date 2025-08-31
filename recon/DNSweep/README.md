# 🌐 DNSweep

**DNSweep** is a lightweight, portable **DNS subdomain enumeration**
tool for offensive security operators, penetration testers, and CTF
players.

It performs DNS lookups across common record types, enumerates
subdomains from a wordlist, and optionally attempts **zone transfers
(AXFR)** against authoritative name servers.

> Minimal dependencies. Accurate results. First-hour recon clarity.

------------------------------------------------------------------------

## ✨ Features

-   🔍 **Subdomain resolution** --- expand a wordlist into FQDNs and
    resolve them.\
-   📋 **Multiple record types** --- A, AAAA, MX, NS, TXT, CNAME, SOA,
    SRV (default set).\
-   🗝️ **Zone transfer attempts** --- optional AXFR checks against
    authoritative NS.\
-   📂 **Organized output** --- per-host text files + consolidated TSV
    of all findings.\
-   ⚡ **Portable & minimal** --- POSIX `sh`, no Bash-isms; works on
    Linux, macOS, WSL.\
-   ⏱️ **Fast & safe defaults** --- `+time=2 +tries=1` to avoid hangs.

------------------------------------------------------------------------

## 📦 Requirements

-   `dig` (from `bind-utils` or `dnsutils`)\
-   Standard UNIX utilities (`sh`, `date`, `mkdir`, `sed`, `tr`)

------------------------------------------------------------------------

## 🚀 Usage

``` sh
dnsweep.sh [-r RESOLVER] [-t TYPES] [-o OUTDIR] [--axfr] DOMAIN SUBDOMAINS_FILE
```

### Arguments

-   **DOMAIN** -- base domain/zone (e.g., `example.com`).\
-   **SUBDOMAINS_FILE** -- file with subdomains, one per line.
    -   Accepts short labels (e.g., `www`) → expands to
        `www.example.com`.\
    -   Accepts fully qualified names (FQDNs) as-is.

### Options

-   `-r RESOLVER` -- use specific DNS resolver (e.g., `1.1.1.1`).
    Default: system resolver.\
-   `-t TYPES` -- comma-separated RR types (default:
    `A,AAAA,MX,NS,TXT,CNAME,SOA,SRV`).\
-   `-o OUTDIR` -- output directory (default: `dns/run_<timestamp>`).\
-   `--axfr` -- attempt zone transfer against authoritative NS for
    DOMAIN.\
-   `-h, --help` -- show usage.

------------------------------------------------------------------------

## 📂 Output Structure

    dns/run_20250831_143055/
    ├─ findings.tsv         # fqdn<TAB>type<TAB>value (all results)
    ├─ hosts/
    │   ├─ www.example.com.txt
    │   ├─ mail.example.com.txt
    │   └─ api.example.com.txt
    └─ axfr/                # only if --axfr enabled
        ├─ ns1.example.com.zone
        └─ ns2.example.com.zone

-   **Per-host text files**: grouped by record type for readability.\
-   **findings.tsv**: machine-friendly, easy to grep, cut, or import.\
-   **axfr/**: saved AXFR dumps (if any succeed).

------------------------------------------------------------------------

## ⚡ Quick Examples

### Basic run

``` sh
./dnsweep.sh example.com subdomains.txt
```

### Use a custom resolver

``` sh
./dnsweep.sh -r 1.1.1.1 corp.example.com subs.txt
```

### Specify record types

``` sh
./dnsweep.sh -t A,AAAA,TXT example.org subs.txt
```

### Attempt zone transfer

``` sh
./dnsweep.sh --axfr target.com subs.txt
```

------------------------------------------------------------------------

## 🔐 Operator Notes

-   Always respect scope --- **only run AXFR checks if authorized**.\
-   Subdomain takeovers often appear in `CNAME` results pointing to
    third-party services.\
-   Use the consolidated TSV for easy pivoting into other tooling (grep,
    awk, jq).

------------------------------------------------------------------------

## 🧾 License

MIT --- use freely, attribution appreciated.

------------------------------------------------------------------------

> **DNSweep:** Sweep the DNS landscape. Reveal the hidden hosts.
