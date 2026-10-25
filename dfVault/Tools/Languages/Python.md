
# Python for Security Tooling

Python supports small utilities, protocol clients, data processing, and web application development.

## Temporary file serving

```bash
python3 -m http.server 8000
```

This serves the working directory. Choose the directory deliberately because backups, dotfiles, and other unintended files can become reachable.

## JSON formatting

```bash
curl -s https://example.com/api/items | python3 -m json.tool
```

The formatter improves readability of valid JSON; it does not validate the security or trustworthiness of the data.

## Frameworks and extension runtimes

Django provides a Python web application framework. Some legacy Burp extensions use Jython, a Java-based Python implementation. Match extension requirements to the configured runtime rather than assuming that every Python script is interchangeable.
