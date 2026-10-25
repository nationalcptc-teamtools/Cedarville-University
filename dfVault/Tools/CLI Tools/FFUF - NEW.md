---
review_status: new
---

# FFUF

FFUF substitutes wordlist entries into marked parts of an HTTP request. It supports content discovery, virtual host enumeration, and parameter testing.

## Content and virtual hosts

```bash
ffuf -w /path/to/words.txt -u http://example.com/FUZZ
ffuf -w /path/to/subdomains.txt -H 'Host: FUZZ.example.com' -u http://192.0.2.10/
ffuf -w /path/to/subdomains.txt -H 'Host: FUZZ.example.com' -u http://192.0.2.10/ -fs BASELINE_SIZE
```

`FUZZ` identifies the insertion point. `-H` adds or changes a header; a Host-header payload probes virtual hosts routed by the same server. `-fs` excludes responses of a specified size after a baseline has been established.

## Form inputs and multiple lists

```bash
ffuf -w /path/to/usernames.txt -X POST \
  -d 'username=FUZZ&email=x&password=x&cpassword=x' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -u http://example.com/signup -mr 'username already exists'
```

Multiple wordlists can be named with markers such as `-w users.txt:W1,passwords.txt:W2`, then referenced as `username=W1&password=W2`.

| Option | Purpose |
| --- | --- |
| `-w` | Wordlist and optional marker name |
| `-u` | Target URL |
| `-X` | HTTP method |
| `-d` | Body data |
| `-H` | Header, including a cookie or content type |
| `-mr` | Match a response expression |
| `-fc` | Exclude status codes |
| `-fs` | Exclude response sizes |

Choose matchers and filters from the application's actual success and failure behavior. A status code alone is not a universal authentication indicator.
