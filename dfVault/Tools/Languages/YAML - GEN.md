---
aliases:
  - "YAML"
generated: true
sources_checked: 2026-10-23
---

# YAML - GEN

YAML is a data serialization language that supports mappings, sequences, and scalar values. Indentation describes structure in common block-style documents.

```yaml
service:
  name: example
  ports:
    - 80
    - 443
```

Use spaces for indentation; tabs must not be used as indentation. Quoting can help distinguish intended strings from values interpreted under a schema.

[[Tools/CLI Tools/Nuclei - GEN|Nuclei]] uses YAML-based templates. YAML and [[Tools/Languages/JSON - GEN|JSON]] are data formats; neither format by itself establishes that loaded data is trustworthy.

**Source**
---
[YAML 1.2.2 specification](https://yaml.org/spec/1.2.2/)
