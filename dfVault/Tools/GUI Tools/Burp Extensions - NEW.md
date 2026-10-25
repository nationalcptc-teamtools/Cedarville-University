---
review_status: new
---

# Burp Extensions

Extensions add functionality to Burp Suite, such as logging, timing, message processing, custom checks, and integrations.

## Management

The Extensions interface lists installed modules and their enabled state. Add an extension from disk or install an available package from the BApp Store. Inspect its description, output, and error messages when troubleshooting.

Extension order can affect message processing when one extension changes data consumed by another. Some extensions add top-level tabs, while others add context-menu actions or background processing.

## Examples

- **Logger++:** Extends traffic logging and inspection.
- **Request Timer:** Records response timing for comparison and performance-sensitive testing.

Availability and compatibility depend on the installed Burp edition and extension version.

## Language runtimes

Java extensions run through the Java runtime. Legacy Python extensions can require a compatible Jython standalone JAR configured in the extension settings. Ruby extensions can use JRuby where supported.

For Jython-based extensions, download the standalone interpreter, configure its location in Burp, then load the compatible extension. A Python extension written for that environment is not automatically compatible with every Python runtime.

## Development interface

Burp exposes extension APIs for working with HTTP messages, adding user-interface components, and integrating custom behavior. Consult the API documentation for the installed version before implementing or updating an extension.

[Burp extension documentation](https://portswigger.net/burp/documentation/desktop/extend-burp/extensions/creating)
