---
aliases:
  - "adduser"
generated: true
sources_checked: 2026-10-23
---

# adduser - GEN

On Debian-family systems, `adduser` provides a higher-level account-management interface that applies distribution policy and configuration.

```bash
sudo adduser analyst
sudo adduser analyst GROUP
```

The first form creates an account. The two-name form adds an existing user to an existing group.

Options include selecting a home directory, shell, UID, or group, and creating a system account. Exact behavior is distribution-specific; another operating system's `adduser` need not be the same program.

Compare with [[Linux CLI Commands/useradd - GEN|useradd]], which exposes lower-level account-creation options. Account records relate to [[Linux CLI Commands/etc-passwd - GEN|/etc/passwd]], [[Linux CLI Commands/etc-shadow - GEN|/etc/shadow]], and [[Linux Groups]].

**Source**
---
[Debian adduser manual](https://manpages.debian.org/bookworm/adduser/adduser.8.en.html)
