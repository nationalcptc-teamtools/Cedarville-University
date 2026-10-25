---
review_status: new
---

# Burp Suite

Burp Suite is a web application testing framework built around capturing, inspecting, modifying, and replaying HTTP and WebSocket traffic.

## Components

| Component | Purpose |
| --- | --- |
| Proxy | Intercept and log browser traffic |
| Repeater | Edit and resend individual requests |
| Intruder | Send controlled variations using payload positions and lists |
| Decoder | Encode, decode, and hash data |
| Comparer | Compare messages by words or bytes |
| Sequencer | Analyze the statistical randomness of tokens |
| Organizer | Save and annotate selected messages |
| Extensions | Add custom integrations and functionality |

Community and licensed editions differ in automation, performance limits, project persistence, and scanning features. Feature availability should be checked in the installed edition.

## Workspace

The dashboard groups background work, events, detected issues, and advisory information. The main tab bar selects a tool; sub-tabs expose that tool's views and settings. Tabs can be detached into separate windows.

Useful navigation shortcuts include:

| Shortcut | Destination |
| --- | --- |
| Ctrl+Shift+D | Dashboard |
| Ctrl+Shift+T | Target |
| Ctrl+Shift+P | Proxy |
| Ctrl+Shift+I | Intruder |
| Ctrl+Shift+R | Repeater |

User settings apply across sessions. Project settings apply to the current assessment. The Settings search and type filters help distinguish the two.

## Application mapping and scope

The Target site map records discovered hosts, paths, and endpoints. Browsing through the proxy builds this map, including APIs called by frontend code. Issue definitions describe vulnerability classes and can support consistent reporting terminology.

Define included and excluded hosts in scope settings. Logging filters, interception rules, and automated activity have separate scope controls; configure each relevant control rather than assuming that one scope setting governs every tool.

## Working sequence

1. Configure a browser to use the proxy.
2. Set the intended target scope.
3. Browse the application and identify entry points.
4. Send interesting requests to Repeater or Intruder.
5. Save useful messages and annotate the evidence.

Detailed usage is covered by the individual Burp component notes.
