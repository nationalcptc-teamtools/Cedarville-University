TLS (Transport Layer Security) is a [[Architecture/Transport Layer - GEN|Transport Layer]] protocol which encrypts traffic, creating the secure alternatives to default services such as FTP, HTTP, and TELNET.

TLS uses a handshake to ensure a secure connection between computers.

All TLS handshakes use asymmetric cryptography (public and private key), but not all use the private key in the process of generating session keys.

Note: RSA key exchange is no longer considered secure, and has been removed from TLS since version 1.3


**RSA key exchange**
	1. The client initiates by sending a hello message containing:
		- Client TLS version
		- Cipher suites supported
		- String of random bytes called the "Client Random"
	2. The server replies with its own hello message containing:
		- Server SSL certificate
		- Server cipher suite
		- String of random bytes called the "Server Random"
	3. *Client verifies SSL certificate with the certificate authority. This confirms the server's identity and that the client is interacting with the actual owner of the domain.*
	4. The client sends a string of random bytes "Premaster Secret" which is encrypted with the public key retrieved from the SSL certificate.
	5. *Server decrypts premaster secret using private key.*
	6. *Server and client generate session keys from the client random, the server random, and the premaster secret. These keys will be identical.*
	7. Client sends a "Finished" message encrypted with the session key.
	8. Server sends a "Finished" message encrypted with the session key.
	9. TLS handshake completed. Communication continues using the session keys.

**Ephemeral Diffie-Hellman handshake**
	1. The client initiates by sending a hello message containing:
		- Client TLS version
		- Cipher suites supported
		- String of random bytes called the "Client Random"
	2. The server replies with its own hello message containing:
		- Server SSL certificate
		- Server Cipher suite
		- String of random bytes called the "Server Random"
		- Digital Signature of all messages up to this point
	3. *The client verifies the server's digital signature and certificate.*
	4. The client sends its DH parameter to the server.
	5. *The client and server use the DH parameters they exchanged to calculate the premaster secret separately.*
	6. *The client and server calculate session keys from the premaster secret, client random, and server random.*
	7. Client sends a "Finished" message encrypted with the session key.
	8. Server sends a "Finished" message encrypted with the session key.
	9. TLS handshake completed. Communication continues using the session keys.
	
	DH stands for Diffie-Hellman. The Diffie-Hellman algorithm uses exponential calculations to arrive at the same premaster secret. The server and client each provide a parameter for the calculation. The calculation is different on each side, but with equal results.

**TLS 1.3**
	1. The client initiates by sending a hello message containing:
		- Client TLS version
		- Cipher suites supported
			- Insecure cipher suites are removed in TLS 1.3
		- String of random bytes called the "Client Random"
		- parameters for calculating the premaster secret
			- due to the simplified list of cipher suites, the client can assume it knows the server's preferred key exchange method
	2. *Since the server has the client random, parameters, and cipher suites, it has everything it needs to generate the master secret, and does so.*
	3. The server replies with a hello message containing:
		- Server SSL certificate
		- Server cipher suite
		- String of random bits called the "Server Random"
		- Digital signature of all messages up to this point
	At the point the server also sends a "Finished" message.
	4. *The client verifies signature and certificate, and generates the master secret.*
	5. The client sends a "Finished" message.
	6. TLS handshake completed. Communication continues using the session keys.

**O-RTT**
	1. The server sends a session ticket during the first session between the server and client.
	2. The client uses the session ticket to send encrypted data to the server on the first message of the next session, along with the session ticket.
	3. Because the client and server have connected to each other previously, they can each derive a shared secret from the first session, called the "resumption main secret."
	4. TLS resumes, without any round trips or back-and-forth communication between client and server.


For more reading on TLS, consult this article and its linked materials.
https://www.cloudflare.com/learning/ssl/what-happens-in-a-tls-handshake/
