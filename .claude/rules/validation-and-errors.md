# Validation and error handling

Each layer validates by answering one question, and each layer has its own errors. A check is written once, in the layer whose question it answers.

## Who checks what

| Layer | The question it answers | Example |
|---|---|---|
| `Domain` | Could this state ever be valid? | A wallpaper never holds more than eight pictures. A slot never holds two pictures. |
| `Application` | Is this allowed or possible now, given the current state and context? | A wallpaper with this name already exists. The file the user chose can no longer be read. |
| `Infrastructure` | None. It reports what the outside world did. | The disk is full. The file is not a picture. |
| `Features` and `Presentation` | None. They show the result. | – |

A feature may check input early so the user gets an immediate answer, but that check never replaces the one in Domain or Application.

## Domain

- Domain throws domain-specific errors: types defined in `Domain` and named in the product's vocabulary, such as `WallpaperError.tooManyPictures(limit: 8)`.
- A domain error says which rule was broken and carries the values needed to explain it.
- Domain throws only its own errors. Never a generic error, a bare string or a framework error.
- Domain validates in initialisers and in state-changing methods, so no caller can skip the check.
- Domain rules never depend on context such as what is stored, who is asking or what the system can do right now.

## Application

- A use case acts on every domain error it can receive. It takes one of three decisions, on purpose: recover from it, map it to an application error that means more to the caller of the use case, or pass it on unchanged. It never ignores it.
- Application defines its own errors for the checks that depend on state and context.
- Application defines the errors that ports may throw. Each port names its error type, and that type lists the failures the application can understand and act on: not found, not permitted, no space left, unreadable, unavailable. One further case covers anything unexpected and keeps a description of the cause for diagnosis.
- A use case states the errors it can fail with, so a feature can handle every one of them.

## Infrastructure

- An adapter catches every framework and system error at its boundary and maps it to the error type its port defines.
- No framework error and no `NSError` ever crosses into Application.
- A failure the adapter does not recognise is mapped to the port's unexpected case. It is never dropped and never passed on raw.
- An adapter throws only what its port allows. It defines no error that Application has not defined.
- An adapter validates no business rule.

## Features

- A feature turns each error of a use case into a state the user can see and act on.
- It handles every case the use case states. It does not collapse them into one message when the user could do something different about each.
- It never shows the raw text of an error.

## The path of a failure

```
framework error
  → adapter maps it to the port's error        (Infrastructure)
  → use case recovers, maps or passes it on    (Application)
  → feature turns it into a state on screen    (Features)

broken business rule
  → domain object throws a domain error        (Domain)
  → use case recovers, maps or passes it on    (Application)
  → feature turns it into a state on screen    (Features)
```
