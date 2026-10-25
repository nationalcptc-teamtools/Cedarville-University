---
review_status: new
---

# Modern Web Stacks

A web stack combines application code, runtime, web server or proxy, database, and frontend assets. Fingerprinting should identify the relevant component rather than assume one banner describes the entire deployment.

| Stack | Components or characteristics | Useful signals |
| --- | --- | --- |
| MERN | MongoDB, Express, React, Node.js | Express headers, session cookies, React assets |
| Next.js | React framework with server-side functionality | `/_next/` assets, framework headers, server-component markers |
| Django | Python web framework, often behind a WSGI server | CSRF fields, session conventions, admin routes, corroborating headers |
| LAMP | Linux, Apache, MySQL, PHP | Apache/PHP behavior and deployment context |

## Assessment sequence

1. Inspect headers, assets, cookies, and error behavior.
2. Corroborate the implementation and version.
3. Identify exposed routes and trust boundaries.
4. Research weaknesses in the actual component and configuration.
5. Validate behavior and demonstrate the relevant consequence.

Prototype pollution, middleware bypass, SQL injection, and path traversal arise at different layers. A framework fingerprint is not proof of any of them.

Automated server scanning can reveal headers and common exposures, while application-specific weaknesses often require targeted testing. Keep version and CVE applicability separate from a general stack identification.
