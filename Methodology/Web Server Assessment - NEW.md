---
review_status: new
---

# Web Server Assessment

Assess server configuration independently from application logic. Different ports on one host can expose different software, files, and administrative interfaces.

## Workflow

1. Enumerate reachable HTTP services.
2. Inspect headers, default pages, and error responses.
3. Identify directory listings, backups, dotfiles, and configuration exposure.
4. Check status, debug, and management endpoints.
5. Inspect supported methods and authentication requirements.
6. Evaluate browser security headers in context.
7. Run an automated scan and validate its results manually.

## Common server-specific paths

| Server | Examples to investigate |
| --- | --- |
| Apache | `/server-status`, directory listings, backup configuration files |
| Python HTTP server | Working-directory contents, dotfiles, archives |
| Node.js / Express | Debug routes, environment output, static configuration |
| Nginx | Autoindex paths, `/nginx_status`, exposed deployment files |
| IIS | WebDAV, `web.config`, `trace.axd`, directory listings |

Record each response's content and consequence. An advertised method, software banner, or missing header is an observation requiring interpretation, not automatically a confirmed high-impact vulnerability.
