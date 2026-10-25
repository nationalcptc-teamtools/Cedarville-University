---
review_status: new
---

# HTTP

HTTP exchanges requests and responses between clients and servers. Plain HTTP commonly uses TCP port 80; HTTPS commonly uses port 443 and protects the exchange with TLS.

## Request structure

```http
GET /index.html HTTP/1.1
Host: example.com

```

The request line gives the method, path, and protocol version. Headers supply context such as the intended host, accepted formats, cookies, and content type. An empty line separates headers from an optional body.

## Response structure

```http
HTTP/1.1 200 OK
Server: example-server
Content-Type: text/html
Content-Length: 13

Hello, world!
```

The status line indicates the result. Headers describe the response and can disclose server software, caching behavior, session state, and supported features.

## Inspection

```bash
curl -I http://example.com/
curl -v http://example.com/
telnet example.com 80
```

HEAD requests headers without a response body; GET retrieves a representation. They can exercise different application paths. Browser developer tools expose both top-level requests and background requests made by JavaScript.

Plaintext HTTP can be read or modified by an observer positioned on the network path. HTTPS adds authenticated encryption when certificate and protocol validation succeed.
