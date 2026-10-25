---
aliases:
  - "Rust"
generated: true
sources_checked: 2026-10-23
---

# Rust - GEN

Rust compiles programs from `.rs` source files. A simple program starts in `main`:

```rust
fn main() {
    println!("Example");
}
```

```bash
rustc example.rs
```

Ownership is a set of memory-management rules checked by the compiler. Values have owners, and ownership behavior determines when resources are released. This differs from relying on a garbage collector or manually freeing every allocation.

Understanding ownership helps when comparing Rust with [[Tools/Languages/C - GEN|C]] and when reading systems-level code. Compilation and ownership rules do not remove the need to assess application logic.

**Sources**
---
- [Rust book: Program structure and compilation](https://doc.rust-lang.org/book/ch01-02-hello-world.html)
- [Rust book: Ownership](https://doc.rust-lang.org/book/ch04-01-what-is-ownership.html)
