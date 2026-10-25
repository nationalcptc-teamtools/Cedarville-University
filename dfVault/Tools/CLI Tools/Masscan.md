Masscan discovers reachable services by sending probes at high rates. Its target and port syntax resembles other network scanners, but its traffic generation and operational behavior differ.

```bash
masscan 192.0.2.0/24 -p443
masscan 192.0.2.0/24 -p80,443
masscan 192.0.2.0/24 -p22-25
masscan 192.0.2.0/24 --top-ports 100
```

Select ports and traffic limits appropriate to the network. Validate discovered services with protocol-specific inspection or a more detailed scanner.
