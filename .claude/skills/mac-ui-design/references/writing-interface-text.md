# Writing interface text

Sources (Apple Human Interface Guidelines, read 2026-11-10): writing, alerts, menus, buttons, toolbars, settings, privacy, inclusion, windows, panels, lists-and-tables. All under https://developer.apple.com/design/human-interface-guidelines/

## Contents

1. Voice and clarity
2. Capitalization and punctuation
3. Buttons and menu items
4. Titles
5. Alerts
6. Errors
7. Empty states
8. Settings
9. Multi-step flows
10. Permission requests
11. Words for the Mac
12. Before and after

## 1. Voice and clarity

The words are part of the design. A screen with the right controls and the wrong words still fails.

- **Decide on a voice and keep a word list.** Choose the terms for the app's main things and actions, write them down, and use the same word for the same thing everywhere. If the project has a glossary, use it.
- **Fit the tone to the moment.** The voice stays the same. The tone changes: plain and direct for an error, lighter for a success.
- **Be clear.** Familiar words. Check that every word is needed. Read it aloud.
- **Put the most important thing first**, in a sentence and on a screen.
- **Write for everyone.** No jargon, no idioms, no gendered wording. Text is also read aloud by VoiceOver and translated into other languages.
- **Use the active voice and say what to do.** "Choose a picture", not "A picture must be chosen".
- **Use possessives sparingly.** "Favorites" says as much as "Your Favorites". If "your" is used, use it consistently.
- **Avoid "we".** It is unclear who is speaking. "Unable to load content", not "We're having trouble loading this content".
- **Address the person as "you".** Never "the user".

## 2. Capitalization and punctuation

Two styles are used, each in fixed places.

- **Title-style** capitalizes every word except articles, coordinating conjunctions and short prepositions, and always capitalizes the last word: Add to Library, Show in Finder.
- **Sentence-style** capitalizes the first word and proper nouns only.

| Element | Style | Ending punctuation |
|---|---|---|
| Menu titles and menu items | Title | None. An ellipsis when more input is needed |
| Button titles, including alert buttons | Title | None. An ellipsis when it opens another view |
| Panel titles | Title | None |
| Column headings | Title | None |
| List and form section headers | Title | None |
| Alert title that is a complete sentence | Sentence | Yes |
| Alert title that is a fragment | Title | None |
| Alert informative text | Sentence, in complete sentences | Yes |
| Permission purpose text | Sentence, one complete sentence | A period |
| Body text, descriptions, help | Sentence | Yes |

For anything not listed, choose one style for that kind of element and use it everywhere.

**The ellipsis (…)** means "this needs more from you before it happens". Use it on a menu item or button whose action opens a view for more input or more choices: Export As…, Rename…. Do not use it when the action happens immediately. Use the single ellipsis character.

## 3. Buttons and menu items

- Start with a verb that names the action: Add, Apply, Duplicate, Remove.
- A few words at most. In an alert, one or two.
- Say what will happen, not how the person might feel. Send, not Let's Do It.
- No articles: View Settings, not View the Settings.
- A link says where it leads. Never "Click here".
- The button that cancels is titled Cancel. Use Done to finish a task and Back to return to the previous step.
- Avoid OK except where the message only informs. Avoid Yes and No. Name the action.
- An item that toggles states what choosing it will do now: Show Sidebar, then Hide Sidebar. If that could be read as a state, add a verb: Turn HDR On.
- Refer to a button in text by its exact title, without quotation marks.
- A tooltip is a short phrase saying what the control does.

## 4. Titles

- A window title says what the window shows. Never the app's name. Under about 15 characters.
- A settings window is titled with the name of the visible pane, or with the app's name followed by Settings when it has only one.
- A panel title is a noun or noun phrase: Inspector, Colors.
- Menu titles are one word where possible.
- The app's short name in menus is 16 characters or fewer, without a version number.
- Sidebar group titles are short and descriptive, with unnecessary words removed.

## 5. Alerts

- The title says what happened and, where it helps, why. Complete and specific, at most two lines.
- Never a title like "Error" or one that carries an error number.
- Informative text only when it adds something the title does not. Keep it short.
- Direct, neutral, approachable. Do not accuse, do not be vague, and do not make a serious problem sound small.
- Buttons are verbs that connect to the title: Erase, Convert, Delete.
- If the buttons are clear, do not explain them. If guidance is unavoidable, say "choose", which fits every way of interacting.

## 6. Errors

- Say what the person can do, not what they did wrong. "Use only letters for your name", not "Don't use numbers or symbols".
- Be specific. "Choose a password with at least 8 characters", not "That password is too short". Never "Invalid name".
- No blame, and no "oops" or "uh-oh". They sound insincere.
- Put the message next to the field or thing it is about.
- Never show raw error text, codes or internal names.
- When something cannot be done, say that and say why.

## 7. Empty states

- Say what will be here and how to put it here, with a button for the action if possible.
- It is a good place for the app's voice, as long as the text is useful.
- Put nothing there that people will need later. It disappears.

## 8. Settings

- Label a setting as practically as possible.
- If the label is not enough, add a line that says what the setting does **when on**. People infer the opposite.
- To send someone to a setting, give a button or link that opens it. Do not describe where it is.

## 9. Multi-step flows

- Choose the words that move people along and keep them: Get Started to begin, Continue or Next between steps, Done at the end. Do not mix Continue and Next in one flow.
- A button can hint at the next step.
- One idea per screen when there are several to convey.
- Label every field. Show an example or a description as placeholder text, such as name@example.com.

## 10. Permission requests

The system shows the request. The app supplies one sentence, shown after the app's name, saying why it needs the access.

- One complete sentence in sentence-style capitalization, active voice, ending with a period.
- Say what the app does with the access and why.

| Verdict | Example |
|---|---|
| Good | The app records during the night to detect snoring sounds. |
| Vague | Microphone access is needed for a better experience. |
| No reason given | Turn on microphone access. |

## 11. Words for the Mac

- People **click** on a Mac. They do not tap, except on a touch display. Use **choose** for menu items, and wherever the wording must fit every way of interacting.
- Say **window**, never scene or view.
- Say **Settings**, opened with Command-Comma.
- Refer to a panel by its title: Show Inspector, the Colors window. Do not say "panel".
- Do not say "popover" in text people read. Refer to the control or the task.
- The menu item is **Delete**, not Erase or Clear.
- Prefer **Duplicate** to Save As.
- Write shortcuts with modifiers in this order: Control, Option, Shift, Command.
- Apple's trademarks do not appear in the app's name or images.

## 12. Before and after

| Before | After | Why |
|---|---|---|
| Error: import failed (code 12) | "Beach.mov" couldn't be opened because it isn't a video the app can read. | Says what happened to which thing, and why. No code. |
| Are you sure? [Yes] [No] | Delete "Summer"? This can't be undone. [Cancel] [Delete] | The title names the action, and the buttons are verbs. |
| Click here to learn more | Learn more about schedules | The link says where it leads. |
| Your Wallpapers | Wallpapers | The possessive adds nothing. |
| We couldn't apply your wallpaper | The wallpaper couldn't be applied to "Built-in Display". | No "we". Names the thing affected. |
| Enable this to allow the filling of empty slots | Fill empty slots with AI pictures | Says what the setting does when on. |
| No items | No wallpapers yet. Choose pictures to make your first one. [Choose Pictures…] | Says what belongs here and offers the action. |
