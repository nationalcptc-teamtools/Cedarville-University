---
aliases:
  - "useradd"
generated: true
sources_checked: 2026-10-23
---

# useradd - GEN

`useradd` creates a local user account using command-line options and system defaults.

```bash
sudo useradd -m -s /bin/bash analyst
```

| Option | Purpose |
| --- | --- |
| `-m` | Create a home directory |
| `-d PATH` | Set the home-directory path |
| `-s SHELL` | Set the login shell |
| `-u UID` | Set the user ID |
| `-g GROUP` | Select a primary group |
| `-G GROUPS` | Select supplementary groups |
| `-r` | Create a system account |

Defaults and related account files affect the resulting account. [[Linux CLI Commands/adduser - GEN|adduser]] may provide a distribution-specific higher-level interface. Verify the result using [[Linux CLI Commands/id - GEN|id]] and the relevant account records.

**Source**
---
[shadow-utils useradd manual](https://man7.org/linux/man-pages/man8/useradd.8.html)
