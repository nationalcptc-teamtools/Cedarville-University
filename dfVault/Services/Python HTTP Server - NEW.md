---
review_status: new
---

# Python HTTP Server

Python's simple HTTP server can publish files from its working directory.

```bash
python3 -m http.server 8000
```

## Exposure

When no suitable index page is present, the server may generate a directory listing. Files within the served tree can be accessible even if they are not linked from another page.

Investigate unintended exposure of dotfiles, environment files, text notes, archives, and database exports. A backup archive can contain information not visible in the directory listing itself.

```bash
curl -s http://example.com:8000/
```

## Interpretation

The issue can be ordinary file serving from the wrong directory, rather than exploitation of a server vulnerability. Determine the actual content and intended access boundary.

Serve only an explicitly chosen directory containing appropriate public content. Avoid exposing credentials, backups, or project working files, and use a deployment suited to the required access controls.
