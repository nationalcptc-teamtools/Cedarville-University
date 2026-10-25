---
aliases:
  - "Ghidra"
generated: true
sources_checked: 2026-10-23
---

# Ghidra - GEN

Ghidra is a software reverse engineering framework with disassembly, decompilation, navigation, and scripting capabilities.

**Basic workflow**
---
1. Create a project and import a program.
2. Check the detected format, language, and processor assumptions.
3. Run analysis and open CodeBrowser.
4. Inspect functions, strings, references, and the assembly listing.
5. Use the Decompiler to examine a C-like representation.
6. Rename symbols, refine types, and add comments as understanding improves.

Decompiler output is a reconstruction, not the original [[Tools/Languages/C - GEN|C]] source. Types and function definitions affect the generated representation. Compare important conclusions against the listing.

**Source**
---
[Ghidra: Introduction and CodeBrowser guide](https://ghidra.re/ghidra_docs/GhidraClass/Beginner/Introduction_to_Ghidra_Student_Guide.html)
