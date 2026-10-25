---
aliases:
  - "Burp Repeater"
generated: true
sources_checked: 2026-10-23
---

# Burp Repeater - GEN

Burp Repeater edits and resends HTTP or WebSocket messages. It supports repeated manual comparison while investigating application behavior.

**Working sequence**
---
1. Send an interesting captured message to Repeater.
2. Confirm the destination and send a baseline.
3. Change a relevant value.
4. Compare the response with the baseline.
5. Keep useful variants for further testing and evidence.

Use it for [[API Testing]], input validation, and authorization checks. [[Tools/GUI Tools/Burp Intruder - GEN|Burp Intruder]] automates larger sets of variations.

See [[Burp Repeater - NEW]] for the existing detailed reference.

**Source**
---
[PortSwigger: Burp Repeater](https://portswigger.net/burp/documentation/desktop/tools/repeater)
