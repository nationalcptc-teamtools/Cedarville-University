FFUF (Fuzz Faster U Fool) is general purpose web fuzzing tool that uses wordlists to discover hidden resources by replacing the FUZZ placeholder.

ffuf -w wordlist.txt -u http://MACHINE_IP/FUZZ

On servers hosting multiple websites, the Host header communicates which site the client is requesting. FFUF can modify the Host header to discover virtual hosts.

To add or modify an http header, use the option -H
	Authentication
		-H "Cookie: session=example"
	Virtual Host (Host header)
		-H "Host: FUZZ.example.com"
		tests for word.example.com

To ignore results of a specified response size, use the option -fs <size>