---
review_status: new
---

# IIS Short Filename Enumeration

Some IIS deployments reveal information about Windows 8.3 short filenames through differences in responses to specially formed requests containing `~` and wildcard patterns.

## Short-name structure

A conventional short name can use an abbreviated prefix, a tilde and collision number, and a shortened extension. The exact generated name depends on the filesystem and filename.

| Observed pattern | Candidate interpretation |
| --- | --- |
| `BACKUP~1` | A name beginning with a backup-related prefix |
| `ADMINI~1` | A possible administration-related name |
| `CONFIG~1.ASP` | A possible ASP-related configuration file |
| `USERS_~1.XLS` | A possible spreadsheet export |

These are clues rather than guaranteed full filenames.

## Enumeration and validation

```bash
python3 iis_shortname_scan.py http://example.com/
```

A compatible scanner compares response behavior for candidate prefixes. `*` represents a wildcard in relevant probe patterns. Confirm the tool's result and investigate plausible completions using additional evidence or content discovery.

If an exposed directory lists files, inspect only relevant authorized content. Backup notes can reveal configuration details or credentials, but the security consequence comes from the accessible information, not simply from the existence of an abbreviated name.

## Remediation considerations

Address the information leak and any exposed files separately. Restrict access to backups and configuration artifacts, review short-name behavior for the deployment, and verify the effect of changes through retesting.
