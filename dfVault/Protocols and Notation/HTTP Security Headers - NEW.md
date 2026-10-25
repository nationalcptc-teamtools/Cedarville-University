---
review_status: new
---

# HTTP Security Headers

HTTP response headers can direct browsers to apply additional restrictions. Their significance depends on the application, response type, and deployment.

| Header | Purpose | Example |
| --- | --- | --- |
| `Content-Security-Policy` | Restrict resource loading and other browser behavior | `default-src 'self'` |
| `X-Frame-Options` | Restrict framing | `DENY` or `SAMEORIGIN` |
| `X-Content-Type-Options` | Disable MIME sniffing for applicable content | `nosniff` |
| `Referrer-Policy` | Control referrer information | `no-referrer` or `strict-origin` |
| `Strict-Transport-Security` | Require HTTPS on later requests | `max-age=31536000` |

CSP's `frame-ancestors` directive supplies a more flexible framing policy than X-Frame-Options. A deployment may intentionally use CSP for that protection.

## Inspection

```bash
curl -sI https://example.com/ | grep -iE 'content-security-policy|x-frame-options|x-content-type-options|referrer-policy|strict-transport-security'
```

Inspect representative responses across relevant services and endpoints. HSTS is processed over HTTPS, so its absence from an HTTP response alone does not establish a defect. Missing headers should be evaluated against application behavior and compensating controls, rather than assigned an automatic severity.
