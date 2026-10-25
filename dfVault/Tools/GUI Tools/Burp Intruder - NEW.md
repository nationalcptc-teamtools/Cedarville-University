---
review_status: new
---

# Burp Intruder

Intruder automates variations of a request by inserting payloads into selected positions. It is useful for parameter fuzzing, endpoint discovery, and credential auditing.

## Configuration

Send a request to Intruder with **Ctrl+I**. Clear automatically selected positions, then mark only the intended input using `§` delimiters.

```text
username=§user§&password=§password§
```

The position controls add, clear, or automatically identify insertion points. The payload configuration selects the payload type, values, processing rules, and encoding. Resource pools and settings control concurrency, result handling, redirects, and response matching where available.

## Attack types

| Type | How values are inserted | Request count |
| --- | --- | --- |
| Sniper | One payload set; vary one position at a time, leaving others at baseline | Positions × payloads |
| Battering ram | Insert the same payload into every marked position in each request | Payloads |
| Pitchfork | One set per position; advance the sets together | The shortest set's length |
| Cluster bomb | One set per position; try every combination | Product of the set lengths |

With two positions and three values, Sniper sends six requests and Battering ram sends three. Two three-entry sets produce three Pitchfork requests or nine Cluster bomb requests. Battering ram reuses a value across fields; it does not inherently perform a race-condition test.

## Payload processing

Payloads can be entered manually, pasted, or loaded from a file. Processing rules can transform case, encode values, or skip values matching a pattern. Processing order matters because one transformation's output becomes the next transformation's input.

Review automatic URL encoding when a payload requires literal characters or has already been encoded. Double encoding can change the test.

## Results

Compare status codes, response lengths, response bodies, redirects, and matched expressions. A login can return the same redirect code for both success and failure, so response length or a stable content marker may be more useful than status alone. Confirm apparent matches manually.

## Rotating CSRF tokens and session cookies

A request may require a fresh hidden token such as `loginToken` and a current `session` cookie. Replaying a stale value can cause rejection before the intended input is evaluated.

1. Record a macro that fetches the login form.
2. Create a session-handling rule that runs the macro before Intruder requests.
3. Restrict the rule to Intruder and the intended URL scope.
4. Update only `loginToken` and the necessary session cookie.
5. Keep username and password under Intruder's payload control.
6. Verify token refresh before starting a larger run.

Overly broad macro replacement can overwrite payload fields. Unexpected authorization failures should prompt inspection of token extraction, cookies, and request ordering.
