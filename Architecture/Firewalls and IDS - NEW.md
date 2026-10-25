---
review_status: new
---

# Firewalls and Intrusion Detection

A firewall permits or blocks traffic according to rules. Policies may deny traffic by default with explicit exceptions, or allow traffic except for explicitly blocked activity.

Traditional network rules inspect IP addresses, ports, and transport metadata. Stateful filtering also considers connection state. More advanced controls may inspect application content.

## Intrusion detection

An intrusion detection system identifies suspicious signatures or behavior and raises alerts. It can inspect packet headers, payloads, and relationships between events.

## Assessment implications

Filtering can make a host or port appear silent without establishing that it is offline or closed. Fragmentation and unusual TCP flags can change how particular controls interpret probes, but do not provide a reliable universal bypass. Compare scanner classifications with packet captures and the actual rule behavior.
