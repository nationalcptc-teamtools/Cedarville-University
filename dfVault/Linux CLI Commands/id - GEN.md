---
aliases:
  - "id"
generated: true
sources_checked: 2026-10-23
---

# id - GEN

`id` prints user and group identity information. Without a username argument, it describes the current process's identity context.

```bash
id
id analyst
id -u
id -g
id -G
id -un
```

| Option | Purpose |
| --- | --- |
| `-u` | User ID |
| `-g` | Primary group ID |
| `-G` | Group IDs |
| `-n` | Names instead of numbers with supported output options |
| `-r` | Real rather than effective ID with supported options |

Use it with [[Linux Users]], [[Linux Groups]], and [[Linux CLI Commands/etc-passwd - GEN|/etc/passwd]] when establishing the current account context.

**Source**
---
[GNU Coreutils id manual](https://man7.org/linux/man-pages/man1/id.1.html)
