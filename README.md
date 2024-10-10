= chad

This is my ideal programming language that I want to build:

- Garbage collected Rust (mix procedural and functional)
- Pattern matching like Rust (enums, structs)
- Compiled using Zig backend (use incremental compilation feature) / QBE
- Async like Elixir, using tasks. Integrated async runtime, no coloring
- Error handling like Zig
- Testing like Zig
- Same function signatures as Zig

The language is ideal as a general purpose, highly concurrent applications
that needs to run fast and be developed fast. It should be expressive meaning
that little code is needed to express the ideas, simple macros / comptime without killing compile
times. Development cycle should be fast, maximum 1 second cycle. Optimized
for developer experience by being an expressive language with excellent edit cycle
and great performance.

Basically I want to take the best features of Rust, Zig, and Elixir with the same goals
as Go in mind to create an excellent language with optimal compile-run-edit cycle, fast performance
and expressive features.

By leveraging the efforts put into the Zig compiler, and writing the language in Zig,
I can create a really nice language that avoids some of the pitfalls of Zig and Rust (async war, too low level, long compilation times).

I really like Zig, Elixir and Rust, some features are just better in one or the other:

- Error handling in Zig is better than Rust
- Expressive type system in Rust is better than Zig
- Async features in Elixir is top-notch (BEAM)
- Type system in Rust is great, if only we get rid of lifetimes and possibly generics (comptime?)

To implement this, I will create a transpiler written in Zig that transpiles to Zig. This will take advantage
of Zig and the Zig ecosystem (easy access to C-libraries, incremental compilation, easy to build, small footprint).
