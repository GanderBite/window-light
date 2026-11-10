# Structuring a window

Sources (Apple Human Interface Guidelines, read 2026-11-10): designing-for-macos, windows, sidebars, split-views, toolbars, search-fields, lists-and-tables, settings, going-full-screen, launching, layout. All under https://developer.apple.com/design/human-interface-guidelines/

## Contents

1. Start from the Mac
2. Windows
3. Choosing a navigation structure
4. Sidebars
5. Split views and inspectors
6. Toolbars
7. Search
8. Lists and tables
9. The settings window
10. Full screen
11. Launch and coming back

## 1. Start from the Mac

What is true of the device decides the structure.

- **Display.** Large and high resolution, often with more displays attached. Show more at once, in fewer nested levels and with fewer modal steps, at a density that is still comfortable to read.
- **Ergonomics.** People sit at a desk. On a Mac with a touch display they reach forward to touch, so touch is for brief, deliberate actions and not for sustained work.
- **Input.** Mainly keyboard and pointing device, plus trackpad gestures, touch on some Macs, voice and game controllers.
- **Sessions.** From a quick task of a few minutes to hours of concentration, usually with several apps open. Switching between active and inactive must be smooth.
- **System features people expect to find:** the menu bar, file management, full-screen mode and Dock menus.

## 2. Windows

An app has two kinds of window.

- A **primary** window holds the main navigation and content.
- An **auxiliary** window holds one task or one area. It offers no navigation to other parts of the app and usually has a button that closes it when the task is done.

Rules:

- **Let the window be any size.** People resize to fit their work. Lay content out so it adapts fluidly, set a sensible minimum, and never resize a window from code.
- **Open a new window for a reason.** A new window is right when it lets people keep their context or do two things side by side, the way a mail app opens a new message. Opening windows by default creates clutter.
- **Offer "open in a new window" as a choice** in a context menu or the File menu when viewing something separately is useful.
- **Never draw your own window frame or window controls.** An imitation that is not perfect in every state makes the app feel broken.
- **Keep the bottom edge free of anything critical.** People often push a window's bottom edge off the screen. If a bottom bar is needed, limit it to a little information about the window's contents or selection, like a count of items. More than that belongs in an inspector.
- **Keep content out from behind the camera housing** at the top of some displays. The system's full-screen mode handles this.
- **Call it a window** in anything a person reads.

### Window states

| State | Meaning |
|---|---|
| Main | The app's frontmost window. One per app. |
| Key | The window that receives input. One on screen at a time. Usually the main window, but a floating panel can be key instead. |
| Inactive | Any window not in the foreground. |

The system draws these differently: the key window shows colored title bar buttons, and inactive windows drop vibrancy, the effect that pulls color into a window from what is beneath it, so they look subdued and farther away. People use that difference to know where their typing will go. Standard components follow it automatically. A custom background or control has to change with the window's state too.

## 3. Choosing a navigation structure

| The app has | Use |
|---|---|
| One kind of content and no areas to switch between | A single window with a toolbar. No sidebar. |
| Several top-level areas or collections | A sidebar and a detail area (`NavigationSplitView`). |
| A hierarchy deeper than two levels | Three panes: sidebar, content list, detail. |
| Details or settings of the selected item, shown while working | An inspector on the trailing side (`inspector(isPresented:content:)`). |
| A short, bounded task tied to the window | A sheet. See `presenting-and-feedback.md`. |
| A self-contained task that people do alongside the main window | An auxiliary window. |
| Controls that people adjust repeatedly while watching the result | A panel. See `presenting-and-feedback.md`. |

Under Liquid Glass, navigation must be visibly separate from content: sidebars and toolbars float in the functional layer and content sits beneath. Do not blend navigation into the content area.

When space changes, keep the same functions and change only how much is visible. Never remove a feature because the window is small.

## 4. Sidebars

A sidebar sits on the leading side and lets people move between areas or top-level collections. It needs a good deal of space in both directions.

- Show at most two levels of hierarchy. Deeper content gets a list pane between the sidebar and the detail.
- With two levels, give each group a short, descriptive title.
- Use disclosure controls to collapse groups when there is a lot of content.
- Use SF Symbols for items. For a custom icon, make a custom symbol, not a bitmap.
- Sidebar icons take the app accent color, and on the Mac they take whatever accent color the person chose in system settings. Leave that alone. Use a fixed color only where the color itself carries meaning, and rarely.
- Let people hide and show it: a toolbar button plus Show Sidebar and Hide Sidebar in the View menu. Do not hide it by default.
- Consider hiding it automatically when the window gets narrow and bringing it back when there is room.
- Let people customize what it lists when that makes sense.
- Its row height, text and icon size follow a size people can change in system settings.
- Nothing critical at the bottom of a sidebar, for the same reason as the bottom of a window.
- Let rich content extend beneath it. See `liquid-glass.md`, section 7.

## 5. Split views and inspectors

- Keep the current selection highlighted in every pane that leads to the detail. It shows people the path they took.
- Use the system split view (`NavigationSplitView`, `NSSplitViewController`). It reflows panes smoothly at every window size.
- Give panes sensible minimum and maximum sizes, so a divider can never seem to vanish.
- Let people hide a pane when they want room, and give more than one way to bring it back: a toolbar button and a menu command with a shortcut.
- Prefer the thin divider.
- Consider drag and drop between panes.
- An **inspector** shows details of the current selection and updates as the selection changes. Put it on the trailing side of a split view, or in a panel. An Info window that keeps showing one item is an ordinary window, not an inspector.

