---
review_status: new
---

# Risk Management

A **vulnerability** is a weakness. A **threat** is a potential actor, event, or condition capable of exploiting a weakness. **Risk** concerns the likelihood and consequence of that exploitation in context.

For example, verbose errors can disclose internal paths. An attacker who can trigger those errors may use the information to support another attack. The risk depends on exposure, the information revealed, and what it enables.

## Management cycle

1. Identify assets, threats, and weaknesses.
2. Assess likelihood and impact.
3. Select and apply a treatment.
4. Review effectiveness and residual risk.

Technical severity and business risk are related but distinct. A generic score does not capture every asset dependency, compensating control, or operational consequence.

## Common causes

| Cause | Example consequence |
| --- | --- |
| Human assumptions | Trusting a client-supplied identity or role |
| Software defects | Incorrect parsing or validation |
| System complexity | Inconsistent authorization across services |
| Excessive customization | A security mechanism behaves differently from expected defaults |
| Technical or design flaws | Issuing a fully authenticated session before MFA completes |

Prioritize treatment using demonstrated impact, reachability, exploitability, affected assets, and operational context. Reassess when systems or threats change.
