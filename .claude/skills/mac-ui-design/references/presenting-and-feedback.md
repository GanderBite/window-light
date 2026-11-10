# Presenting things and giving feedback

Sources (Apple Human Interface Guidelines, read 2026-11-10): sheets, alerts, popovers, panels, feedback, loading, onboarding, launching, privacy. All under https://developer.apple.com/design/human-interface-guidelines/

## Contents

1. Choosing how to present something
2. Sheets
3. Alerts
4. Popovers
5. Panels
6. Feedback
7. Loading and progress
8. Empty states and errors
9. Onboarding
10. Asking for permission

## 1. Choosing how to present something

Match the weight of the presentation to the weight of the message. The more something interrupts, the more it has to be worth.

| The situation | Use | Interrupts |
|---|---|---|
| Status that people may want to glance at | Text or a symbol in the window, next to what it describes | No |
| What a control does | A tooltip | No |
| A little information or a few related choices about one element | A popover | Slightly |
| Details of the selection, shown while working | An inspector pane or panel | No |
| Controls people adjust again and again while watching the result | A panel | No |
| A short, bounded task tied to one window | A sheet | That window only |
| A longer, self-contained task | A separate window, or full-screen mode | No |
| Something critical that needs a decision now | An alert | Yes |

A large display is a reason to use fewer modal steps. Ask first whether the thing can simply be in the window.

## 2. Sheets

A sheet is for a scoped task closely related to the current context: supplying the information an action needs, choosing a file, confirming a set of options.

On the Mac a sheet is always modal to its window. It is a card with rounded corners that floats over the parent window, and the parent is dimmed.

- **One sheet at a time.** If something inside a sheet needs another sheet, close the first and reopen it afterwards if necessary. Closing a sheet must return people to the window.
- **Other windows of the app stay usable** while a sheet is open. Only the parent is blocked.
- **Give it a good default size.** People do not expect to resize a sheet, though allowing it helps when the content benefits from more room.
- **Buttons.** Cancel dismisses without saving. Done dismisses after completing or saving. Back moves to the previous step and does not dismiss. Always pair Done with Cancel or with Back, so finishing the task is never the only way out. Never show all three.
- **Not for long or complex work.** Use a separate window, or full-screen mode for media.
- **Not for repeated input.** If people provide input and observe results over and over, as with find and replace, use a panel.

Under Liquid Glass, sheets have rounder corners and draw their own background. Keep content clear of the corners and add no background of your own.

## 3. Alerts

An alert delivers critical information that people need right away. It stops everything, so each one must earn that.

**When not to use one**

- To inform without offering an action. Put the information in the window, where it applies.
- For a common action that can be undone, even a destructive one. Deleting an item needs no alert when undo exists.
- At launch. Show the problem quietly in the window instead.
- When data loss is the expected result of what the person just chose.

**When to use one**

- An uncommon destructive action that cannot be undone.
- A problem that needs a decision before anything can continue.
- A confirmation of something significant that the person started.

**Content**

- Title, optional informative text, and up to three buttons. A Mac alert can also carry a suppression checkbox for alerts that repeat, an accessory view and a Help button. The system shows the app icon.
- The **title** says what happened and why, specifically and briefly: at most two lines. Never "Error" or an error number.
- Add **informative text** only when it adds something. Keep it short, in complete sentences.
- Direct, neutral, approachable tone. Do not blame, hint or soften a serious problem.
- If the buttons are clear, do not explain them.
- Use the caution symbol rarely, only when unexpected data loss is at stake. Not for saving or emptying the trash.
- A text field only when input is needed to resolve the situation, such as a password.

**Buttons**

- One or two words that say what the button does, as verbs tied to the alert's text: Erase, Convert, Delete, View All.
- Avoid OK except in an alert that only informs. Avoid Yes and No.
- The button that cancels is always titled Cancel.
- The default button is on the trailing side of a row or the top of a stack. Cancel is on the leading side or at the bottom.
- The default button responds to Return, so never make a destructive button the default.
- Use the destructive style for a destructive action the person did **not** deliberately choose. When they chose it themselves, such as Empty Trash, the confirming button is not styled destructive.
- Any destructive action comes with a Cancel button. Cancel is never the default button.
- To make people actually read an alert, give it no default button.
- Esc and Command-Period cancel.

## 4. Popovers

A popover is a transient view that appears next to the control or area that opened it.

