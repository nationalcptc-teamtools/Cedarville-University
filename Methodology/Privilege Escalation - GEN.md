---
aliases:
  - "Privilege Escalation"
generated: true
sources_checked: 2026-10-23
---

# Privilege Escalation - GEN

Privilege escalation obtains permissions beyond the current level of access. Higher permissions can be needed to reach protected resources or perform privileged operations.

Possible paths include vulnerable software, unsafe configuration, and abuse of available permissions. A foothold does not automatically provide administrative access.

**Evidence**
---
- Record the starting identity and privileges.
- Identify the condition enabling the transition.
- Verify the resulting identity or newly permitted action.
- Explain the resource or operation that became reachable.

[[Tools/CLI Tools/Linpeas - GEN|Linpeas]] can identify possible local paths. [[Tools/GUI Tools/Bloodhound - GEN|Bloodhound]] analyzes identity relationships relevant to escalation and [[Lateral Movement]].

**Source**
---
[MITRE ATT&CK: Privilege Escalation](https://attack.mitre.org/tactics/TA0004/)
