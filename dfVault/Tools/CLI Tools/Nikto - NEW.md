---
review_status: new
---

# Nikto

Nikto scans web servers for known files, exposed interfaces, configuration weaknesses, and recognizable software behavior.

```bash
nikto -h http://example.com
nikto -h http://example.com:8080 -nointeractive
```

`-h` identifies the target service. `-nointeractive` suppresses interactive prompts where supported.

## Common observations

- Server and framework headers.
- Missing browser security headers.
- Cookies without expected security attributes.
- Directory listings and accessible backup files.
- Enabled HTTP methods, including TRACE.
- Recognizable software versions and exposed endpoints.

Scan each relevant port because different services on the same host may use different configurations.

## Interpretation

Nikto output supplies investigation leads. Confirm results manually and distinguish an observation from demonstrated impact. A version banner can be misleading; a known CVE also requires the relevant configuration and reachable code path.

Application logic weaknesses, prototype pollution, middleware authorization bypasses, and SQL injection may require targeted manual testing even when the server scan identifies the framework correctly.
