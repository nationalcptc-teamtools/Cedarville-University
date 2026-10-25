Nmap, or Network Mapper, is a tool which can perform host discovery and can scan [[Ports]] by sending specially crafted packets to targets and analyzing responses.

Nmap is also capable of enumerating the services running on each port based on the port response (open, closed, or filtered).

Nmap is a tool used for [[Enumeration and Scanning]], and is considered active reconnaissance.

There is a 9 step progress to fully map the target network with Nmap
	1. Enumerate Targets
	2. Discover live hosts
	3. Reverse-DNS lookup
	4. Scan Ports
	5. Detect Versions
	6. Detect OS
	7. Traceroute
	8. Scripts
	9. Write Output

Command structure:
sudo nmap -options targets

Command Details
---
**Target Specification**
	- list: MACHINE_IP example.com TARGET_IP will can 3 IP addresses
	- range: 10.10.10.10-15 will scan 6 IP addresses (10, 11...15)
	- subnet: MACHINE_IP/30 will scan 4 IP addresses
		- uses [[CIDR]] notation
	Can use a file as input, with the -iL option
		nmap -iL targets.txt
	To check the hosts Nmap will scan, use the -sL option
		nmap -sL Targets

**Online Host Discovery**
	- privileged user (root or sudo)
		1. When scanning targets on a local network, Nmap uses ARP requests because ARP scans are more reliable than ICMP scans
		2. When scanning targets outside the local network, Nmap uses ICMP echo requests, TCP ACK to port 80, TCP SYN to port 443, and ICMP timestamp request.
	- unprivileged user
		1. Nmap uses a TCP 3-way handshake by sending SYN packets to ports 80 and 443.
	Nmap defaults to a ping scan to find live hosts and port scans them. To scan a target without port scanning the live systems, use the option -sn TARGET_IP.
	To not use reverse-DNS resolution to obtain target names (enabled by default) use the -n option.
	Be default Nmap looks up online hosts, but use the option -R to query the DNS server for offline hosts.
	To add a specific DNS server, add the --dns-servers DNS_SERVER option.

**Port Specification**
	To scan ports in consecutive order, rather than random (default), use the -r option
	To enable fast mode and decrease the number of scanned ports from 1000 to 100 most common ports, use the -F option
	To scan all ports, use the -p- option
	To scan a list of ports X, Y, and Z use the option -pX,Y,Z
	To scan a range of ports X through Z, use the option -pX-Z
	To probe open ports to identify the service and version, use the option -

**Scan Timing and Speed**
	Nmap allows control of scan timing with the option -T<0-5>
		T0 - paranoid
			T0 scans one port at a time and waits 5 minutes between each probe.
		T1 - sneaky
		T2 - polite
		T3 - normal
		T3 is the default scanning speed
		T4 - aggressive
		T5 - insane
	Nmap allows control of packet rate with the option --min-rate(number) and --max-rate(number)
		For example, --max-rate 10 or --max-rate=10 ensures the scanner sends no more than 10 packets per second.
	Nmap allows control of probing parallelization using --min-parallelism(number) and --max-parallelism(number)
		Nmap probes targets to discover live hosts and open ports. Probing parallelization specifies the number of probes that can be run in parallel.

