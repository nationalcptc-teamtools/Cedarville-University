---
review_status: new
---

# Threat Modeling

Threat modeling identifies how an adversary could affect a system and which controls reduce the resulting risk.

## Process

1. Prepare: identify objectives, assets, data flows, and trust boundaries.
2. Identify threats and possible abuse paths.
3. Select mitigations based on risk and available capabilities.
4. Review the model as the system and evidence change.

Include threat intelligence, asset identification, mitigation capabilities, and risk assessment rather than listing attack names without context.

## STRIDE

| Category | Concern |
| --- | --- |
| Spoofing | False identity |
| Tampering | Unauthorized modification |
| Repudiation | Inability to establish responsibility |
| Information disclosure | Unauthorized access to information |
| Denial of service | Loss of availability |
| Elevation of privilege | Unauthorized increase in permissions |

PASTA, the Process for Attack Simulation and Threat Analysis, is another approach that connects business objectives, technical analysis, threats, and attack scenarios.
