---
aliases:
  - "JSON"
generated: true
sources_checked: 2026-10-23
---

# JSON - GEN

JSON (JavaScript Object Notation) is a text format for exchanging structured data. It is commonly used in [[API documentation]] and [[Protocols and Notation/HTTP - GEN|HTTP]] message bodies.

Values can be objects, arrays, strings, numbers, `true`, `false`, or `null`. Object member names are strings written in double quotes.

```json
{
  "name": "example",
  "enabled": true,
  "ports": [80, 443]
}
```

JSON syntax does not include comments or trailing commas. The format describes data representation, not authentication or encryption.

Related formats include [[Tools/Languages/XML - GEN|XML]] and [[Tools/Languages/YAML - GEN|YAML]].

**Source**
---
[RFC 8259: JSON data interchange format](https://datatracker.ietf.org/doc/html/rfc8259)
