Enumeration and Scanning is the second part of a cyber operation or penetration test. It involves gathering all available information on a subject without launching an attack, or active reconnaissance. This includes scanning, discovering topology, etc.

This is a part of the Reconnaissance step of the Cyber Kill Chain.

1. Map network topology and discover live hosts
	- [[NMAP]]
	- [[Tools/CLI Tools/Ping - GEN|Ping]]
2. Enumerate subdomains and directories
	- [[Gobuster]] - directory brute forcing
	- [[Tools/CLI Tools/Sublist3r - GEN|Sublist3r]] - subdomain enumeration
	- [[FFUF]] - subdomain enumeration
3. Vulnerability Scanning
	- [[NMAP]]
	- [[Tools/CLI Tools/Metasploit - GEN|Metasploit]]
4. *HTTP Domain enumeration*
	1. *Discover web server type*
	2. *Check broken validation*
	3. *Check for SQL injects*

[[Walking an Application]]

Specific Vulnerabilities
1. Insecure Direct Object Reference ([[IDOR]])
2. File Inclusion




Network Topology -  [[NMAP]]; [[Tools/CLI Tools/Ping - GEN|Ping]]

Active Subdomain enumeration - [[FFUF]]; [[Tools/GUI Tools/BURP Suite - GEN|BURP Suite]]

Directory Brute-Forcing - [[Gobuster]]; [[Tools/GUI Tools/BURP Suite - GEN|BURP Suite]]

Identifier Enumeration - [[Tools/GUI Tools/BURP Suite - GEN|BURP Suite]]

REST API Enumeration - [[Tools/GUI Tools/BURP Suite - GEN|BURP Suite]]


Password Attacks
	1. [[Hydra]] - Brute Force Attacks
	2. [[Tools/CLI Tools/Hashcat - GEN|Hashcat]] - Cracking Hashes
	
	https://crackstation.net/ - hash and original string database

Vulnerability Scanning
	1. [[Tools/CLI Tools/Linpeas - GEN|Linpeas]]
	2. [[Tools/CLI Tools/Nuclei - GEN|Nuclei]]
	3. [[Tools/CLI Tools/Katana - GEN|Katana]]
	4. [[Tools/CLI Tools/Greenbone Vulnerability Management - GEN|Greenbone Vulnerability Management]]

