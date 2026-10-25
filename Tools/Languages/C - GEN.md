---
aliases:
  - "C"
generated: true
sources_checked: 2026-10-23
---

# C - GEN

C is a programming language commonly compiled into native programs. Source files, headers, the preprocessor, compilation, and linking contribute to building an executable.

```c
#include <stdio.h>

int main(void) {
    puts("Example");
    return 0;
}
```

With GCC, a simple build can use:

```bash
gcc example.c -o example
```

Important concepts include types, expressions, functions, arrays, structures, and pointers. Pointers refer to memory locations; arrays and pointer operations require careful reasoning about object boundaries.

[[Tools/GUI Tools/Ghidra - GEN|Ghidra]] can reconstruct a C-like view from compiled code, but that output is not the original source.

**Sources**
---
- [GNU C reference manual](https://www.gnu.org/software/gnu-c-manual/gnu-c-manual.html)
- [GCC invocation](https://gcc.gnu.org/onlinedocs/gcc/Invoking-GCC.html)
