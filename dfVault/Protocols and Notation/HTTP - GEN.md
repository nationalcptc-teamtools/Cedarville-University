---
aliases:
  - "HTTP"
generated: true
sources_checked: 2026-10-23
---

# HTTP - GEN

HTTP is an application-level request/response protocol. A client selects a method and target resource; the server returns a status and a representation or other response data.

**Important methods**
---
- GET retrieves a selected representation.
- HEAD has GET semantics without response content.
- POST asks a resource to process supplied content.
- PUT creates or replaces the target's state with the supplied representation.
- DELETE requests removal of the target association.
- OPTIONS describes communication options.

Headers carry metadata and control information. HTTPS uses a protected connection; the `https` URI scheme is distinct from cleartext `http`.

[[Tools/CLI Tools/Curl - GEN|Curl]], [[Tools/GUI Tools/Burp Repeater - GEN|Burp Repeater]], and [[Tools/GUI Tools/Postman - GEN|Postman]] can inspect HTTP interactions during [[API Testing]].

**Source**
---
[RFC 9110: HTTP semantics](https://datatracker.ietf.org/doc/html/rfc9110)
