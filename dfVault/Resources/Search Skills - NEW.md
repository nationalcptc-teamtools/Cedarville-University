---
review_status: new
---

# Security Research and Search Skills

Effective research starts with a precise question and uses evidence appropriate to that question.

## Search strategy

Search exact error strings, product names, version numbers, protocol terms, and vulnerability identifiers. Quoted phrases and operators such as `site:` or `filetype:` reduce irrelevant results.

Compare publication dates, affected versions, and deployment assumptions. Prefer product documentation and original advisories for technical behavior, then use community discussion for additional context.

## Documentation

Use official product guides, API references, local help, and manual pages to understand syntax and expected behavior. A command copied from another environment may use different defaults or options.

```bash
man COMMAND
COMMAND --help
```

Manual pages commonly provide NAME, SYNOPSIS, and detailed option descriptions. Read the invocation structure before assuming that a flag takes a value.

## Reputation and analysis services

Services such as VirusTotal combine observations from multiple scanners and other sources. Such results are supporting evidence rather than definitive proof of safety or maliciousness. Consider what information is submitted and whether it is appropriate to disclose to an external service.

Record useful references with the observation they support, including enough context to distinguish a verified fact from an inference.
