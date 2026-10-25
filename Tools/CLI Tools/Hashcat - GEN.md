---
aliases:
  - "Hashcat"
generated: true
sources_checked: 2026-10-23
---

# Hashcat - GEN

Hashcat is a password recovery tool that tests candidate passwords against supported hash formats. It performs offline comparison rather than submitting login attempts to a server.

```bash
hashcat -m HASH_MODE -a 0 hashes.txt words.txt
hashcat --example-hashes
```

**Important options**
---
- `-m`: Hash format or mode.
- `-a`: Candidate-generation attack mode.
- `-a 0`: Straight wordlist mode.
- `-a 3`: Mask mode.
- `-a 6` / `-a 7`: Hybrid wordlist and mask modes.
- `--show`: Display recovered entries for the supplied hash list.

Select the mode from the actual stored format, not the digest length alone. [[Resources/Wordlists - GEN|Wordlists]] supply candidates; [[Hydra]] instead interacts with network authentication services.

**Source**
---
[Hashcat documentation and option reference](https://hashcat.net/wiki/doku.php?id=hashcat)
