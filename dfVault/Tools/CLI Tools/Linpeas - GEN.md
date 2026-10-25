---
aliases:
  - "Linpeas"
generated: true
sources_checked: 2026-10-23
---

# Linpeas - GEN

LinPEAS is a PEASS-ng script that searches for possible local [[Methodology/Privilege Escalation - GEN|Privilege Escalation]] paths on Linux and other supported Unix-like systems.

```bash
sh linpeas.sh
```

Run a reviewed local copy in the context being assessed. Its output highlights configuration, permissions, credentials, and other conditions that may warrant investigation.

A highlighted result is a lead, not confirmation that escalation is possible. Record the current identity with [[Linux CLI Commands/id - GEN|id]], inspect the relevant permissions, and verify the actual consequence.

This is local enumeration after access has been obtained; it differs from remote port scanning with [[NMAP]].

**Source**
---
[PEASS-ng: LinPEAS maintainer documentation](https://github.com/peass-ng/PEASS-ng/tree/master/linPEAS)
