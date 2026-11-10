# Architecture

The app is built from five layers. Each layer is one Swift module, and the module lives in a directory that has exactly the layer's name: `Domain`, `Application`, `Infrastructure`, `Presentation`, `Features`. A file belongs to the layer whose directory it is in. The app target, the one that holds `@main`, is the composition root and belongs to no layer.

## What each layer may know

"Know" means "import". A layer that may not know another layer never imports it and never names one of its types. A hook checks the imports of every Swift file before it is written.

| Layer | May import | Must never import |
|---|---|---|
| `Domain` | The Swift standard library and Foundation. Nothing else. | Every other layer, every other framework, every third-party package |
| `Application` | `Domain`, Foundation | `Infrastructure`, `Presentation`, `Features`, every other framework or package |
| `Infrastructure` | `Domain`; from `Application` only ports and the errors defined for them; any framework or package | `Presentation`, `Features`; use cases |
| `Presentation` | `Domain`, UI frameworks | `Application`, `Infrastructure`, `Features` |
| `Features` | `Application`, `Domain`, `Presentation`, UI frameworks | `Infrastructure` |
| Composition root | Everything | – |

Test targets live in directories whose name ends in `Tests`. They may also import the test framework and the module they test.

## Domain

The heart of the software. It represents the concepts of the business, the business situation and the business rules.

- Holds entities, value objects, aggregates, domain services and domain errors.
- State that reflects the business situation is controlled and used here. How it is stored is delegated to Infrastructure.
- It is pure. The test: copy the whole `Domain` directory into another Swift app, and it compiles and works unchanged.
- It does no input or output. It never reads the clock, the locale, the file system or a random source by itself; the caller passes such values in.
- It carries no persistence annotations, no UI types and no framework types.

## Application

Defines the jobs the software does and directs domain objects to do them.

- **Use cases.** One use case is one job a user or the system wants done. It is a coordinator: it gets domain objects through ports, asks them to do the work, and hands the results back through ports. It decides nothing about the business.
- **Ports.** Thin protocols that say what the application needs from the outside world. A port is named for that need, not for a technology, and speaks only in Domain types and standard types. Each port defines the errors its implementations may throw.
- It holds no business rule and no state that reflects the business situation. It may hold state that reflects the progress of a task for the user, such as how far an import has come.
- If a use case contains an `if` about the business, that decision belongs in a domain object.

## Infrastructure

Adapters. It gives the layers above their technical capabilities: storing the domain's state, reading files, decoding pictures and videos, talking to the operating system and to services.

- Every adapter implements a port defined by Application. A capability nobody asked for through a port does not exist.
- An adapter translates: framework types to Domain types, and framework errors to the errors the port defines.
- Framework types and framework errors never leave this layer.
- It may also supply the technical framework that supports how the layers work together, such as the delivery of messages between them.
- It holds no business rule, starts no use case and coordinates no job.

## Presentation

Shows information to the user and interprets the user's commands.

- Holds views, controls, styles and the formatting of values for display. Its parts can be reused by any feature.
- A view gets what it shows as parameters and reports what the user did through closures or bindings.
- It knows no use case, does no input or output and holds no business rule.

## Features

Implements what the product requires of the user interface, one feature per directory: `Features/<FeatureName>/`.

- A feature builds its screens from Presentation parts, holds the state of those screens and calls Application use cases.
- State flows one way. The view reads state and sends actions. The feature's model receives an action, changes state and calls use cases. A view never calls a use case directly.
- A feature gets its use cases from outside, through its initialiser or a dependency container. It never creates an adapter.
- A feature holds no business rule. When it must decide something about the business, it asks a use case.
- A feature never reaches into another feature. Movement between features is wired by the composition root.
- A feature's model can be tested without a screen: send it actions with stand-in use cases and check the state.

## Composition root

The only place that knows every layer. It creates the adapters, hands them to the use cases as ports, hands the use cases to the features, and builds the navigation between features. It holds no logic of its own.

## Where does new code go?

| The code | Goes in |
|---|---|
| decides or guards something about the business | `Domain` |
| lists the steps of one job | `Application`, as a use case |
| needs something from the outside world | `Application`, as a port, with an adapter in `Infrastructure` |
| calls a framework, the system, a file or a service | `Infrastructure` |
| draws something any screen could use | `Presentation` |
| is one screen and its state | `Features` |
| creates objects and connects them | the composition root |
