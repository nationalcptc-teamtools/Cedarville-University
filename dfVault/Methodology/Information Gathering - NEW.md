---
review_status: new
---

# Information Gathering

Information gathering establishes what is known about an organization, its systems, and its exposed services. It informs [[Enumeration and Scanning]] and vulnerability assessment.

## Passive reconnaissance

Collect public information without directly probing the target service. Sources include domain registration, public DNS information, search indexes, certificate transparency, public repositories, job advertisements, and published documentation.

Useful tools and sources include [[Tools/CLI Tools/Sublist3r - GEN|Sublist3r]], [[Google dorking]], WHOIS, archives, and service search engines. Distinguish information collected by a third party from direct interaction performed by the assessor.

## Active reconnaissance

Connect to the target to inspect application behavior, service banners, ports, and host responses. Browsing, endpoint requests, and network scans create observable interactions.

## Records

For each discovery, retain the source, date, asset, confidence, and reason it matters. Validate ownership and scope before treating a public reference as an assessment target.
