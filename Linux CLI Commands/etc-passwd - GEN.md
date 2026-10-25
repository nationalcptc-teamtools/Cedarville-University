---
aliases:
  - "/etc/passwd"
generated: true
sources_checked: 2026-10-23
---

# /etc/passwd - GEN

`/etc/passwd` describes local user account records. Entries contain seven colon-separated fields:

```text
name:password:UID:GID:comment:home:shell
```

- UID and GID identify the user and primary group.
- The home field gives the home directory.
- The shell field identifies the login shell or another configured program.
- An `x` in the password field commonly indicates that password information is held in [[Linux CLI Commands/etc-shadow - GEN|/etc/shadow]].

The file is normally readable so programs can map IDs to names, but must not be writable by ordinary users. [[Linux Users]] provides the account context; [[Linux CLI Commands/id - GEN|id]] displays identity information.

**Source**
---
[Linux passwd(5) manual](https://man7.org/linux/man-pages/man5/passwd.5.html)
