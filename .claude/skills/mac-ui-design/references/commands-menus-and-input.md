# Commands, menus and input

Sources (Apple Human Interface Guidelines, read 2026-11-10): the-menu-bar, menus, context-menus, dock-menus, keyboards, pointing-devices, drag-and-drop, undo-and-redo, file-management. All under https://developer.apple.com/design/human-interface-guidelines/

## Contents

1. Where a command lives
2. The menu bar
3. Writing and organizing menu items
4. Context menus
5. The Dock menu and menu bar extras
6. Keyboard
7. Pointer, trackpad and touch
8. Drag and drop
9. Undo and redo
10. Files

## 1. Where a command lives

| Place | What goes there |
|---|---|
| Menu bar | Every command the app has. Always. |
| Toolbar | The few commands used most, as a shortcut. |
| Context menu | The few commands most relevant to the item under the pointer, as a shortcut. |
| Keyboard shortcut | Standard commands, and the app's most frequent ones. |
| Dock menu | A few high-value commands that are useful when the app is not in front. |

The menu bar is the complete list. Everything else is a faster path to something that is already there. A command that exists only in a toolbar, a context menu, a gesture or a shortcut is hidden from people who use the keyboard, people who use assistive technology and people who are still learning the app.

## 2. The menu bar

### Order

App menu, File, Edit, Format, View, app-specific menus, Window, Help. Leave out File if the app handles no files, and Format if it has no formatted text. Keep the rest.

### Rules

- Keep the standard menus, their order and their standard items. The system implements many of them for you.
- **Always show the same items.** A command that cannot be used now is dimmed, not removed. People learn the app by reading its menus.
- Support the standard shortcut for every standard item included.
- Menu titles are one word where possible. Longer titles use title-style capitalization.
- Use the system's icons for common actions such as Copy, Share and Delete.

### App menu

In this order: About (first, in a group of its own), Settings…, optional app-level items, Services, Hide, Hide Others, Show All, Quit. Use a short app name of 16 characters or fewer, the same in About, Hide and Quit, with no version number. Settings… here is for app-level settings only.

### File menu

The usual items, in order: New, Open, Open Recent, Close, Save, Duplicate, Rename…, Move To…, Export As…, Revert To, Page Setup…, Print….

- Name what New creates: New Event, New Wallpaper.
- Open Recent lists names people recognize, most recent first, never file paths, and usually ends with Clear Menu.
- Prefer Duplicate to Save As, Export, Copy To and Save To. Those do not make clear how the new file relates to the original.
- Keep Export As… for formats the app does not normally work in.
- Save automatically as people work, so they do not have to keep choosing Save.

### Edit menu

Undo, Redo, Cut, Copy, Paste, Paste and Match Style, Delete, Select All, then Find, Spelling and Grammar, Substitutions, Transformations and Speech where they apply. The system appends Start Dictation and Emoji & Symbols.

- Useful even in an app without documents, because it serves every text field.
- Name the target of undo and redo: Undo Typing, Redo Move.
- The item is Delete, not Erase or Clear, to match the Delete key.

### View menu

Show or Hide Tab Bar, Show All Tabs, Show or Hide Toolbar, Customize Toolbar, Show or Hide Sidebar, Enter or Exit Full Screen.

- Provide a View menu even if only one of these applies.
- Each Show or Hide title states what choosing it will do now.
- View changes how windows look. It does not switch between windows or manage them.

### App-specific menus

Between View and Window.

- Put every app-specific command in the menu bar, including advanced and rarely used ones.
- Let the menus mirror the app's own hierarchy, the way a mail app has Mailbox and then Message.
- Order them from general or commonly used to specialized.

### Window menu

Minimize, Zoom, tab commands, Bring All to Front, then the list of open windows in alphabetical order.

- Provide it even in a one-window app, with Minimize and Zoom, so keyboard users can reach them.
- It may hold commands that show or hide panels. Panels do not appear in the list of windows.
- It does not close windows (that is File) and does not customize them (that is View). Enter Full Screen appears here only when there is no View menu.
- Zoom never means full screen.

### Help menu

At the trailing end. The app's help first, then a separator and a small number of other items. Help written in the Help Book format gets a search field in the menu automatically.

### Dynamic menu items

