---
review_status: new
---

# Burp Decoder

Decoder transforms captured data or prepared input through encoding, decoding, and hashing operations. Send selected data from another Burp component using **Send to Decoder**, or paste it directly into the workspace.

## Representations and transformations

The text and hexadecimal views display the same bytes differently. Each transformation creates another pane, allowing several operations to be chained and compared.

| Transformation | Use |
| --- | --- |
| URL encoding | Percent-encode bytes, such as `/` as `%2F` |
| HTML entities | Represent HTML-sensitive characters using entities |
| Base64 | Represent bytes using a text alphabet and optional padding |
| ASCII hex | Represent each byte as hexadecimal digits |
| Hex, octal, or binary numeric forms | Convert between supported numeric representations |
| Gzip | Compress or decompress compatible data |

Smart Decode attempts to recognize an encoding automatically. Inspect the result because layered, ambiguous, or malformed data can require explicit transformations.

## Hashing

A hash produces a fixed-length digest of input. It is not reversible encoding. Identical inputs under the same algorithm produce identical outputs, while small input changes should substantially alter the digest.

Decoder can calculate supported digests and show them as text or hexadecimal bytes. MD5 is useful for recognizing legacy values or comparing file content, but is unsuitable as a modern collision-resistant security primitive or password storage scheme.

## Testing sequence

1. Preserve the original value.
2. Identify the outer representation.
3. Decode one layer at a time.
4. Inspect and modify the underlying data if appropriate.
5. Reapply transformations in reverse order.
6. Compare server behavior with the baseline.

Encoding does not provide confidentiality, integrity, or authorization. A Base64-encoded session object is still client-controlled unless the server independently protects and validates it.
