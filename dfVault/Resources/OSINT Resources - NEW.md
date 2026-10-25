---
review_status: new
---

# OSINT Resources

Open-source intelligence uses publicly available information to understand assets, technologies, and exposure.

| Resource | Useful information | Interpretation limit |
| --- | --- | --- |
| Wappalyzer | Frameworks, CMSs, libraries, and other technology fingerprints | Signals can be incomplete or misleading |
| Wayback Machine | Historical pages, paths, and content | Archived content may no longer exist |
| Public Git repositories | Code, configuration, deployment references, and accidentally published secrets | Confirm relevance and ownership |
| Certificate transparency | Names appearing in issued certificates | Names may be historical or unrelated to a current service |
| Shodan | Previously observed banners, addresses, services, and hosting information | Records may be stale |
| Public DNS and registration data | Resolution and registration relationships | Does not prove application ownership or authorization |

## Git and repositories

Git tracks changes through commits. Hosted repositories can reveal historical configuration and references absent from the current website. Distinguish repository contents, commit history, and the deployed application.

## S3 references

An S3 bucket can use a hostname such as `bucket-name.s3.amazonaws.com`. Bucket references may appear in HTML, scripts, repositories, or documentation. Public readability and writability are separate properties; an identifier alone is not evidence of misconfiguration.

Record the discovery source, date, relevant asset, and confidence. Correlate independent sources before making a conclusion.
