
A report translates assessment evidence into decisions and remediation work. It should tell a clear, reproducible account of what was tested, what was demonstrated, and why it matters.

## Audiences and structure

| Section | Audience and purpose |
| --- | --- |
| Executive summary | Business and security stakeholders: overall posture, impact, strengths, weaknesses, and priorities |
| Introduction and scope | All readers: objectives, assets, constraints, dates, and assessment context |
| Methodology | Security stakeholders: approach, coverage, and limitations |
| Findings summary | Decision-makers and implementers: ranked findings and affected assets |
| Detailed findings | Technical stakeholders: reproduction, evidence, impact, and remediation |
| Technical narrative and appendices | Assessors and engineers: supporting actions, artifacts, and detailed evidence |

## Executive summary

Use accessible language and keep the summary brief. Explain what was assessed, the most consequential outcomes, the overall pattern of strengths and weaknesses, and the remediation priorities. Avoid unexplained tools, payloads, and protocol details.

Technical severity should be connected to a concrete business consequence, such as unauthorized access to records, interruption of service, or compromise of administrative functions.

## Scope and methodology

State included and excluded assets explicitly. Record the testing period, access supplied, user roles, allowed techniques, constraints, and relevant assumptions. List important assessment artifacts and identify any untested areas.

Describe the method at a level that explains coverage and supports confidence in the conclusions. Keep the detailed execution narrative separate from the high-level explanation where that improves readability.

## Finding structure

1. Descriptive title and stable identifier.
2. Affected systems, endpoints, parameters, or accounts.
3. Technical severity, scoring model/version, and vector when used.
4. Organizational risk and business impact.
5. Vulnerability description and relevant CWE classification.
6. Preconditions and reproducible steps.
7. Evidence: requests, responses, screenshots, or other artifacts.
8. Practical remediation tailored to the implementation.
9. References and retest expectations where relevant.

Place findings in a consistent order and use a layout that makes each one easy to locate. For a paginated report, a new page per finding can improve navigation when it suits the chosen template.

## Evidence and technical narrative

Record the request or action, the observed response, and the security consequence. Evidence should demonstrate the claim rather than merely show a tool running.

For an authentication bypass, show the relevant input, the authenticated response or subsequent authorized resource access, and the account context. A redirect alone may not establish a successful login.

Keep enough context to reproduce the result, including cookies or prerequisites described safely. Redact secrets and personal information while retaining the evidence necessary to understand the finding.

## Remediation guidance

Address the root cause and explain an implementable approach. For SQL injection, separate query structure from untrusted values through parameterized queries and restrict dynamic identifiers with allowlists. Do not propose a replacement that preserves another weakness, such as direct plaintext password comparison.

Prioritize changes and distinguish immediate containment from durable repair. Avoid unsupported product endorsements or remediation claims that exceed the evidence.

## Writing and quality assurance

Use precise, neutral language, consistent terminology, and past tense for completed observations. Avoid first-person narration when the report's house style requires an objective voice. Define acronyms and remove unnecessary jargon or personal commentary.

Check technical accuracy, reproducibility, scope, severity rationale, grammar, formatting, references, redactions, and consistency between the summary and findings. Have another reviewer inspect important conclusions when possible.

## Delivery and closeout

Use agreed secure delivery and retention arrangements. Apply version control, resolve review feedback, document acceptance, and agree on remediation follow-up or retesting. Retain or dispose of assessment artifacts according to the engagement agreement.


Related notes
---

- [[Flat Images - GEN|Flat Images]]
