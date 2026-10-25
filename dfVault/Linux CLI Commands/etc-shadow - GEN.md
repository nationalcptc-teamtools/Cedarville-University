---
aliases:
  - "/etc/shadow"
generated: true
sources_checked: 2026-10-23
---

# /etc/shadow - GEN

`/etc/shadow` stores password-related and password-aging information for local accounts. It must not be readable by regular users.

**Fields**
---
1. Login name.
2. Password representation or account-lock indicator.
3. Last password-change day.
4. Minimum password age.
5. Maximum password age.
6. Warning period.
7. Inactivity period.
8. Account-expiry day.
9. Reserved field.

A leading `!` in the password field locks password authentication under the documented conventions. Account access can also involve other authentication mechanisms.

[[Linux CLI Commands/etc-passwd - GEN|/etc/passwd]] contains the corresponding account record. [[Linux CLI Commands/useradd - GEN|useradd]] and [[Linux CLI Commands/adduser - GEN|adduser]] manage account creation using system tools.

**Source**
---
[Linux shadow(5) manual](https://man7.org/linux/man-pages/man5/shadow.5.html)
