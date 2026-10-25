---
aliases:
  - "su"
generated: true
sources_checked: 2026-10-23
---

# su - GEN

`su` runs a shell or command with substitute user and group IDs. With no target user, it defaults to root under the documented implementation.

```bash
su - analyst
su -c 'id' analyst
```

- `-` or `--login`: Start a login-style environment.
- `-c COMMAND`: Pass a command to the selected shell.
- `-s SHELL`: Select a shell, subject to applicable restrictions.

Authentication and account handling use the system's configured mechanisms, including PAM where supported. A login-style invocation avoids unintentionally mixing parts of the old and new environments.

Use [[Linux CLI Commands/id - GEN|id]] to inspect the resulting context. See [[Linux Users]] for user IDs and account records.

**Source**
---
[util-linux su manual](https://man7.org/linux/man-pages/man1/su.1.html)
