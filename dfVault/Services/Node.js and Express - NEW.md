---
review_status: new
---

# Node.js and Express

Node.js runs server-side JavaScript. Express supplies routing and middleware for HTTP applications.

## Fingerprinting

Potential clues include `X-Powered-By: Express`, session cookies such as `connect.sid`, recognizable error responses, and frontend assets. Corroborate them rather than assuming that one header identifies the whole stack.

## Information exposure

Investigate development behavior and endpoints such as:

| Pattern | Possible exposure |
| --- | --- |
| Root JSON status response | Application name or version |
| Verbose API errors | Queries, internal services, ports, and filesystem paths |
| `/api/routes` | Route inventory |
| `/api/debug/env` | Environment variables and secrets |
| Static configuration files | Internal API addresses and deployment settings |

These paths are examples of application routes, not mandatory Express endpoints.

```bash
curl -s https://example.com/api/users | python3 -m json.tool
```

## Security interpretation

Public client configuration is not automatically secret, but it can reveal internal topology or unsuitable embedded credentials. A development-mode label is a configuration lead; demonstrate the behavior it enables.

Remove unnecessary debug routes, return controlled public errors, keep secrets server-side, and enforce authorization on each sensitive endpoint. Review object merging and client-controlled properties separately for prototype pollution or mass-assignment issues.