**Evasion and Spoofing**
	In some network environments, it is possible to scan a target using a spoofed IP address or even a spoofed MAC address. This is only useful when one can capture the response.
	---
	IP Address Spoofing
		To spoof an IP, use the option -S SPOOFED_IP
				ex. nmap -S SPOOFED_IP TARGET
		Scanning with a spoofed IP Address has three steps
			1. The attacker sends a packet with a spoofed source IP address to the target
			2. The target replies to the spoofed IP address as the destination
			3. The attacker captures replies to identify open ports.
		In general, specify the network interface with the option -e  and explicitly disable ping scan as well with -Pn. This scan is useless if the attacker's system cannot monitor the network for responses.
			ex. nmap -e NET_INTERFACE -Pn -S SPOOFED_IP TARGET
	---
	MAC Address Spoofing
		If the attacker and target are on the same subnet (same Ethernet (802.3) network or the same WiFi (802.11)), it is possible to spoof the [[Protocols and Notation/MAC Address - GEN|MAC Address]] of the attacker's machine. To spoof a MAC address, use the option --spoof-mac SPOOFED_MAC
			ex. nmap --spoof-mac SPOOFED_MAC TARGET
	---
	Decoy Scans
		Spoofing only works in minimal cases, so decoys is another method that might help obfuscate the attacker. This option will make scans appear to come from all the decoys as well as the attacker's machine.
			To launch a decoy scan, use the option -D DECOY, DECOY, ME
		Decoy scans can use specific or random IP addresses and can be in any order (use RND to indicate random)
			ex. nmap -D 10.10.0.1, RND, ME, RND, 10.68.47.207 TARGET
	---
	Fragmented Packets
		Fragmenting packets divides the bits in the destination portion of the IP Header. This can be used to evade the malicious rules of an Intrusion Detection System ([[Architecture/IDS - GEN|IDS]]) or [[Architecture/Firewall - GEN|Firewall]] rules.
			-f divides the IP data into 8 bytes or fewer
			-ff divides the IP data into 16 byte-fragments instead of 8
			--mtu can change the default value, but a multiple of 8 must always be used
		To increase the size of packets, use the option --data-length NUM, where NUM is the number of bytes appended to each packet
	---
	Idle/Zombie Scans
		Spoofing, while stealthy, requires specific network set ups and the ability to monitor traffic.
		A zombie/idle scan uses the IP of an idle host, and then uses that host to observe responses. This leverages the IP identification (IP ID) value in the IP header.
		The idle host MUST not be busy, otherwise the IP IDs can't be compared accurately.
		---
		There are 3 steps to discover an open port with an idle scan
		1. The scanner triggers the idle host to record the current IP ID of the idle host
		2. The scanner sends a SYN packet to a TCP port on the target. The packet spoofed to appear to come from the idle host's IP address.
			If the TCP port is closed, the target system responds to the idle host with an RST packet. The idle host does not respond, and its IP ID is not incremented.
			-
			If the TCP port is open, the target system responds to the idle host with a SYN/ACK packet. The idle hosts responds to the unexpected packet with an RST, incrementing its IP ID.
			-
			If the target does not respond due to firewall rules, the idle host will not respond, and its IP ID is not incremented.
		3. The scanner retriggers the idle host to compare the IP IDs.
			If the difference between the first IP ID and the latter is 1, then the target port is closed or filtered. If the difference is 2, then the target port is open.

**Service Detection**
	Nmap can probe ports to identify the services running on it. To determine service and version information for open ports, use the option -sV
		control the intensity with --version-*intensity* <0-9>
			0, the lightest, 9 the most complete
			-sV --version-light has an intensity of 2
			-sV --version-all has an intensity of 9
	Note that -sV forces Nmap to proceed with the [[TCP]] 3-way handshake and establish the connection. Therefore, a stealth SYN scan (-sS) is not possible with -sV.
	Note that -sV will require root privileges (shell as root or sudo)
		ex. nmap -sV --version-light TARGETS

**Traceroute**
	Nmap has a unique traceroute style. The traceroute (or tracert) style on Linux, macOS, and Windows starts with a low TTL (Time to Live) and increases until it reaches the target.
	Nmap's traceroute starts with a packet with a high TTL and decreases it over time.
	To identify the routers between the client and the target, use the option --traceroute

**OS Detection**
	Nmap can detect the [[Architecture/Operating System - GEN|Operating System]] of a target based on its behavior and network responses.
	Nmap may fail to find an exact match for the target OS due to virtualisation, firewall filtering, kernel customization, or other variables that could modify packet characteristics.
	To enable OS detection, use the option -O

**Output**
	To get the explicit reason behind Nmap's report, use the option --reason
	For verbose output, use either the option -v or -vv
	For debugging details, use the option -d or -dd