An item can change while a modifier key is held, the way Minimize becomes Minimize All with Option.

- Never the only way to do something.
- One modifier key only.
- Keep them to menu bar menus.

## 3. Writing and organizing menu items

**Labels**

- A verb or verb phrase for an action: Close, Select, Duplicate.
- Title-style capitalization.
- No articles: View Settings, not View the Settings.
- An ellipsis (…) when choosing the item needs more input before the action happens, usually in another view.
- Unavailable items are dimmed. A menu whose items are all unavailable still opens.

**Icons**

- Use the standard symbol for a standard action.
- Use icons with purpose, for the most common actions and for things that are naturally visual. If no symbol clearly fits, show none.
- Within one group, all items have icons or none do.

**Organization**

- Important and frequent items first.
- Group related items and separate groups with separators. Keep related commands together even when some are used far less.
- Watch the length. Split a long menu or use a submenu. Menus that people fill themselves, such as history or bookmarks, may be long.

**Submenus**

- Use sparingly: each one hides its items and adds a step.
- A good case is a term repeated in three or more items: Sort By, with Date, Name and Size inside.
- One level deep. More than about five items suggests a menu of its own.
- A submenu stays available even when everything in it is dimmed.
- Never indent items to suggest hierarchy.

**Items that toggle**

- One item whose label changes with the state: Show Map, Hide Map.
- Add a verb when the label could be read as either a state or an action: Turn HDR On.
- Show both items when seeing both helps.
- Use a checkmark for an attribute that is in effect.

## 4. Context menus

Opened with a secondary click or a Control-click, and with touch and hold on a touch display. Hidden by default, so many people never find them.

- Include only the commands most relevant to the item. Not advanced or rare ones.
- Keep it short, in about three groups at most.
- Every item is also available in the menu bar.
- Support context menus everywhere they would be expected, or nowhere. Support in some places only reads as a fault.
- **Hide** what does not apply. This is the opposite of menu bar menus. On the Mac, Cut, Copy and Paste may appear dimmed.
- Most frequently used items nearest to where the menu opens.
- No keyboard shortcuts shown.
- At most one level of submenu.
- Usually no title.

## 5. The Dock menu and menu bar extras

**Dock menu.** Appears on a secondary click of the app's Dock icon.

- Offer a few commands that are valuable when the app is not frontmost or has no window open, plus the open windows.
- Everything in it is also available elsewhere.

**Menu bar extras.** An icon at the trailing end of the menu bar while the app runs.

- People decide whether it is shown, with a setting. The app does not decide for them.
- Clicking it opens a menu, not a popover, unless the function is too complex for a menu.
- Use a symbol that the system can color for light and dark menu bars. The menu bar is 24 pt high.
- Never depend on it being visible. The system hides extras when space is short.

## 6. Keyboard

- **Support Full Keyboard Access.** People must be able to reach and operate every window, menu and control with the keyboard alone. Turn it on in the Accessibility settings and try the whole app.
- **Do not repurpose a standard shortcut.** People press them without thinking. Redefine one only when its usual action has no meaning in the app.
- **Custom shortcuts only for the most frequent app-specific commands.** Too many make an app feel hard to learn.

Shortcuts people already know. Do not use them for anything else:

| Shortcut | Action |
|---|---|
| Command-N, O, S, P, W, Q | New, Open, Save, Print, Close window, Quit |
| Command-Z, Shift-Command-Z | Undo, Redo |
| Command-X, C, V, A | Cut, Copy, Paste, Select All |
| Command-F, G, Shift-Command-G | Find, Find Next, Find Previous |
| Command-B, I, U | Bold, Italic, Underline |
| Command-Comma | Open settings |
| Command-H, Option-Command-H | Hide the app, Hide others |
| Command-M | Minimize |
| Control-Command-F | Enter full screen |
| Command-Question mark | Open the Help menu |
| Command-Grave accent | Next window of the app |
| Command-Tab, Command-Space | Switch apps, Spotlight |
| Esc, Command-Period | Cancel |
| Option-Command-T | Show or hide the toolbar |
| Option-Command-I, Command-I | Show an inspector, Get Info |

**Rules for custom shortcuts**

