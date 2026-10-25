---
aliases:
  - "Wordlists"
generated: true
sources_checked: 2026-10-23
---

# Wordlists - GEN

Wordlists supply candidate values to automated discovery and testing tools. SecLists groups lists for uses such as usernames, passwords, URLs, and fuzzing inputs.

**Choose a list by purpose**
---
- Web paths and filenames for [[Gobuster]] or [[FFUF]].
- Candidate DNS labels for subdomain discovery.
- Usernames or password candidates for relevant authentication tests.
- Payload lists for parameter testing.

The candidates must match the input being tested. A web-path list and a password list represent different assumptions and should not be treated as interchangeable.

[[Tools/CLI Tools/Hashcat - GEN|Hashcat]] uses candidates for offline recovery. [[Tools/GUI Tools/Burp Intruder - GEN|Burp Intruder]] can insert a list's values into request positions.

**Source**
---
[SecLists maintainer repository](https://github.com/danielmiessler/SecLists)