**Saving Results**
	To save Nmap output to a file use the option, -oN example.txt
	To save Nmap output to a grepable file format use the option, -oG example.txt
	To save Nmap output to a XML file use the option, -oX example.txt
	To save Nmap scan output in all three formats (normal, grepable, and xml) use the option, -oA example.txt

---

Host Discovery Scans
---
**ARP scan**
An ARP scan uses Address Resolution Protocol ([[ARP]]) queries to discover live hosts on a subnet.

An ARP scan can only be used on targets on the same subnet as the client.

Nmap can use an ARP scan to identify live hosts by the ARP reply.

To only use an ARP scan, use the option -PR.

For more ARP scan options, use [[Arp-scan]].

---
**ICMP scan**
An ICMP scan pings IP addresses with Internet Control Message Protocol ([[ICMP]]) packets to identify live hosts by the responses.

An ICMP echo scan is not always reliable since many firewalls block ICMP echo, and some by default. Also, an ARP query precedes ICMP requests if on the same subnet.

Since ICMP echo requests are usually blocked, ICMP Timestamp or ICMP Address Mask requests can help identify live hosts.

ICMP Echo
	Nmap uses a ping (ICMP Type 8/Echo) and checks for a ping reply (ICMP Type 0).

	To use ICMP echo requests, use the option -PE.

ICMP Timestamp
	Nmap uses a timestamp request (ICMP Type 13) and checks for a Timestamp reply (ICMP Type 14).

	To use ICMP timestamp requests, use the option -PP.

ICMP Address Mask
	Nmap uses address mask queries (ICMP Type 17) and checks for an address mask reply (ICMP Type 18).

	To use ICMP Address Mask Requests, use the option -PM

Good practice involves multiple times of scans, especially since different types of ICMP packets may or may not be blocked.

---
**TCP scan**
A TCP scan sends packets with TCP options to TCP ports, and can identify live hosts by the response.

Privileged users do not need to complete the [[TCP]] handshake, even if the port is open. Unprivileged users must complete the [[TCP]] handshake if the port is open.

TCP SYN
	Nmap uses packets with the SYN (Synchronize) option to a [[TCP]] port (80 by default) and checks for a ACK (Acknowledge) response. A closed port results in an RST (Reset).
	
	To use TCP SYN packets, use the option -PS
	
	Specific port numbers should follow -PS immediately, such as -PSx; -PSx-z; -PSx,y,z. The default port is 80.

TCP ACK
	Nmap uses packets with the ACK (Acknowledge) option to a [[TCP]] port and checks for a RST (Reset) response, which will confirm a live host. TCP ACK scans must be run as a privileged user, otherwise Nmap will attempt the [[TCP]] handshake.
	
	
	To use TCP ACK ping, use the option -PA
	
	Specific port numbers should follow -PA immediately, such as -PAx; -PAx-z; -PAx,y,z. The default port is 80.

---
**UDP Scan**
A UDP scan sends [[UDP]] packets to ports and checks for live hosts by the response.

A UDP packet sent to an open port will not generate a reply. A UDP packet send to a closed port will generate an ICMP port unreachable packet, which indicates the targeted host is live.

	To use a UDP scan, use the option -PU

---

Port Scans
---
While [[Ports]] can be generally understood as either open or closed, firewalls can interfere in scanning. Nmap therefore classifies ports in one of six ways.
1. Open - a service is listening on the specified port
2. Closed - no service is listening on the specified port, but it is accessible (not blocked by a firewall or other security programs)
3. Filtered - Nmap cannot determine if the port is open or closed because the port is not accessible (usually a firewall preventing Nmap from reaching the port)
4. Unfiltered - Nmap cannot determine if the port is open or closed, although the port is accessible (encountered when using an ACK scan -sA)
5. Open|Filtered - Nmap cannot determine whether the port is open or filtered
6. Closed|Filtered - Nmap cannot determine whether a port is closed or filtered

