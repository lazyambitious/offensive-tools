# 👂 Sniffle

**Sniffle** is a lightweight, portable, passive network recon tool.\
It captures broadcast, DNS, and Active Directory--related traffic to
give operators **early, low‑noise visibility** into a network after
gaining a foothold.

------------------------------------------------------------------------

## ✨ Features

-   👂 **Passive capture** --- observe traffic without active probing.\
-   🎯 **Mode presets** ---
    -   `bcast` → ARP, NBNS, LLMNR, mDNS (host discovery).\
    -   `ad-core` → Kerberos, LDAP, SMB, RPC, Global Catalog, kpasswd,
        ADWS.\
    -   `dns` → DNS queries & responses (53/tcp,udp).\
    -   `all` → Capture everything (use with care).\
-   📂 **Organized outputs** --- timestamped run dirs with `pcap/` and
    `summary.log`.\
-   🛡️ **Stealthy recon** --- ideal for red team ops and lab exercises
    where noise matters.\
-   ⚡ **Portable** --- POSIX `sh`, no Bash‑isms; works on Linux, macOS
    (with tcpdump).

------------------------------------------------------------------------

## 📦 Requirements

-   `tcpdump`\
-   `awk`\
-   `date`, `mkdir`, `sh`\
-   `timeout` (Linux) or `gtimeout` (macOS via coreutils) for duration
    control

Run as **root** or with `sudo`, since `tcpdump` requires elevated
privileges.

------------------------------------------------------------------------

## 🚀 Usage

``` sh
sniffle.sh [--mode MODE] [--iface IFACE] [--secs N]
           [--rotate-secs N] [--max-mb N]
           [--outroot DIR] [--tag NAME]
           [--quiet] [--dry-run] [-h|--help]
```

### Modes

-   `bcast` (default) → capture broadcast/multicast (ARP, NBNS, mDNS,
    LLMNR).\
-   `ad-core` → capture core Active Directory protocols.\
-   `dns` → capture DNS traffic.\
-   `all` → capture all IP traffic.

### Common Options

-   `--iface IFACE` → network interface (auto-detects if not given).\
-   `--secs N` → limit duration with timeout.\
-   `--rotate-secs N` → rotate pcap every N seconds.\
-   `--max-mb N` → rotate pcap when it reaches N MB.\
-   `--outroot DIR` → base directory (default: `enum/sniff`).\
-   `--tag NAME` → add a custom label to output folder.\
-   `--quiet` → suppress console messages.\
-   `--dry-run` → show what would run without capturing.

------------------------------------------------------------------------

## 📂 Output Structure

    enum/sniff/run_20250831_144210_labA/
    ├─ pcap/
    │   ├─ sniffle.pcap
    │   └─ sniffle.20250831_144210.pcap   # if rotating
    └─ summary.log

-   **pcap/** → raw captures for offline analysis in Wireshark/tshark.\
-   **summary.log** → human‑readable quicklook with DNS queries,
    Kerberos/LDAP/SMB hints, ARP/NBNS activity.

------------------------------------------------------------------------

## ⚡ Quick Examples

### Passive host discovery

``` sh
sudo ./sniffle.sh --mode bcast --secs 60
```

### Capture Active Directory core traffic

``` sh
sudo ./sniffle.sh --mode ad-core --iface eth0 --rotate-secs 300
```

### DNS reconnaissance

``` sh
sudo ./sniffle.sh --mode dns --tag labA
```

### Full capture (caution)

``` sh
sudo ./sniffle.sh --mode all --secs 30
```

------------------------------------------------------------------------

## 🔐 Operator Notes

-   Designed for **first‑hour recon** after landing inside a network.\
-   Provides **zero‑touch visibility** before launching active scans.\
-   `summary.log` highlights DNS SRV lookups, Kerberos traffic, and
    NBNS/LLMNR hostnames.\
-   Large/long captures can grow quickly --- use `--rotate-secs` or
    `--max-mb`.

------------------------------------------------------------------------

## 🧾 License

MIT --- free to use, modify, and share.

------------------------------------------------------------------------

> **Sniffle:** A quiet way to listen for network whispers.
