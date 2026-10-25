---
review_status: new
---

# Burp Repeater

Repeater edits and resends HTTP requests while displaying their responses. It supports controlled manual testing of input validation, authorization, session handling, and [[Vulnerability Categories/SQL Injection - GEN|SQL Injection]].

## Request workflow

1. Capture a representative request in Proxy.
2. Send it to Repeater using the context menu or **Ctrl+R**.
3. Verify the destination host, port, and TLS setting.
4. Send a baseline request.
5. Change one relevant value and compare the response.
6. Keep useful variants in separate tabs and use request history to revisit changes.

Requests can also be constructed manually. Layout options place request and response views side by side, vertically, or in separate tabs.

## Message views and Inspector

| View | Purpose |
| --- | --- |
| Pretty | Readable formatting |
| Raw | The underlying HTTP message |
| Hex | Byte-level inspection |
| Render | A browser-style rendering of compatible response content |

Displaying non-printable characters helps identify CRLF sequences and other otherwise invisible bytes.

Inspector separates request attributes, query parameters, body parameters, cookies, request headers, and response headers. Editable request fields update the underlying message. Response headers describe the received response and are not request input.

## Comparison strategy

Record status, response length, headers, redirects, reflected values, and response time. A changed response is a lead; confirm the security consequence rather than treating any error as proof of a vulnerability.

For path parameters such as `/products/2` or `/about/2`, compare valid identifiers, invalid identifiers, type changes, and authorization boundaries.

## SQL injection example

An unescaped quote in an identifier may trigger a database error. A verbose error can reveal the table and selected columns, for example:

```sql
SELECT firstName, lastName, pfpLink, role, bio
FROM people
WHERE id = 2;
```

If a UNION injection is independently confirmed, the number and types of selected columns must match. A five-column query can be explored with an expression and four `NULL` placeholders:

```sql
0 UNION ALL SELECT column_name,NULL,NULL,NULL,NULL
FROM information_schema.columns
WHERE table_name='people'
```

If only one row is rendered, an aggregate such as `group_concat(column_name)` can expose multiple values in the same visible field. URL-encode request parameters as needed. Keep schema enumeration and extraction details in the SQL Injection note; Repeater supplies the edit, replay, and comparison workflow.
