---
aliases:
  - "Curl"
generated: true
sources_checked: 2026-10-23
---

# Curl - GEN

Curl transfers data using URLs. It can inspect [[Protocols and Notation/HTTP - GEN|HTTP]] requests and responses, send [[Tools/Languages/JSON - GEN|JSON]] data, and work with cookies during [[API Testing]].

```bash
curl https://example.com/
curl -I https://example.com/
curl -H 'Content-Type: application/json' -d '{"name":"example"}' https://example.com/api/items
```

| Option | Purpose |
| --- | --- |
| `-I` | Request headers using HEAD |
| `-v` | Show connection and protocol details |
| `-H` | Add or replace a header |
| `-d` | Send body data; normally selects POST |
| `-o FILE` | Save the response to a file |
| `-L` | Follow redirects |
| `-b FILE` / `-c FILE` | Read / write cookies |

HEAD and GET have different semantics; use the relevant method when reproducing application behavior.

**Source**
---
[Curl manual](https://curl.se/docs/manpage.html)
