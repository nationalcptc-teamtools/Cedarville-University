---
aliases:
  - "Bloodhound"
generated: true
sources_checked: 2026-10-23
---

# Bloodhound - GEN

BloodHound uses a graph to analyze relationships and attack paths in identity environments such as Active Directory and Entra ID.

**Graph concepts**
---
- Nodes represent entities.
- Edges represent relationships or capabilities.
- Paths connect relationships that may permit access to a target.

Collectors gather data for ingestion. The analysis depends on the collected relationships and their quality; a path is a reason to investigate its prerequisites and current applicability.

Use it when assessing [[Methodology/Privilege Escalation - GEN|Privilege Escalation]] and [[Lateral Movement]]. BloodHound Community Edition and BloodHound Enterprise are distinct products; use documentation matching the deployment.

**Source**
---
[SpecterOps: Introduction to BloodHound](https://bloodhound.specterops.io/get-started/introduction)
