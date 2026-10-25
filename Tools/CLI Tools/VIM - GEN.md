---
aliases:
  - "VIM"
generated: true
sources_checked: 2026-10-23
---

# VIM - GEN

Vim is a modal text editor. Normal mode interprets keys as commands; Insert mode enters text.

```bash
vim notes.txt
```

| Key or command | Purpose |
| --- | --- |
| `i` | Enter Insert mode |
| Escape | Return to Normal mode |
| `h`, `j`, `k`, `l` | Move left, down, up, right |
| `x` | Delete a character |
| `u` | Undo |
| Ctrl+R | Redo |
| `:w` | Write the file |
| `:q` | Quit |
| `:wq` | Write and quit |
| `:q!` | Quit without saving changes |
| `:help` | Open help |

[[Nano]] provides another terminal editing workflow. Editing protected configuration files requires the appropriate filesystem permissions.

**Source**
---
[Vim user manual: First steps](https://vimhelp.org/usr_02.txt.html)
