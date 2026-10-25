---
review_status: new
---

# Curl

Curl sends requests and displays responses from the command line. It is useful for HTTP inspection, API interaction, authentication testing, and file transfer.

## HTTP options

| Option | Purpose |
| --- | --- |
| `-I` | Request headers using HEAD |
| `-s` | Suppress progress output |
| `-v` | Display connection, request, and response details |
| `-X METHOD` | Specify a method |
| `-H 'Name: value'` | Set a header |
| `-d 'data'` | Send request body data |
| `-b cookies.txt` | Read cookies |
| `-c cookies.txt` | Save cookies |
| `--path-as-is` | Avoid normalizing the supplied path |
| `--ntlm -u 'user:password'` | Use NTLM authentication |
| `-T FILE` | Upload a file |
| `-G --data-urlencode 'key=value'` | Encode data into query parameters |

## Examples

```bash
curl -I https://example.com
curl -v http://example.com/
curl -X OPTIONS http://example.com/ -sv
curl -H 'Content-Type: application/json' -d '{"name":"example"}' https://example.com/api/items
curl -c cookies.txt https://example.com/
curl -b cookies.txt https://example.com/account
```

HEAD and GET can produce different application behavior. Use the actual request method when validating an observation. Preserve the relevant request and response when documenting a finding.
