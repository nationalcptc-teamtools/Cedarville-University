---
review_status: new
---

# Apache HTTP Server

Apache serves static and dynamic web content through configured virtual hosts, directories, modules, and handlers.

## Fingerprinting

```bash
curl -sI http://example.com/ | grep -i server
curl -s http://example.com/nonexistent-path
```

Headers and default error pages can disclose software and version information. `ServerTokens` controls portions of the advertised server identity. Suppressing a banner reduces disclosure but does not repair an underlying weakness.

## Files and directories

Directory listing can expose files under a path such as `/files/`. Investigate backups, text notes, exported data, and configuration artifacts.

```bash
gobuster dir -u http://example.com/ -w /path/to/content.txt -x bak,txt,html
```

A readable backup may disclose internal hostnames, document roots, credentials, or deployment details. Evaluate the content rather than the extension alone.

## Status and modules

`/server-status` can expose operational information when mod_status is enabled and access restrictions permit it. CGI paths and script handlers can create additional execution boundaries.

An HTTP status does not by itself prove a module is loaded. Confirm behavior with corroborating evidence and the applicable configuration.

## Hardening

Restrict status and management endpoints, disable unnecessary listing and handlers, exclude secrets and backups from public roots, maintain the server, and apply appropriate filesystem permissions and response headers.
