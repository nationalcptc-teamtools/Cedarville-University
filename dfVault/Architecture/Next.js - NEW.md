---
review_status: new
---

# Next.js

Next.js adds routing, rendering, and server-side application functionality to React. The security boundary includes middleware, route handlers, server-side operations, and the surrounding deployment.

## Fingerprinting

Signals can include `X-Powered-By: Next.js`, `/_next/` asset paths, `window.__next_f` in page scripts, and framework-specific cache headers. These clues support identification but do not establish an exact version or vulnerability.

React Server Components use a transport representation often referred to as the Flight protocol. Its presence identifies an architectural feature, not an automatic code execution condition.

## Authorization boundaries

Middleware can perform request checks before routing. Test whether protected handlers independently enforce authorization and whether unexpected internal-looking headers alter the execution path.

Compare a protected route's ordinary anonymous response with a controlled variant, then confirm access to the protected data or operation. Do not use a changed status alone as proof.

The middleware bypass mechanism involves the internal `x-middleware-subrequest` header. A repeated value such as `middleware:middleware:middleware:middleware:middleware` is associated with one affected configuration. Its behavior depends on the relevant version and middleware path; it is not a universal bypass for every deployment.

## Vulnerability research

`CVE-2025-29927` concerns middleware authorization bypass. `CVE-2025-55182` concerns React Server Components deserialization. They describe different mechanisms and should not be conflated.

Determine the installed React/Next.js versions, deployment mode, affected dependencies, and reachable functionality from the relevant vendor advisories before drawing an applicability conclusion.

## Defensive design

Enforce authorization at the server-side action or resource boundary. Handle internal framework headers at appropriate trust boundaries, maintain dependencies, and verify protected behavior after updates.
