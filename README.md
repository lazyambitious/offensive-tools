# 🛠️ offensive-tools

**offensive-tools** is a collection of lightweight, portable scripts and
utilities for offensive security operators, red teamers, and learners.

This repo is built with a **"learn by building"** philosophy:\
\> Writing tools forces you to deeply understand the foundations of
offensive tradecraft. By automating, abstracting, and scripting the
workflow, you build both engineering skill and operational intuition.

------------------------------------------------------------------------

## 📑 Table of Contents

-   [🎯 Goals](#-goals)
-   [📂 Repo Organization](#-repo-organization)
    -   [Engagement Scaffolding](#engagement-scaffolding)
    -   [Recon & Enumeration](#recon--enumeration)
-   [🚀 Philosophy](#-philosophy)
-   [⚡ Getting Started](#-getting-started)
-   [🔐 Disclaimer](#-disclaimer)
-   [🧾 License](#-license)
-   [📌 Roadmap / Ideas](#-roadmap--ideas)

------------------------------------------------------------------------

## 🎯 Goals

-   **Learn by doing** --- each tool exists because it solved a real
    need in a lab, CTF, or engagement.\
-   **Automate the manual** --- common enumeration, recon, and
    organization tasks turned into repeatable scripts.\
-   **Stay organized** --- enforce clean structure so operators don't
    drown in unstructured outputs.\
-   **Share openly** --- others can download, use, adapt, and hopefully
    accelerate their own learning.

------------------------------------------------------------------------

## 📂 Repo Organization

### Engagement Scaffolding

-   [**CleanRoom**](cleanroom/README.md) --- bootstrap a clean directory
    structure for ops (first script to run).

### Recon & Enumeration

-   [**DNSweep**](recon/dnsweep/README.md) --- subdomain + DNS record
    enumeration with optional AXFR checks.\
-   [**Sniffle**](recon/sniffle/README.md) --- passive network listener for
    broadcast, DNS, and AD signals.

### (More coming...)

-   Credential attacks, pivoting helpers, reporting tools, etc.

Each tool includes its own `README.md` with usage, requirements, and
examples.

------------------------------------------------------------------------

## 🚀 Philosophy

This repo is not about creating "the next big framework." Instead:\
- **Minimalism:** one small script per need, POSIX-sh where possible,
zero external deps.\
- **Portability:** works out of the box on Kali, common Linux distros,
and (with care) macOS/WSL.\
- **Transparency:** plain shell scripts you can read, audit, and modify
easily.\
- **Operator mindset:** every script reflects the kinds of problems an
operator faces in the first hours of an operation.

------------------------------------------------------------------------

## ⚡ Getting Started

Clone the repo:

``` sh
git clone https://github.com/<your-username>/offensive-tools.git
cd offensive-tools
```

Make scripts executable:

``` sh
chmod +x *.sh
```

Run tool help:

``` sh
./cleanroom.sh --help
./dnsweep.sh --help
./sniffle.sh --help
```

------------------------------------------------------------------------

## 🔐 Disclaimer

These tools are for **educational and authorized testing only**.\
Do not use them against systems or networks you do not own or have
explicit permission to test.

------------------------------------------------------------------------

## 🧾 License

MIT --- free to use, modify, and share. Attribution appreciated.

------------------------------------------------------------------------

## 📌 Roadmap / Ideas

-   Credential attacks (Kerberos roasting, password spraying helpers).\
-   Post-exploitation organization helpers (hashes, dumps, loot mgmt).\
-   Pivoting/tunneling wrappers.\
-   Reporting scaffolds.

------------------------------------------------------------------------

> **offensive-tools**: An engineering approach to learning and
> implementing offensive security TTPs --- one script at a time.