---
**TCP Connect port scan**
A TCP connect scan completes the [[TCP]] 3-way handshake to determine the port state. Nmap tears the connection as soon as the port state is confirmed by sending a RST/ACK.

Client --> SYN --> Server
Client <-- SYN, ACK <-- Server
Client --> ACK --> Server
Client --> RST, ACK --> Server

	To use a TCP Connect port scan, use the option -sT

Note that for an unprivileged user, a TCP Connect scan is the only option to discover open TCP ports.

---
**TCP SYN port scan**
A TCP SYN scan does not complete the [[TCP]] 3-way handshake, but tears down the connection once it receives a response from the server.

Because no TCP connection was established, the scan is less likely to be logged.

	To use a TCP SYN port scan, use the option -sS

Note that the default scan mode is the TCP SYN scan, for a privileged user

---
**UDP port scan**
UDP is a connectionless protocol, and has no handshake for connection. There is no way to guarantee a service listening on a UDP port would respond to packets.

A closed UDP port will return a ICMP port unreachable error ([[ICMP]] type 3, code 3).

	To use a UDP port scan, use the option -sU

---

Advanced Port Scans
---
Advanced Port Scans set different flags in the [[TCP]] header to map a target environment based on responses.

Note that many nmap options require sudo permissions, unless running as root.

**Stateless Firewall Scans**
The Null, FIN, and Xmas scans are all similar. They are particularly effective when scanning a target behind a stateless (non-stateful) firewall. Stateless firewalls check for the SYN flag to detect connection attempts. Other flag combinations can deceive the firewall and allow access to the system behind it.

A stateful firewall, practically, blocks all such packets, rendering these scans useless.

**Stateful Firewall Scans**
	FIXME

---
**Null Scan**
The null scan sends packets set with no flags; all six flag bits are set to 0. A closed port will respond with a RST packet to a "null packet."

Therefore, a lack of response indicates the port is either open or blocked by a firewall.

	To use a null scan, use the option -sN

---
**FIN Scan**
A FIN scan sends packets set with the FIN flag. If a port is closed, the system should respond with an RST packet.

Therefore, a lack of response indicates the port is either open or blocked by a firewall.

	To use a FIN scan, use the option -sF

---
**Xmas Scan**
A Xmas scan sends packets set with the FIN, PSH, and URG flags simultaneously.

Similarly to the Null and FIN scans, a RST packet indicates the port is closed. If there is no response, the port will be reported as open|filtered.

	To use an Xmas scan, use the option -sX

---
**Maimon Scan**
A Maimon scan sends packets set with the FIN and ACK flags. The target should respond with an RST packet whether the port is open or closed.

Some BSD-deprived systems will drop the packet if the port is open.

This scan is not effective on most modern networks.

	To use a Maimon scan, use the option -sM

---
**ACK Scan**
A TCP ACK scan sends packets set with the ACK flag. The target will respond with RST regardless of the port's state. So while this scan cannot determine the state of a port, it can help determine firewall rule sets and configurations.

Note that although a firewall may not be blocking a port, there may not be a service listening at the port.

	To use an ACK scan, use the option -sA

---
**Window Scan**
A TCP window scan is similar to a TCP ACK scan, but it examines the TCP Window field of RST packets returned. This can reveal if the port is open.

Note that although a firewall may not be blocking a port, there may not be a service listening at the port.

	To use a Window scan, use the option -sW

---
**Custom Scan**
To use a TCP flag combination beyond the built-in TCP scan types, use the option --scanflags FLAG_TYPES
	ex. nmap --scanflags RSTSYNFIN TARGET

---

Scripts
---
Nmap supports [[Scripts]] written in Lua. The Nmap Scripting Engine (NSE) is a Lua interpreter that allows Nmap to execute Lua [[Scripts]].

The default Nmap installation contains several hundred scripts.

To run Nmap's default scripts to pull details such as supported authenticated methods, use the option -sC or the option *default*.

