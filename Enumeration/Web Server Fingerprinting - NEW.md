---
review_status: new
---

# Web Server Fingerprinting

Fingerprinting combines response headers, error behavior, default pages, and application assets to estimate server and framework identity.

```bash
curl -sI http://example.com/
curl -s http://example.com/nonexistent-path
```

## Common signals

| Signal | Possible interpretation |
| --- | --- |
| `Server: Apache/...` | Apache or a component advertising it |
| `Server: nginx/...` | Nginx or a component advertising it |
| `Server: Microsoft-IIS/...` | IIS |
| `SimpleHTTP/... Python/...` | Python's simple HTTP server |
| `X-Powered-By: Express` | Express application middleware |
| `X-Powered-By: ASP.NET` | ASP.NET-related hosting |
| Default 404 page | Additional implementation clues |

Inspect the actual request and response in browser developer tools to distinguish headers returned by the server from assumptions based on page appearance.

## Confidence

Headers can be removed, changed, or supplied by a reverse proxy. A banner does not prove an exact patch level or exploitability. Corroborate with assets, behavior, deployment information, and configuration-specific tests.

Record which port and endpoint supplied each observation; different services on one address may use unrelated stacks.
