---
review_status: new
---

# Burp Sequencer

Sequencer statistically analyzes tokens intended to be unpredictable, such as session identifiers. It examines whether observed output is consistent with randomness.

## Collection modes

**Live capture** repeatedly sends a request and extracts the selected value from a cookie, form field, or response location. **Manual load** analyzes a previously collected token set.

Select the actual token rather than surrounding syntax. Stable prefixes, timestamps, or encoding can affect interpretation. Keep collection conditions representative of the behavior being assessed.

## Analysis

A larger sample improves the usefulness of statistical tests; several thousand tokens may be needed for a meaningful initial analysis. Capture can be paused and analyzed before a full run completes.

The results describe effective entropy, confidence, and individual tests at character or bit level. Inspect the overall result together with test details and token structure.

## Interpretation limits

Statistical appearance does not prove a token generator is secure. A deterministic algorithm can produce output that looks random, and token security also depends on generation, secrecy, binding, lifetime, invalidation, and server-side validation.

Document the extraction location, sample size, collection method, and observed weakness. Avoid treating one failed statistical test as conclusive without investigating the cause.
