---
review_status: new
---

# Content Discovery

Content discovery identifies application pages, files, endpoints, and supporting resources that are not obvious from normal navigation.

## Manual discovery

Inspect links, HTML comments, JavaScript, response headers, and browser network requests. Compare public and authenticated views. Useful discovery files include:

- `robots.txt`: Crawler instructions that may mention sensitive or unlinked paths; these instructions are not access controls.
- `sitemap.xml`: Published URLs that may include pages outside the main navigation.
- Favicons and static assets: Possible framework or product identifiers.
- Default pages and error messages: Clues about software and configuration.

## Public information

Search indexes, certificate transparency, archived pages, public repositories, and exposed storage references can reveal historical paths or related assets. Validate discoveries because references can be stale, unrelated, or outside scope.

## Automated discovery

Tools such as FFUF, Gobuster, and directory scanners substitute wordlist candidates into paths or filenames. Select lists and extensions appropriate to the application.

```bash
gobuster dir -u http://example.com -w /path/to/content.txt -x php,txt,bak
ffuf -w /path/to/content.txt -u http://example.com/FUZZ
```

Compare status codes, sizes, redirects, and response bodies with a nonexistent-path baseline. Soft 404s and wildcard routing can generate false positives. Discovery establishes a resource to investigate; exposure becomes a finding when its content or behavior violates an intended security boundary.
