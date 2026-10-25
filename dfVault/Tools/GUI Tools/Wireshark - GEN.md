---
aliases:
  - "Wireshark"
generated: true
sources_checked: 2026-10-23
---

# Wireshark - GEN

Wireshark captures and analyzes network packets. It displays protocol fields and helps inspect exchanges involving [[TCP]], [[UDP]], [[ICMP]], and application protocols.

**Display filters**
---
```text
tcp
http.request
ip.addr == 192.0.2.10
tcp.flags.syn == 1
```

Display filters select packets from the capture for viewing. They can test protocol presence, field values, and combinations using `and` or `or`.

Packet inspection can support [[Enumeration and Scanning]] by showing which probes and replies actually occurred. A protocol filter identifies decoded traffic; it does not independently establish the security consequence of that exchange.

**Sources**
---
- [Wireshark introduction](https://www.wireshark.org/docs/wsug_html_chunked/ChapterIntroduction.html)
- [Wireshark display filters](https://www.wireshark.org/docs/wsug_html_chunked/ChWorkBuildDisplayFilterSection.html)
