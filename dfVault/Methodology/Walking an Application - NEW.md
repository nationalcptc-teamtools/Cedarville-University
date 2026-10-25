---
review_status: new
---

# Walking an Application

Manual application mapping identifies functionality, user roles, inputs, and data flows before focused testing.

## Mapping process

1. Browse public pages and record their purpose.
2. Create representative accounts when available.
3. Compare anonymous and authenticated functionality.
4. Exercise forms, uploads, search, account changes, and recovery flows.
5. Record URLs, methods, parameters, cookies, and background API requests.
6. Note role-dependent behavior and resources that require ownership checks.

## Browser evidence

Use page source for the received HTML and Inspector for the current DOM. Debugger/Sources reveals JavaScript behavior and breakpoints. Network captures background requests, headers, bodies, and responses. Storage exposes cookies and other browser-held data.

Presentation changes can reveal hidden content but do not prove a server-side access control failure. Test the underlying request and its authorization separately.

## Discovery leads

Inspect comments, links, script files, `robots.txt`, `sitemap.xml`, response headers, and framework-specific paths. Record useful observations in a page/function table so each feature has a clear testing status and evidence trail.

## Related concepts

- [[Dev Tools]]
- [[Google Dorking]]
- [[Resources/Wordlists - GEN|Wordlists]]
- [[Gobuster]]

## References

- [Further reading](https://{name}.s3.amazonaws.com)
