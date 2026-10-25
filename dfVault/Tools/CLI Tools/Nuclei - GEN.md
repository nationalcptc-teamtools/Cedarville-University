---
aliases:
  - "Nuclei"
generated: true
sources_checked: 2026-10-23
---

# Nuclei - GEN

Nuclei performs security checks described by templates, commonly written in [[Tools/Languages/YAML - GEN|YAML]]. Templates define requests and conditions used to recognize a result.

```bash
nuclei -u https://example.com -t /path/to/template.yaml
nuclei -l targets.txt -t /path/to/templates/
```

- `-u`: A target URL.
- `-l`: A target list.
- `-t`: A template or template directory.
- `-tags`: Select templates by tag.
- `-severity`: Filter template severity labels.

Review the selected templates and the requests they issue. A result depends on a template's matching logic and should be validated during [[Vulnerability Assessment]].

[[Tools/CLI Tools/Katana - GEN|Katana]] can discover endpoints; Nuclei applies separate checks to selected targets.

**Sources**
---
- [Nuclei overview](https://docs.projectdiscovery.io/opensource/nuclei/overview)
- [Running Nuclei](https://docs.projectdiscovery.io/opensource/nuclei/running)
