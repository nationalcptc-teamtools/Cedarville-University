Gobuster is an enumeration tool written in Go.

To see available commands and global flags, use gobuster --help

Directory and File Enumeration (dir)
---
Dir mode brute-forces directories and files on a web server. The basic command syntax is included below.

gobuster dir -u "http://TARGET_IP" -w exampleWordlist.txt

Required Flags:
	-u specifies the target url
	-w specifies the wordlist file

Other dir mode flags:

| Flag                     | Description                                                    |
| ------------------------ | -------------------------------------------------------------- |
| -x / --extensions        | File extensions to search for (e.g., -x .php,.txt,.js)         |
| -r / --followredirect    | Follow HTTP redirects                                          |
| -k / --no-tls-validation | Skip TLS certificate verification (useful in lab environments) |
| -s / --status-codes      | Only show specific status codes (e.g., -s 200,301)             |

---

DNS Subdomain Enumeration (dns)
---
DNS mode performs DNS lookups using a wordlist as subdomain candidates. The default command syntax is included below.

gobuster dns -d target.com -w exampleWordlist.txt
	this generates searches for wordlistEntry.target.com

Required Flags:
	-d specifies the target domain
	-w specifies the wordlist file

The option --wildcard is used to force enumeration despite wildcard DNS, which can generate potential false positives.

Other dns mode flags:

| Flag            | Description                                      |
| --------------- | ------------------------------------------------ |
| -d / --domain   | The target domain to enumerate                   |
| -i / --show-ips | Show the IP addresses that subdomains resolve to |
| -r / --resolver | Use a custom DNS server for lookups              |

---

Virtual Host Enumeration (vhost)
---


---

Global Options
---

| Flag            | Description                                                            |
| --------------- | ---------------------------------------------------------------------- |
| -t / --threads  | Number of concurrent threads (default: 10). Increase for faster scans. |
| -w / --wordlist | Path to the wordlist file. Required for all modes.                     |
| -o / --output   | Write results to a file instead of stdout.                             |
| --delay         | Wait time between requests: useful against rate-limited servers.       |