To run scripts use the option, --script=scriptExample

| Script Category | Description                                                             |
| --------------- | ----------------------------------------------------------------------- |
| auth            | Runs authentication-related scripts                                     |
| broadcast       | Discovers hosts by sending broadcast messages                           |
| brute           | Performs brute-force password auditing against logins                   |
| default         | Runs default scripts (same as -sC)                                      |
| discovery       | Retrieves accessible information, such as database tables and DNS names |
| dos             | Detects servers vulnerable to Denial of Service (DoS)                   |
| exploit         | Attempts to exploit various vulnerable services                         |
| external        | Checks using a third-party service, such as Geoplugin and Virustotal    |
| fuzzer          | Launches fuzzing attacks                                                |
| intrusive       | Runs intrusive scripts such as brute-force attacks and exploitation     |
| malware         | Scans for backdoors                                                     |
| safe            | Runs safe scripts that won't crash the target                           |
| version         | Retrieves service versions                                              |
| vuln            | Checks for vulnerabilities or exploits in a vulnerable service          |

---

Option Table
---

| Option | Action                           |
| ------ | -------------------------------- |
| -PR    | ARP Host Discovery Scan          |
| -PE    | ICMP Echo Host Discovery         |
| -PP    | ICMP Timestamp Host Discovery    |
| -PM    | ICMP Address Mask Host Discovery |
| -PS    | TCP SYN Host Discovery           |
| -PA    | TCP ACK Host Discovery           |
| -PU    | UDP Host Discovery               |

| Option | Action                |
| ------ | --------------------- |
| -sT    | TCP Connect Port Scan |
| -sS    | TCP SYN Port Scan     |
| -sU    | UDP Port Scan         |


| Option            | Action               |
| ----------------- | -------------------- |
| -sN               | TCP Null Scan        |
| -sF               | TCP FIN Scan         |
| -sX               | TCP Xmas Scan        |
| -sM               | Maimon Scan          |
| -sA               | TCP ACK Scan         |
| -sW               | TCP Window Scan      |
| --scanflags FLAGS | Custom TCP Flag Scan |


| Option              | Action                                                 |
| ------------------- | ------------------------------------------------------ |
| -S SPOOFED_IP       | change the source IP Address of packets                |
| --spoof-mac         | change the source MAC Address of packets               |
| -D DECOY, ME, DECOY | add decoy hosts to the scan to obfuscate attacker data |
| -f; -ff; -mtu       | packet fragmentation                                   |
| --data-length NUM   | append bytes to increase packet size                   |
| -sI ZOMBIE_IP       | idle/zombie scan                                       |


| Option   | Action                     |
| -------- | -------------------------- |
| --reason | explains reasoning         |
| -v       | verbose                    |
| -vv      | very verbose               |
| -d       | debugging                  |
| -dd      | more details for debugging |

| Option  | Action                               |
| ------- | ------------------------------------ |
| -p-     | scan all ports                       |
| -F      | scan 100 most common ports           |
| -r      | scan ports in consecutive order      |
| -T<0-5> | scan timing                          |
| -sn     | host discovery without port scans    |
| -n      | not use reverse DNS for target names |

| Option                          | Action                                |
| ------------------------------- | ------------------------------------- |
| -sV                             | service and version detection         |
| -sV --version-*intensity* <0-9> | intensity of service detection probes |
| -O                              | operating system detection            |
| --traceroute                    | runs traceroute to the target         |
| --script=SCRIPTS                | run Nmap scripts                      |
| -sC / --script=default          | run default Nmap scripts              |
| -A                              | equivalent to -sV -O -sC --traceroute |

| Option          | Action                                          |
| --------------- | ----------------------------------------------- |
| -oN example.txt | save output in normal format                    |
| -oG example.txt | save output in grepable format                  |
| -oX example.txt | save output in XML format                       |
| -oS example.txt | save output in Script Kiddie format             |
| -oA example.txt | save output in normal, grepable, and xml format |