- For a small amount of information or a few related controls. It closes when people click outside it or choose something in it.
- Its arrow points at what opened it, and it does not cover that element or anything people need to see while using it.
- One popover at a time. Never a popover out of a popover. Nothing appears over a popover except an alert.
- Let people close one and open another with a single click.
- Only as big as its content. Animate a change of size.
- A Close, Cancel or Done button only when it adds clarity, such as leaving with or without saving.
- Work is saved when a popover closes by itself. Discard only on an explicit Cancel.
- Never for a warning. People can miss it or dismiss it by accident.
- On the Mac a popover can be made detachable, becoming a panel when dragged away. Keep its look nearly the same when detached.
- Do not write the word "popover" in help text. Refer to the task or the control.

## 5. Panels

A panel is a Mac window that floats above the others and holds supplementary controls, options or information for the active window or current selection.

- Use it for quick access to controls or information about what the person is working on, and for inspectors.
- Prefer simple adjustment controls such as sliders and steppers. Avoid typing and multi-step selection in a panel.
- A short noun title in title-style capitalization: Inspector, Colors.
- When the app becomes active, all its panels come forward. When it is inactive, they hide.
- Commands to show or hide a panel may be in the Window menu, titled by the panel's name: Show Inspector. Panels are not listed among the windows.
- Usually no minimize button.

**HUD-style panels** are dark and translucent. Prefer the standard panel. A HUD fits only a media-oriented app, a case where a standard panel would hide essential content, or a panel that needs almost no controls. Keep it small and use color sparingly.

## 6. Feedback

Feedback tells people what is happening, what they can do next, what an action did, and how to avoid a mistake.

- Put status next to the thing it describes, so people can see it without acting.
- Reserve interruption for what is critical and can be acted on.
- People expect an action to succeed. Confirm success only for something significant. Always show failure, with the reason.
- Warn before an action that causes loss which is unexpected and cannot be undone. Do not warn when loss is what the person asked for.
- When a command cannot be carried out, say so and say why.
- Give feedback in more than one form. Color, text, a symbol and sound together reach people who would miss one of them.
- Never close or dismiss something on a timer when it holds information people need. Some people need longer to read.

## 7. Loading and progress

- Show something immediately. An empty window looks like a fault. Use placeholders and replace them as content arrives.
- Let people keep doing other things while content loads.
- Say that loading is happening and, if possible, for how long. A determinate progress indicator when the length is known, an indeterminate one when it is not.
- Let people cancel long work.
- The best loading experience is one nobody notices.

## 8. Empty states and errors

**Empty states.** A view with nothing in it yet is a chance to welcome people and show them what to do.

- Say what will appear here and give the action that fills it, as a button if possible.
- Keep nothing crucial there. An empty state disappears once there is content.

**Errors.**

- Prevent the error where possible: dim a button until its conditions are met, offer choices in place of free text, check values as people enter them.
- Show the message as close to the problem as possible.
- Say what happened and what to do about it. "Choose a password with at least 8 characters" helps. "That password is too short" does not.
- Do not blame. No "oops". No raw error text or codes.
- If an error affects many people and words cannot fix it, redesign the interaction.

Wording is covered in `writing-interface-text.md`.

## 9. Onboarding

Ideally people understand the app by using it. When an introduction is needed, make it fast and optional.

- It comes after launch and is not part of launching.
- Teach by doing. Let people try the real action safely. Do not show pages of instruction.
- Prefer tips in context, shown near the thing they describe and one at a time, to a single long flow.
- A required flow is brief and asks people to remember little.
- Let people skip a tutorial. Do not show it again at the next launch, and keep it findable in the Help menu or settings.
- Cover the app only, not how to use the Mac.
- Put off setup and customization. Good defaults let people start at once.
- No licensing text in the flow.
- Let people use the app before asking for a rating.

## 10. Asking for permission

- Ask only for what a feature really needs, and only when the person uses that feature.
- Do not ask at launch unless the app cannot work at all without the access and the reason is obvious.
- The system shows the request. The app supplies one sentence saying why. See `writing-interface-text.md`.
- If a screen of the app's own comes before the system request, it has a single button titled Continue or Next that opens the system request. It has no way out that skips the request, and its button is never titled Allow.
- Do the work on the device where possible.
- An app on the Mac App Store runs in the sandbox, and its privacy details are shown on its store page.
- Do not assume who is signed in to the Mac. Several people may be, through fast user switching.
