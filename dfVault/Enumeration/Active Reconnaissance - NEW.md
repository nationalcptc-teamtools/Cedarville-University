---
review_status: new
---

# Active Reconnaissance

Active reconnaissance directly interacts with target systems to identify services, functionality, and security-relevant behavior.

## Browser-based reconnaissance

Browse the application, inspect page source, and use developer tools to observe the rendered DOM, JavaScript, background requests, headers, cookies, and storage.

HTTP and HTTPS commonly use ports 80 and 443, but applications can listen elsewhere. Include explicit ports when investigating another service.

## Supporting tools

- **FoxyProxy:** Switch between browser proxy configurations.
- **User-agent overrides:** Compare behavior for different advertised clients.
- **Wappalyzer:** Collect technology fingerprints.
- **Ping and Traceroute:** Investigate reachability and routing behavior.
- **Telnet and Netcat:** Inspect plaintext service exchanges and banners.
- **Nmap:** Discover hosts, ports, services, and related behavior.

Record the exact interaction and response. A fingerprint or failed probe is a lead to validate, rather than a complete statement of the system's security.
