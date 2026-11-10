# Comments

Code in this repository carries no comments that explain it. It documents itself through the names of its variables, functions, types and modules. A hook rejects a Swift file that gains a comment.

## What is not allowed

- Line comments (`//`) and block comments (`/* */`) of any kind.
- Documentation comments (`///` and `/** */`).
- `// MARK:`, `// TODO:` and `// FIXME:` lines.
- The header that Xcode puts at the top of a new file.
- Code that has been commented out. Delete it; the history keeps it.

## What to do when a comment seems needed

The wish to write a comment means the code is not yet clear. Change the code.

| The comment would say | Do this instead |
|---|---|
| what a value is | Rename the value. |
| what a block of code does | Move the block into a function named for what it does. |
| what a condition means | Give the condition a name: a well-named constant, a computed property or a method on the object it asks about. |
| what a number or a string stands for | Make it a named constant. |
| which values a parameter accepts | Give the parameter a type that allows only those values. |
| why the code does something unusual | Put the reason in the name: `waitUntilTheSystemHasStoredTheWallpaper()`. Put the story behind it in the commit message. |
| how a type or function is meant to be used | Shape its interface so it can only be used that way. Let a test with a descriptive name show the behaviour. |
| that work is left to do | Finish the work, or record it outside the code. |

## The only exceptions

Lines that a tool reads and that are not there to explain code:

- `// swift-tools-version:` at the top of `Package.swift`;
- directives for a linter, formatter or code generator: `// swiftlint:…`, `// swiftformat:…`, `// sourcery:…`.

## Scope

The rule covers all Swift code, tests included, and the scripts in `.claude/hooks`.