| Modifier | Use |
|---|---|
| Command | The main modifier. Prefer it. |
| Shift | A second modifier for a variant of a related command. |
| Option | Sparingly, for less common commands and power features. |
| Control | Avoid. The system uses it widely. |

- List modifiers in this order: Control, Option, Shift, Command.
- Do not create a shortcut by adding a modifier to the shortcut of an unrelated command. Shift-Command-Z belongs to Redo because Command-Z is Undo.
- For the upper character of a two-character key, name the character and do not add Shift: Command-Question mark.
- Beyond Command, prefer letters. Some keyboards need modifier keys to type certain characters.
- Let the system localize and mirror shortcuts.
- Use modifiers the way people expect: Option while dragging copies, Command while dragging moves items as a group, Shift while resizing keeps the proportions, and holding an arrow key moves the selection by the smallest unit the app defines.

## 7. Pointer, trackpad and touch

- Standard gestures do what they do everywhere: primary click selects or activates, secondary click opens a context menu, scrolling moves content within its view, a two-finger pinch zooms, two fingers moving in a circle rotate, a swipe moves between pages, a force click shows Quick Look or a lookup.
- Never redefine a systemwide gesture. People can also remap them.
- The same action gives the same result whether done by pointer, keyboard, gesture or touch.
- Use the standard pointer shapes to say what will happen: the arrow, the pointing hand over a link, the I-beam over text, the open and closed hand for content that can be moved, the resize pointers at edges and dividers, and during a drag the copy, link, disappearing item and not-allowed pointers.
- The system shows a tooltip when the pointer rests on a control. Write a short phrase that says what the control does.

**Controls that appear on hover.** Some Macs have a touch display, and touch cannot hover.

- Decide which hidden controls are essential. Only those need a touch equivalent. Tooltips and anything touch can already do need none.
- Reveal a hidden control when its general area is tapped. That first tap reveals only. A second tap on the control acts.
- Keep the current selection when revealing.
- Hide the control again when the person finishes, or after a few seconds.
- Put essential hidden controls in the context menu too.
- Do not leave hover controls permanently visible just to suit touch.
- For touch, enlarge the area that responds or let the control expand when touched. Keep its size and density as they are for the pointer.

## 8. Drag and drop

People try it everywhere, so support it wherever content could reasonably be dragged or dropped.

- **Always give another way** to do the same thing, such as a menu command.
- **Move or copy.** Within one container a drag moves. Between containers it copies. Between apps it always copies. Holding Option at the moment of the drop turns a move into a copy.
- Support dragging several items at once, and show a badge with the count.
- Let people undo a drop.
- Show a translucent drag image once the drag has moved about three points.
- Highlight a destination only while the content is over it and only if it can accept the content. Mark one destination at a time.
- When a drop fails or lands somewhere invalid, show it: the item returns to where it came from, or scales up and fades.
- Scroll a destination automatically when the drag nears its edge.
- Accept the richest form of the content the app can use, and offer several forms when the app is the source.
- Show progress when a drop takes time, and a placeholder where the content will appear.
- After a drop, the content is selected in the destination.
- On the Mac: let people drag content out to the Finder in a format the app can open again, let them drag from an inactive window without first bringing it forward, and let them select and drag in one motion.

## 9. Undo and redo

- Undo and Redo are at the top of the Edit menu, with Command-Z and Shift-Command-Z.
- Name what will be undone in the menu item.
- Show the result. If the undone change is off screen, scroll to it. Otherwise people undo again and again.
- Allow many steps. People expect to go back to when they opened the document or last saved.
- No dedicated undo buttons unless truly needed. If they are, use the standard symbols and put them in the toolbar.
- Being able to undo is what makes it safe to try things. It is also the reason most destructive actions need no confirmation.

## 10. Files

- Create and open through the File menu and the standard shortcuts.
- Use the system's open and save panels. People know them. Build a custom browser only for a strong reason, and then let people reach the rest of the file system.
- The Open button in an open panel can be renamed to fit the task, such as Insert.
- Keep people's work without being asked: save periodically, when a window closes and when the person switches away.
- New documents are called Untitled until named.
- Hide file extensions by default and honor the person's choice to show them.
- If people have turned autosave off in system settings, show a dot in the close button and beside the name in the Window menu when there are unsaved changes, and ask before closing.
- Offer Quick Look previews for files the app shows but cannot open.
