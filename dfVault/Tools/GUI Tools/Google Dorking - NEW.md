---
review_status: new
---

# Google Dorking

Search operators narrow public search results to potentially relevant hosts, paths, documents, and text.

| Operator | Example | Purpose |
| --- | --- | --- |
| `site:` | `site:example.com` | Limit results to a domain |
| `inurl:` | `inurl:admin` | Match text in a URL |
| `filetype:` | `filetype:pdf` | Select a file format |
| `intitle:` | `intitle:admin` | Match a page title |
| `intext:` | `intext:configuration` | Match body text |
| `-` | `site:example.com -site:www.example.com` | Exclude matching results |

Combine operators to investigate public documentation, subdomains, exposed interfaces, and indexed files. Search results can be stale or incomplete, so validate important discoveries independently.

Search operators depend on the engine and can change. Historical instructions for cached-page operators should not be assumed to remain supported.

## References

- [Further reading](https://en.wikipedia.org/wiki/Google_hacking)