## 6. Toolbars

A toolbar gives quick access to frequent commands, navigation and search. It holds three kinds of thing: the title, navigation controls and search, and actions.

**Placement**

| Area | Holds | Notes |
|---|---|---|
| Leading edge | Back, show or hide sidebar, then the title, then an optional document menu | Not customizable, so these are always there. |
| Center | Common, useful controls | People can customize this part. Items collapse into the system's overflow menu as the window narrows. |
| Trailing edge | Items that must stay available, inspector buttons, optional search, a More menu, the primary action | Stays visible at every window size. |

**Choosing items**

- Include only commands people use often. Each item must be easy to tell apart and to hit.
- Every toolbar item must also be a menu bar command, because people can hide or customize the toolbar. The reverse is not true: most menu commands do not deserve a toolbar item.
- The system adds an overflow menu when items do not fit. Never add one yourself, and do not design a layout that overflows at the default size.
- Add a More menu only when really needed, for the less important actions.
- Consider making the toolbar customizable when the app has many commands or is used for long sessions.

**Grouping**

- Group by function and by how often things are used. Aim for three groups at most.
- Put navigation and critical actions such as Done, Close or Save in their own familiar, distinct groups.
- Keep text-labeled actions apart from symbol actions and from each other, with fixed space between. Side by side they read as one control.

**Items**

- Prefer simple, recognizable symbols to text. Use text where no symbol says it well, such as Edit.
- Use symbols without a border or enclosing circle. The group already supplies the container, and the system draws hover and selection states.
- Use the standard Back and Close symbols, without text labels.
- Give the key action, such as Done or Submit, the prominent style. Only one, on the trailing side.
- On the Mac the title can sit in line with the controls, and toolbar items have no bezel.

**Titles**

- Give each window a title that says what it shows. It helps people tell windows apart.
- Never use the app's name as a window title.
- Keep it under about 15 characters.
- If a title would only repeat what the content already says, leave it empty.

**Appearance**

- No custom toolbar background and no tinted items. Let content color the bar through the glass, and use the scroll edge effect where separation is needed.
- If the content is bright and colorful, keep the toolbar's default monochrome look.
- Hiding the toolbar for a distraction-free view is fine when it suits the moment, with a reliable way to get it back.

## 7. Search

- **Trailing side of the toolbar** is the usual place. It suits split views, where search runs across columns and results can be browsed while the selection stays visible.
- **Top of the sidebar** when the search filters the sidebar or navigation itself.
- **Its own sidebar item** when search is an area for discovery with suggestions and categories. Focus the field as soon as people arrive there.
- Use placeholder text to say what can be searched.
- Start searching as people type when possible.
- Consider showing recent searches and suggestions.
- Put the most relevant results first and consider grouping them.
- Use a scope bar to narrow among clearly defined categories, and default to the broader scope.

## 8. Lists and tables

- Lists and tables are best for text. For many pictures or items of very different sizes, use a collection or grid.
- Keep row text short. If items carry a lot of text, show titles and put the rest in a detail view.
- In a narrow column, truncating in the middle can keep an item recognizable.
- A list used for navigation keeps the selected row highlighted. A list of options highlights briefly and then shows a checkmark.
- Let people reorder when order matters to them.
- On the Mac: let people click a column heading to sort and click again to reverse, let them resize columns, consider alternating row colors in wide multicolumn tables, and use an outline view for hierarchical data.
- Column headings are nouns or short noun phrases in title-style capitalization, with no ending punctuation.
- In a form, use the system's grouped form style so spacing and metrics follow the platform.

## 9. The settings window

- Open it from the Settings item in the app menu, with Command-Comma. Never put a settings button in a window's toolbar.
- Offer few settings, and choose defaults that suit most people so nothing has to be changed before the app is useful.
- Never duplicate a system setting such as appearance or accessibility options. Follow the system's.
- Do not use settings to ask for something the app can detect.
- Options that affect one task belong in that task's own view, not in the settings window.
- With several panes: a toolbar that cannot be customized, stays visible and always shows the active pane.
- The window title is the name of the visible pane. With a single pane, the title is the app's name followed by Settings.
- Dim the minimize and zoom buttons.
- Reopen on the pane people used last.
- Document-level options go in the File menu instead.

## 10. Full screen

- Support it when the app shows media or an absorbing task that benefits from no distractions.
- Use the system's full-screen mode. People enter with the window's button, the View menu or Control-Command-F. Never enter or leave it on the app's own initiative, and do not offer a custom menu of window modes.
- Adjust proportions if needed, subtly. Do not change which things are shown.
- Keep the controls a task needs reachable without leaving full screen.
- Keep the Dock reachable.
- Toolbars and navigation may hide while content has the focus, as long as moving the pointer to the top of the screen brings them back.
- When people switch away and return, they find things as they left them.

## 11. Launch and coming back

- Launch fast and show something at once. The Mac needs no launch screen.
- Restore the previous state: the same windows in the same places and sizes, scrolled to where they were.
- No alert at launch. If something is wrong at startup, show it quietly in the window.
- Onboarding, when needed, comes after launch and is covered in `presenting-and-feedback.md`.
