---
review_status: new
---

# Penetration Testing Frameworks

A framework structures assessment planning, coverage, validation, and reporting. Choose one based on the environment, engagement objectives, evidence requirements, and applicable obligations.

## Main frameworks

| Framework | Scope | Strength | Limitation |
| --- | --- | --- | --- |
| OSSTMM | Human, physical, wireless, telecommunications, and data-network channels | Repeatable measurement and operational analysis | Requires careful understanding of its metrics |
| OWASP WSTG | Web applications | Detailed web testing categories and techniques | Does not replace engagement planning or application-specific reasoning |
| NIST SP 800-115 | Systems, networks, and applications | Assessment planning and technical testing guidance | Requires tailoring to the organization |
| PTES | End-to-end penetration tests | A practical engagement lifecycle | Technical implementation requires additional detail |
| ISSAF | Network and system assessment | A detailed historical adversarial progression | Treat older technical guidance in its historical context |
| MITRE ATT&CK | Adversary behavior | Shared names for tactics and techniques | Does not define a complete assessment lifecycle |

## OSSTMM

The Open Source Security Testing Methodology Manual emphasizes consistent observation and measurable operational security. Its five channels cover human, physical, wireless, telecommunications, and data networks. Measurements such as Relative Attack Values support comparison, but depend on consistent definitions and collection.

Use its planning and measurement discipline to avoid equating a list of scanner findings with a complete assessment.

## OWASP WSTG

The Web Security Testing Guide organizes web assessment across the software lifecycle. Coverage includes information gathering, configuration, identity management, authentication, authorization, session management, input validation, error handling, cryptography, business logic, and client-side behavior.

Use test cases to support coverage while adapting them to the application's actual architecture and workflows. A completed checklist does not prove that business logic has been assessed adequately.

## NIST SP 800-115

The assessment lifecycle includes planning, discovery, attack/validation, and reporting. The broader guidance distinguishes:

- **Review techniques:** Documentation, policies, configurations, and rules.
- **Target identification and analysis:** Host discovery, service mapping, and fingerprinting.
- **Vulnerability validation:** Confirming whether reported weaknesses are real.
- **Penetration testing:** Demonstrating achievable consequences through controlled attack paths.

Use the guide when consistent planning, evidence, and organizational reporting requirements are central to the engagement.

## PTES

The Penetration Testing Execution Standard defines seven activities:

1. Pre-engagement interactions.
2. Intelligence gathering.
3. Threat modeling.
4. Vulnerability analysis.
5. Exploitation.
6. Post-exploitation.
7. Reporting.

The phases connect assessment objectives and business context to technical work and final evidence. Revisit earlier phases when discoveries change the understanding of the environment.

## ISSAF

The Information Systems Security Assessment Framework groups work into planning and preparation, assessment, and reporting/cleanup. Its assessment progression includes:

1. Information gathering.
2. Network mapping.
3. Vulnerability identification.
4. Penetration.
5. Gaining access and privilege escalation.
6. Further enumeration.
7. Compromising remote users or sites.
8. Maintaining access.
9. Covering tracks.

Persistence and log manipulation describe adversary behavior. Demonstrate or document them within engagement constraints, preserve assessment evidence, and remove approved test artifacts during cleanup.

## MITRE ATT&CK

Tactics describe objectives, techniques describe methods, and sub-techniques describe narrower behavior. ATT&CK enriches findings from another assessment method rather than replacing scoping, permission, execution, or reporting.

Examples of useful mappings include spearphishing attachments (`T1566.001`), exploitation of public-facing applications (`T1190`), credential dumping (`T1003`), and collection from information repositories (`T1213`). Map observed behavior precisely; a tactic name alone does not establish a particular technique.

## Specialized references

| Reference | Best fit |
| --- | --- |
| OWASP MASTG | Android and iOS application testing |
| CSA Cloud Controls Matrix | Cloud governance and control assessment |
| PCI DSS penetration testing guidance | Environments handling payment card data |
| CBEST | Threat-intelligence-led assessment in the UK financial sector |
| WASC Threat Classification | Historical web threat taxonomy |

## Selection criteria

Identify the primary technology, regulatory context, assessment depth, required deliverables, team experience, and available time. A web application test can combine PTES for engagement management, WSTG for technical coverage, and ATT&CK for behavior mapping. Cloud control review and adversarial exploitation may require complementary references because they answer different questions.
