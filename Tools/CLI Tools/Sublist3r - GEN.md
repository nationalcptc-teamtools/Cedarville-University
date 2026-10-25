---
aliases:
  - "Sublist3r"
generated: true
sources_checked: 2026-10-23
---

# Sublist3r - GEN

Sublist3r collects subdomain names from public information sources. It also has optional active behavior such as brute-force enumeration and port filtering.

```bash
python sublist3r.py -d example.com
python sublist3r.py -d example.com -p 80,443
python sublist3r.py -b -d example.com
```

- `-d`: Domain to enumerate.
- `-p`: Filter using selected open TCP ports.
- `-b`: Enable the brute-force module.
- `-v`: Show results as they are found.
- `-e`: Select supported search engines.

Public-source collection and direct probing are different activities. Use the selected options deliberately during [[Information Gathering]]. Validate names before adding them to an active assessment inventory.

**Source**
---
[Sublist3r maintainer documentation](https://github.com/aboul3la/Sublist3r)
