

# CPTC Team Repositories — Consolidated Index

This document merges four separate CPTC (Collegiate Penetration Testing Competition) team-tooling repository analyses into one cohesive reference. It has two goals:

1. **Index each repository** — a short, anonymized profile of what each repo *is* and what it contains.
2. **Index the tooling for a CPTC competition** — a combined, phase-oriented catalog that cross-references every tool and resource across all four repos, so an operator can find the right tool regardless of which team originally shipped it.

Team/university names have been removed from the narrative and replaced with neutral codenames. Where the same tool appears in multiple repos, that overlap is called out — overlap is a strong signal of what is genuinely load-bearing in a CPTC engagement.

> **Scope note:** "General use case" descriptions are illustrative of each tool's established purpose. A tool being present in, or installable by, a repository is *not* evidence that a team actually deployed it in competition. OT/ICS tooling in particular reflects preparation hypotheses, not confirmed engagement scope.

---

## Repository Index

| Codename | Character | Primary focus | Repository |
| --- | --- | --- | --- |
| **Repo A — Bootstrap Kit** | Shell installers + pre-staged binaries | One-shot provisioning of a Linux attack box, plus a bundled Windows/AD offensive binary set and a pivoting tool | [link](https://github.com/nationalcptc-teamtools/University-Of-South-Florida) |
| **Repo B — IT/OT Preparation & Evidence Toolkit** | Python tooling + Bash/PowerShell runners | Scoped enumeration runners, a 40-entry IT/OT tool catalog, offline reporting, evidence provenance, and human-review workflow | [link](https://github.com/nationalcptc-teamtools/United-States-Military-Academy) |
| **Repo C — Curated Toolkit Reference** | Documentation-first tool guide | A well-documented, per-tool reference covering the full recon → exploit → AD → report workflow, with usage examples and team notes | [link](https://github.com/nationalcptc-teamtools/Princess-Sumaya-University-for-Technology) |
| **Repo D — Script Collection & Deployment Aids** | Independent scripts + reference datasets | A collection of standalone recon/analysis scripts, deployment automation, compliance baselines, and a reporting tool | [link](https://github.com/nationalcptc-teamtools/Rochester-Institute-of-Technology) |

---

## Repo A — Bootstrap Kit

*Repository: [nationalcptc-teamtools/University-Of-South-Florida](https://github.com/nationalcptc-teamtools/University-Of-South-Florida)*

### Summary

A bootstrap kit: a set of shell installers that turn a fresh Debian/Kali-style box into a ready-to-use engagement workstation, plus a bundle of pre-staged Windows/Active Directory offensive binaries, a tunneling tool, an Nmap output parser, and terminal/multiplexer configuration. Written for a zsh user on a `bookworm` base. Minimal README; the intended install order is the authoritative documentation.

### Tools

| Component | Purpose |
| --- | --- |
| `letsgo.sh` | Primary bootstrap installer (run first, as root). Lays down `/opt/tools`, installs the core toolset (Nmap, Metasploit, John, Hydra, Hashcat, etc.) via apt/pipx, installs Docker + Go, configures `.zshrc` PATHs, optionally installs SecLists, wires in the Nmap parser and tmux setup. |
| `else.sh` | Active Directory / internal-network installer: Impacket, evil-winrm, Responder, krbrelayx, Certipy, mitm6, coercer, BloodyAD, NetExec, Chisel, Kerbrute. Each install guarded with `\|\| true`; has a removable debug-confirm wrapper. |
| `windows.sh` | **Web-application** tooling (name is misleading): Gobuster, sqlmap, whatweb, sslscan, ffuf, dirsearch, Burp Suite, feroxbuster, linPEAS, plus Go installs of Nuclei, httpx, katana, hakrawler, gowitness. |
| `fixtmux.sh` | Builds latest `tmux` from source and installs a tuned `.tmux.conf` with auto-logging to `~/logs/tmux` (evidence capture), TPM plugins, vi keys, 250k history, and a tmuxinator layout with an `msf` window. |
| `bloodhound_setup.sh` | Installs Docker/Compose and SpecterOps BloodHound CLI, then runs BloodHound CE for AD attack-path mapping. Refuses to run as root directly (needs `$SUDO_USER`). |
| `tools/ultimate-nmap-parser.sh` | Standalone Bash parser (by Shifty0g) that converts Nmap greppable output (`.gnmap`) into CSVs, host/port lists, service-split files, and SMB/web/SSL target lists. Ships `--help`; `--all` writes everything into `parse/`. |
| `tools/windows/` | Pre-staged Windows/AD binaries: mimikatz, Rubeus, SigmaPotato, Seatbelt, SharpUp, SharpView, Snaffler, plus PowerShell PowerView/PowerUp/Powermad/Inveigh, and a `godap` TUI LDAP client. Committed directly (expect AV/EDR flags). |
| `tools/ligolo-ng/` | Prebuilt Ligolo-ng (Linux + Windows `agent`/`proxy`) — reverse TCP/TLS tunneling via a `tun` interface instead of SOCKS/proxychains. |

**Install sequence:**
```bash
git clone https://github.com/nationalcptc-teamtools/University-Of-South-Florida && cd University-Of-South-Florida
chmod +x ./letsgo.sh && sudo ./letsgo.sh
source ~/.zshrc
bash else.sh
bash windows.sh
```

### Learning / Resources

- `README.md` — terse clone-and-run runbook (authoritative install order).
- `tools/ligolo-ng/.../README.md` — vendored upstream Ligolo-ng docs; explains the tun-interface model vs. SOCKS/Chisel and the Nmap `--unprivileged`/`-PE` caveat. Links to <https://docs.ligolo.ng/>.
- `configs/config.kdl` — a personal Zellij multiplexer config (vim-style nav, Catppuccin Mocha); a shareable alternative to the tmux setup.
- In-script docs — `ultimate-nmap-parser.sh` carries its own `--help` and a developer roadmap/known-bugs header.

---

## Repo B — IT/OT Preparation & Evidence Toolkit

*Repository: [nationalcptc-teamtools/United-States-Military-Academy](https://github.com/nationalcptc-teamtools/United-States-Military-Academy)*

### Summary

A preparation and evidence-management toolkit with two real network-enumeration runners (Bash for Linux, PowerShell for Windows) plus a set of Python modules for tool preparation, synthetic reporting, and human review. Both runners freeze explicit target scope, retain raw evidence and command logs, and generate local summaries. A 40-entry "farmkit" catalog (heavily IT/OT-focused) is a *selection and rehearsal resource*, not 40 custom tools. Emphasis throughout is on repeatable setup, evidence provenance, and human review. Reporting input remains synthetic-only by design.

### Tools — Repository automation (first-party)

| Component | Purpose |
| --- | --- |
| `cptc-linux.sh` | Scoped Linux enumeration: discovery, TCP/optional UDP, service ID, protocol follow-ups, optional web/vuln phases, raw-evidence preservation, Markdown/HTML/CSV/JSON reports, resume, and operator logging. Profiles `quick\|standard\|deep`. OT ports are quarantined from generic NSE probing. |
| `cptc-windows.ps1` | Scoped Windows enumeration on PowerShell 5.1: installs/locates Nmap/httpx/Nuclei/ffuf, freezes IPv4 scope, local inventory, network/web enum, optional AD metadata, normalized CSV/JSON + HTML report, resume. |
| `cptc-collect-logs.sh` | End-of-session operator evidence archive: shell history, session transcripts, auditd/journald, process accounting, sudo I/O; hashes everything into `MANIFEST.txt` (0600 perms). |
| `install.sh` / `tooling/farmkit/install.py` | Core/full assessment-suite preparation: plans, acquires/builds, inventories, and checks packages, isolated Python envs, native OT clients, reporting deps, and hash-checked PEASS assets. Prepares, does not execute. |
| `tools.py` / `tooling/farmkit/onboard.py` | Individual tool/bundle preparation and drift checking (`list\|show\|plan\|install\|check`, `--bundle qa\|sensors\|labs\|runner`). |
| `tooling/farmkit/kit.py` | Catalog/source/lock/readiness validation, filtering, local artifact hash verification, readiness reporting. |
| `tooling/farmkit/build.py` | Deterministic, allowlist-based source-only ZIP builder for sharing/recovering reviewed prep code. |
| `tooling/reporting/reportgen.py` + `updates.py` | Offline report generator: validates synthetic report JSON → canonical JSON/Markdown + optional PDF/Word with hashes; applies curated evidence/finding updates. Never overwrites exports. |
| `tooling/workbench/workbench.py` | Development workbench: tool discovery/compare, scaffolds, synthetic records, finding review/authoring, evidence append, dedupe/merge, snapshots, and manual handoff packages. |
| `config.py` | Legacy interactive scope-file wizard (writes `{"ranges":[],"hosts":[]}` JSON for the Windows runner). |
| `super_nmap.py` | Retired compatibility entrypoint — parses legacy flags and exits 2; performs no scan. |

### Tools — IT/OT & assessment catalog (third-party, 40 entries + runner integrations)

The catalog's defining feature is deep **OT/ICS/IoT protocol** coverage, which is unusual among CPTC repos. Grouped by protocol/function:

- **Traffic & packets:** Wireshark/TShark, Zeek, Suricata, Scapy
- **Modbus:** PyModbus, mbpoll, libmodbus, MinimalModbus
- **Siemens S7:** python-snap7
- **EtherNet/IP · CIP:** cpppo, pycomm3
- **OPC UA:** asyncua / opcua-asyncio, open62541
- **BACnet:** BACpypes3, BACnet Stack
- **MQTT:** Mosquitto clients/broker, Eclipse Paho (Python)
- **Power/utility (IEC/DNP3/DLMS):** lib60870, libiec61850, OpenDNP3 (archived), Gurux DLMS Python
- **CAN bus:** can-utils, python-can, cantools, canopen
- **UAV/robotics:** pymavlink
- **LoRaWAN:** ChirpStack · **Zigbee:** zigpy
- **PLC/SCADA/HMI & honeypot:** OpenPLC Runtime v4, FUXA, Node-RED, Conpot
- **Host/IT enum & exploitation:** LinPEAS, WinPEAS, enum4linux-ng, NetExec, Impacket, testssl.sh, ffuf, Metasploit Framework
- **Runner-integrated recon:** Nmap, ProjectDiscovery httpx, Nuclei, curl, WhatWeb, Nikto, Gobuster + SecLists, smbclient/rpcclient, ldapsearch, dig, snmpwalk, rpcinfo/showmount, ssh-keyscan/ssh-audit, sslscan, Swaks, SearchSploit/Exploit-DB
- **Build/report support:** Syft (SBOM), pip-tools, LibreOffice Writer, ReportLab, python-docx
- **Optional/installation-only:** Prowler, wkhtmltopdf, Vulscan, arp-scan, onesixtyone, ipmitool, EyeWitness, OpenSSL, netcat-openbsd, jq, xsltproc

> Many catalog entries are libraries/SDKs rather than target-facing CLIs; several carry explicit license/runtime **holds** (e.g. PEASS, Impacket, OpenDNP3, Vulscan).

### Learning / Resources

Extensive Markdown documentation — operator guides (`README.md`, `docs/USER-GUIDE.md`, workflow diagrams), the full 40-entry tool guide (`docs/TOOL-GUIDES.md`), runbooks for offline PCAP review and bounded protocol rehearsals, report templates/examples (`tooling/reporting/templates/`, `examples/`), workbench contracts/handover docs, onboarding design/review/verification records, and readiness/policy records. Links the [official CPTC rulebook](https://cp.tc/docs/cptc-rules.pdf) and [historical CPTC report examples](https://github.com/globalcptc/report_examples).

---

## Repo C — Curated Toolkit Reference

*Repository: [nationalcptc-teamtools/Princess-Sumaya-University-for-Technology](https://github.com/nationalcptc-teamtools/Princess-Sumaya-University-for-Technology)*

### Summary

A documentation-first reference of free/open-source tooling the team uses for CPTC. Each tool gets a detailed card (functionality, general + specific use cases, team notes, copy-paste usage). Because CPTC is scored on the written report and executive debrief as well as technical findings, reporting and evidence-capture tooling is treated as first-class alongside offensive tools. This is the best repo for *how to actually use* each tool.

### Tools (by workflow)

- **Recon/enum:** Nmap, enum4linux-ng, smbmap/smbclient, onesixtyone + snmpwalk, Subfinder/Amass, theHarvester, gowitness
- **Exploitation:** searchsploit, Metasploit (incl. msfvenom), Hydra, netcat/pwncat
- **Priv-esc:** PEASS-ng (linPEAS/winPEAS), pspy
- **Pivoting:** ligolo-ng / chisel + proxychains
- **Credentials/cracking:** Responder, hashcat / John the Ripper, pypykatz / mimikatz
- **Web:** Burp Suite Community / OWASP ZAP, ffuf / feroxbuster, sqlmap, nuclei, wpscan, whatweb / nikto
- **Active Directory:** BloodHound + SharpHound, NetExec (nxc), Impacket, Kerbrute, Certipy, evil-winrm, PowerView
- **Reporting/notes/evidence:** SysReptor, Pwndoc, Ghostwriter, Obsidian / CherryTree, Flameshot / Greenshot

Each card includes practical team notes — e.g. "don't use Nmap `-A` (too loud for detection scoring)", two-stage scanning, always `-oA`; spray don't brute against AD; run Metasploit `check` before `run`.

### Learning / Resources

HackTricks, PayloadsAllTheThings, GTFOBins / LOLBAS, revshells.com, SecLists, the CPTC reporting guidelines + sample reports, the CVSS v3.1 calculator, HackTheBox / TryHackMe (+ IppSec), and a competitor's CPTC strategy write-up. Recurring theme in the notes: **breadth of documented findings + a strong report/debrief beats deep single-box heroics.**

**Sources cited by this repo:** [CPTC Overview](https://cp.tc/overview) · [CPTC Compete](https://cp.tc/compete) · [Competitor write-up](https://atch2203.github.io/blog/posts/an-uncomprehensive-guide-to-doing-well-in-cptc) · [UMass intro-pentesting slides](https://umasscybersec.org/files/slides/fall-2025/intro-pentesting.pdf) · [Hurricane Labs CPTC resource list](https://hurricanelabs.com/blog/global-collegiate-penetration-testing-competition-industry-resource-list/) · [SysReptor reporting-tools list](https://docs.sysreptor.com/s/pentest-reporting-tools) · [TCM Security top-5 AD tools](https://tcm-sec.com/top-5-tools-for-active-directory-penetration-testing/)

---

## Repo D — Script Collection & Deployment Aids

*Repository: [nationalcptc-teamtools/Rochester-Institute-of-Technology](https://github.com/nationalcptc-teamtools/Rochester-Institute-of-Technology)*

### Summary

A collection of independent cybersecurity scripts, deployment aids, reference datasets, and documentation. It is **not** one integrated application; several components are older and need updated dependencies, validation, or security fixes before operational use. Strongest in bulk scanning/parsing automation, Windows host-baseline comparison, compliance references, and reporting.

### Tools

| Component | Purpose |
| --- | --- |
| `2020/linux/nmap/`, `2020/linux/services/` | Bash wrappers for host discovery, quick/full TCP, full UDP, and service-specific NSE (SSH, MySQL) scans. |
| `2020/lux/Interlace Scripts/` | Templated Nmap + Nikto scanning across a target list with concurrency (Interlace). |
| `2020/lux/Machine Setup Scripts/`, `2020/linux/cptc-install.sh`, `2020/web_iot/`, `2020/windows/` | Environment provisioning for Linux, web/IoT, and Windows (PTF-based) workstations. |
| `Deployment/`, `Deployment/simple_deploy/` | General and lightweight Kali deployment automation (Linux `.sh` + `windows_install.ps1`) driven by package/repo inventory lists. |
| `Networking/masscan_subnet.py` | Runs Masscan, parses open ports per host, optionally launches Nmap. |
| `Networking/csv.py` | Normalizes/merges CSV security/compliance results (Pandas). |
| `Networking/xml scanner` | Converts Nmap XML into an Excel workbook with notes/severity columns (openpyxl). |
| `FlaskMap/` | Distributed scanning: a Flask server queues scan commands to workers that upload results. (Needs HTTP/HTTPS + command-handling fixes before use.) |
| `Sprayer/` | Authorized credential spraying against selected services + Linux enumeration output parsing. |
| `password download scripts/` | Downloads wordlists, installs John the Ripper, automates offline hash testing. |
| `BrickStrike Vulnerability Validator/` | Configurable vulnerability-check framework (incomplete — missing tests/code defects). |
| `Windows/Filesystem/CPTC Windows Filesystem Analysis/` | C# generator + analyzer that compares a host's filesystem paths against per-OS Windows baselines to spot anomalies. |
| `Rex/` (Report Rex) | Turns structured Markdown findings into professional reports; ships packaged Linux builds and a VS Code extension. |

### Learning / Resources

READMEs and operational notes; example username/credential/target datasets; deployment package/repo inventories; Linux and Windows/AD deployment cheatsheets (PDF + text); per-OS Windows filesystem baselines; a large set of **CIS Benchmarks** (Docker, Kubernetes, AWS/Azure/GCP/OCI/IBM cloud, Apache, pfSense, Kerberos, MFD) and **PCI-DSS v4.0.1**; and password-wordlist source URL lists.

---

## Cross-Repository CPTC Tool Index

The combined catalog, organized by engagement phase. The **Repos** column shows where each capability appears (A/B/C/D) — multi-repo entries are the consensus "must-have" tools. Use Repo C for the clearest usage guidance and Repo A for the fastest install.

### 1. Recon & scanning
| Tool | Repos | Notes |
| --- | --- | --- |
| Nmap | A B C D | Universal. Two-stage scan, always `-oA`, avoid `-A`. |
| Masscan | D | Fast subnet sweep → feeds Nmap. |
| ProjectDiscovery httpx | A B | Live web-host probing. |
| Subfinder / Amass | C | External subdomain enumeration. |
| theHarvester | C | OSINT → username/email lists. |
| ultimate-nmap-parser | A | `.gnmap` → service-split target lists. |
| Nmap XML→XLSX / CSV merge | D | Reportable service inventory. |
| FlaskMap | D | Distributed scan orchestration. |

### 2. Web application
| Tool | Repos | Notes |
| --- | --- | --- |
| Burp Suite / OWASP ZAP | A C | Intercepting proxy; ZAP adds free scanner. |
| ffuf / feroxbuster / gobuster / dirsearch | A B C | Content & parameter fuzzing. |
| Nuclei | A B C | Templated CVE/misconfig scanning. |
| sqlmap | A C | SQL injection. |
| wpscan | C | WordPress. |
| whatweb / nikto | A B C D | Fingerprinting + quick misconfig checks; D orchestrates Nikto via Interlace. |
| gowitness / EyeWitness | A B C | Bulk web screenshots for triage. |
| katana / hakrawler | A | Crawling. |

### 3. SMB & network-service enumeration
| Tool | Repos | Notes |
| --- | --- | --- |
| enum4linux-ng | B C | One-shot SMB/RPC dump. |
| smbmap / smbclient | A C | Share discovery & looting. |
| onesixtyone + snmpwalk | B C | SNMP community spray + MIB walk (UDP — remember `-sU`). |
| ldapsearch / dig / rpcinfo / showmount / ssh-audit / sslscan / testssl.sh / Swaks | B | Protocol-specific checks in the Linux runner. |

### 4. Active Directory
| Tool | Repos | Notes |
| --- | --- | --- |
| BloodHound + SharpHound | A C | Attack-path graphing — highest-leverage AD tool. |
| NetExec (nxc) | A B C | Multi-protocol validate/enumerate/execute at scale. |
| Impacket | A B C | Kerberos attacks, remote exec, cred dumping. |
| Responder | A C | LLMNR/NBT-NS/mDNS poisoning → NetNTLM capture. |
| Kerbrute | A C | Kerberos user enum + spray. |
| Certipy | A C | AD CS (ESC1–ESC8) abuse. |
| evil-winrm | A C | Interactive WinRM shell. |
| PowerView / PowerUp / Powermad / Inveigh / Rubeus / Seatbelt / SharpUp / SharpView / Snaffler | A | Pre-staged on-host Windows kill-chain binaries. |
| mitm6 / coercer / bloodyAD / krbrelayx | A | IPv6 takeover, coercion, directory manipulation, relaying. |
| pypykatz / mimikatz | A C | LSASS credential/ticket extraction. |
| godap | A | TUI LDAP/AD browser. |

### 5. Privilege escalation
| Tool | Repos | Notes |
| --- | --- | --- |
| PEASS-ng (linPEAS / winPEAS) | A B C | Automated local priv-esc triage. (B holds execution pending license review.) |
| pspy | C | Unprivileged Linux cron/process monitor. |
| GTFOBins / LOLBAS | C | Reference — check `sudo -l` output against GTFOBins. |

### 6. Pivoting & tunneling
| Tool | Repos | Notes |
| --- | --- | --- |
| ligolo-ng | A C | tun-interface tunneling (no proxychains needed). |
| chisel + proxychains | A C | Classic SOCKS pivot. |

### 7. Credential attacks & cracking
| Tool | Repos | Notes |
| --- | --- | --- |
| hashcat / John the Ripper | A C D | Offline cracking. |
| Hydra | C | Online spraying/brute (mind AD lockout). |
| Sprayer | D | Authorized credential spraying + enum parsing. |
| password download scripts | D | Wordlist fetch + John automation. |

### 8. Exploitation & validation
| Tool | Repos | Notes |
| --- | --- | --- |
| Metasploit + msfvenom | A C | Run `check` before `run`; payload generation. |
| searchsploit / Exploit-DB | B C | Version → public-exploit mapping (read PoC first). |
| BrickStrike validator | D | Configurable check framework (incomplete). |

### 9. OT / ICS / IoT (specialty — Repo B)
| Domain | Tools |
| --- | --- |
| Traffic/packets | Wireshark/TShark, Zeek, Suricata, Scapy |
| Modbus | PyModbus, mbpoll, libmodbus, MinimalModbus |
| S7 / CIP / OPC UA | python-snap7 · cpppo, pycomm3 · asyncua, open62541 |
| BACnet / MQTT | BACpypes3, BACnet Stack · Mosquitto, Paho |
| Power & utility | lib60870, libiec61850, OpenDNP3, Gurux DLMS |
| CAN / UAV | can-utils, python-can, cantools, canopen · pymavlink |
| LoRaWAN / Zigbee | ChirpStack · zigpy |
| PLC/SCADA/honeypot | OpenPLC v4, FUXA, Node-RED, Conpot |
| IoT lab setup | `2020/web_iot/` (Repo D) |

### 10. Reporting, evidence & note-taking
| Tool | Repos | Notes |
| --- | --- | --- |
| SysReptor / Pwndoc / Ghostwriter | C | Report platforms (Markdown→PDF, finding libraries, engagement mgmt). |
| Report Rex | D | Markdown findings → formatted report (binaries + VS Code ext). |
| reportgen.py / workbench | B | Offline, provenance-tracked synthetic report pipeline. |
| Obsidian / CherryTree | C | Live per-host notes. |
| Flameshot / Greenshot | C | Annotated evidence screenshots. |
| tmux auto-logging / Zellij config | A | Per-pane output capture for evidence. |
| cptc-collect-logs.sh | B | Operator activity archive with hashed manifest. |
| Windows Filesystem Analyzer | D | Host-baseline anomaly detection. |
| Syft / ReportLab / python-docx / LibreOffice | B | SBOM + document rendering. |

### 11. Setup & deployment automation
| Tool | Repos |
| --- | --- |
| `letsgo.sh` / `else.sh` / `windows.sh` / `fixtmux.sh` / `bloodhound_setup.sh` | A |
| `install.sh` / farmkit (`install.py`, `onboard.py`, `kit.py`, `build.py`) | B |
| `2020/` installers, `Deployment/`, `simple_deploy/`, Machine Setup Scripts | D |

### 12. Wordlists, payloads & reference material
| Resource | Repos | Notes |
| --- | --- | --- |
| SecLists | A B C | Standard wordlist collection (`/usr/share/seclists`). |
| HackTricks | C | Methodology by service/technique. |
| PayloadsAllTheThings | C | Ready-to-use payloads/bypasses (clone offline). |
| revshells.com | C | Reverse-shell/listener/TTY generator. |
| CVSS v3.1 calculator | C | Consistent severity scoring. |
| CIS Benchmarks / PCI-DSS v4.0.1 | D | Hardening & compliance references. |
| Windows per-OS filesystem baselines | D | Comparison data for host audits. |
| CPTC reporting guidelines + sample reports | B C | Model the deliverable on what judges reward. |
| HackTheBox / TryHackMe / IppSec | C | Pre-competition practice. |

---

## My Notes & Comments

These are my own observations from consolidating the four analyses:

- **Four very different philosophies.** Repo A optimizes for *speed of setup* (clone-and-run installers). Repo C optimizes for *operator knowledge* (the best per-tool usage docs). Repo B optimizes for *rigor and evidence provenance* (scoped runners, hashed manifests, human-review reporting, OT breadth). Repo D is a *historical grab-bag* of standalone scripts and reference data. For a team starting fresh, A + C together are the most immediately useful combination; B is the model to copy for evidence discipline and reporting.

- **The consensus toolset.** Tools appearing in 3+ repos are the reliable CPTC core: **Nmap, Nuclei, ffuf/feroxbuster, whatweb/nikto, NetExec, Impacket, PEASS-ng, SecLists**, plus the AD cluster (BloodHound, Responder, Kerbrute, Certipy, evil-winrm) and crackers (hashcat/John). If building a minimum viable kit, start there.

- **Reporting is treated as a first-class deliverable** in three of the four repos (SysReptor/Pwndoc/Ghostwriter in C, the full offline reporting pipeline in B, Report Rex in D). This matches CPTC scoring, where the written report and executive debrief carry heavy weight. Repo C's note — *breadth of documented findings + strong report beats deep single-box heroics* — is the single most actionable strategic takeaway across all four.

- **Repo B's OT/ICS depth is unique and worth highlighting.** No other repo covers Modbus/S7/CIP/OPC UA/BACnet/DNP3/CAN/LoRaWAN/Zigbee. If a given CPTC scenario includes industrial or IoT targets, B is the only prepared reference here — but note its own caveat that this is *preparation hypothesis*, not confirmed scope, and several components carry license/runtime holds.

- **Caveats to carry forward.**
  - Repo A's `tools/windows/` binaries are committed directly and will likely trip AV/EDR — expect to stage/obfuscate on target.
  - Repo A's `windows.sh` installs *web* tooling despite its name.
  - Repo B's reporting is synthetic-only and intentionally never ingests raw scanner output automatically.
  - Repo D is explicitly aged — review and fix dependencies/security issues (e.g. FlaskMap's HTTP handling, BrickStrike's incompleteness) before any use.

- **Anonymization vs. links.** Per the request, university/team names are removed from the narrative. Repository URLs are retained because they are the only way to cross-reference the source material; those URLs necessarily contain the original names. If fully name-free output is required, strip the "Repository" column and the Sources section below.

---

## Sources

Repository links (used for cross-referencing the underlying analyses):

- Repo A — <https://github.com/nationalcptc-teamtools/University-Of-South-Florida>
- Repo B — <https://github.com/nationalcptc-teamtools/United-States-Military-Academy>
- Repo C — <https://github.com/nationalcptc-teamtools/Princess-Sumaya-University-for-Technology>
- Repo D — <https://github.com/nationalcptc-teamtools/Rochester-Institute-of-Technology>

CPTC references cited across the repos:

- [CPTC — Overview](https://cp.tc/overview) · [CPTC — Compete](https://cp.tc/compete) · [CPTC rulebook (PDF)](https://cp.tc/docs/cptc-rules.pdf)
- [Global CPTC report examples](https://github.com/globalcptc/report_examples)
- [Competitor CPTC write-up](https://atch2203.github.io/blog/posts/an-uncomprehensive-guide-to-doing-well-in-cptc)
- [Hurricane Labs — CPTC industry resource list](https://hurricanelabs.com/blog/global-collegiate-penetration-testing-competition-industry-resource-list/)
- [SysReptor — pentest reporting tools](https://docs.sysreptor.com/s/pentest-reporting-tools)
- [TCM Security — top 5 AD pentest tools](https://tcm-sec.com/top-5-tools-for-active-directory-penetration-testing/)
