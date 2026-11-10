# System design

Three rules shape every type and module: domain objects are rich, modules are deep, and errors are handled gracefully.

## Rich domain objects

A domain object owns its data together with the behaviour that keeps that data valid. An object that only carries data, with its rules written somewhere else, is anemic and is not allowed.

- An invalid instance cannot exist. The initialiser and every method that changes state enforce the object's rules.
- State changes through methods named for what the business does: `wallpaper.place(picture, in: slot)`, never `wallpaper.slots[3] = picture`.
- Stored properties are not publicly settable when a rule applies to them.
- A question about an object is answered by the object: `wallpaper.isReadyToApply`, not a helper that inspects its fields.
- A concept that has rules gets its own type. A slot is a `Slot`, not an `Int`. A capture time is not a bare `Date`.
- Names come from the product's vocabulary in `docs/features`.

Signs of an anemic design, each to be fixed by moving the behaviour into the object:

- a type made of stored properties and nothing else, next to a `Manager`, `Helper`, `Util` or `Service` that holds its logic;
- the same check on an object's fields written in more than one place;
- a caller that must read several properties and combine them to learn one fact.

## Deep modules

A module is a type, a service or a layer boundary. Its interface is what a caller must know to use it. A deep module hides a lot of work behind a small, simple interface. A shallow module has an interface nearly as complicated as what it does, so it hides nothing.

Every service gives its callers an interface that is easy to use and keeps the complicated business logic behind it.

- The caller says what it wants, not how to do it. One call does one whole job.
- It is better for a module to be harder to write than harder to use. When something difficult has to be handled, the module handles it and does not push it onto every caller.
- Each design decision is known in one place. If changing a file format, an algorithm or an order of steps would touch two modules, the knowledge has leaked.
- A module decides what it can decide by itself and does not ask for it as a parameter.
- An interface that is somewhat general is simpler and lasts longer than one shaped around a single caller.
- Two layers next to each other offer different abstractions. If a method only passes its arguments on to a method with the same shape, one of the two should not exist.

Signs of a shallow design:

- a method that only forwards to another method;
- methods that must be called in a fixed order for the result to be right;
- a caller that needs to know how the module works inside to use it correctly;
- an interface whose methods repeat the steps of the implementation one by one;
- internal collections or framework types handed out to callers.

## Graceful error handling

A failure never crashes the app, never disappears and never leaves data half changed.

- The app does not crash on something that can happen while it runs. No `try!`. No force-unwrapping of a value that can be missing at run time. No `fatalError` or `precondition` for a condition a user, a file or the system can cause.
- No failure is swallowed. No empty `catch`. No `try?` that hides a failure the user or the caller needs to know about.
- An error is handled at the point that knows enough to recover from it. Any other point passes it on unchanged or maps it, as the rule on validation and errors says.
- Every failure that reaches the user becomes a clear state on screen: what happened, in the user's words, and what they can do next.
- An operation that fails leaves things as they were before it started.
- Where an interface can make a failure impossible, design it that way. Removing a picture that is not there is a result, not an error.

A hook rejects `try!` and empty `catch` blocks outside tests.
