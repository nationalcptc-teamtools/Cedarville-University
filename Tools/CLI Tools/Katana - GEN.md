---
aliases:
  - "Katana"
generated: true
sources_checked: 2026-10-23
---

# Katana - GEN

Katana is a web crawler that discovers URLs and endpoints. It supports standard crawling, JavaScript parsing, and headless browsing for applications that depend on browser execution.

```bash
katana -u https://example.com -d 3
katana -u https://example.com -jc
```

| Option | Purpose |
| --- | --- |
| `-u` | Target URL |
| `-d` | Crawl depth |
| `-jc` | Parse and crawl JavaScript-discovered endpoints |
| `-cs` / `-cos` | Include / exclude scope expressions |

Use the discovered paths during [[Walking an Application]] and [[API Reconnaissance]]. Crawling discovers content; it does not itself establish that an endpoint is vulnerable. [[Tools/CLI Tools/Nuclei - GEN|Nuclei]] performs separate template-based checks.

**Sources**
---
- [Katana overview](https://docs.projectdiscovery.io/opensource/katana/overview)
- [Running Katana](https://docs.projectdiscovery.io/opensource/katana/running)
