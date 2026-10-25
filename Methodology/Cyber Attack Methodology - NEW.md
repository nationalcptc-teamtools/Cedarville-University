---
review_status: new
---

# Cyber Attack Methodology

The Cyber Kill Chain describes stages of an intrusion and helps relate attacker behavior to defensive opportunities.

| Stage | Typical behavior | Defensive focus |
| --- | --- | --- |
| Reconnaissance | Collect organizational, technical, and personnel information | Reduce unnecessary exposure and detect probing |
| Weaponization | Prepare an exploit or delivery artifact | Harden software and reduce usable attack surface |
| Delivery | Send a payload through a reachable channel | Filter malicious content and control entry points |
| Exploitation | Trigger a weakness | Patch, validate inputs, and enforce security boundaries |
| Installation | Establish an executable foothold or persistence | Restrict execution and monitor system changes |
| Command and control | Communicate with the compromised system | Monitor egress and suspicious connections |
| Actions on objectives | Access data, move laterally, disrupt, or otherwise achieve a goal | Limit privileges, segment access, detect and respond |

Examples include targeted phishing, malicious documents, exposed service exploitation, scheduled persistence, reverse connections, credential misuse, and unauthorized data access.

## Assessment workflow

1. [[Information Gathering]] establishes the attack surface.
2. [[Enumeration and Scanning]] maps reachable assets and behavior.
3. [[Methodology/Exploitation - GEN|Exploitation]] validates the consequence of weaknesses.
4. [[Methodology/Privilege Escalation - GEN|Privilege Escalation]] examines additional permissions that become reachable.
5. [[Methodology/Post Exploitation - GEN|Post Exploitation]] assesses impact, access paths, and defensive visibility.

An engagement can loop between these activities as discoveries reveal new paths. Covering tracks is an adversary behavior to assess through logging and detection evidence; routine assessment records should be retained rather than erased.
