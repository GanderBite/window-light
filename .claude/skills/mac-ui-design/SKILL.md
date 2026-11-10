---
name: mac-ui-design
description: Design guidance for Mac app interfaces. Covers how to structure windows, sidebars, toolbars, menus, sheets and settings the way macOS users expect, how to use Liquid Glass with restraint, and the foundations of Apple's Human Interface Guidelines (layout, color, typography, materials, motion, SF Symbols, accessibility, writing). Use this skill whenever you design, build, restyle or review any user-facing part of a macOS app, such as a new screen or window, a SwiftUI or AppKit view, a toolbar, a menu, an alert, onboarding, an app icon or interface wording, and whenever Liquid Glass, glass effects, the HIG, "Mac-like" or "native feel" come up, even if the request only says "add a view for X" or "make this look better". It decides what to build and why. Pair it with swiftui-pro for how to write the SwiftUI code.
---

# Designing for the Mac

This skill helps you decide what a Mac interface should be before you write it: which window, which navigation, which controls, where each command lives, how it looks, how it reads and who can use it. It is distilled from Apple's Human Interface Guidelines and the Liquid Glass documentation.

The goal is an app that feels at home on the Mac. People who use a Mac have years of habits: where Settings is, what Command-W does, that a window can be resized, that every command is in the menu bar. An interface that follows those habits needs no explanation. One that ignores them feels broken, however good it looks.

## How to use this skill

1. Read this file to the end. It holds the ideas every decision follows from.
2. Open the reference for the task in front of you. The table at the bottom says which.
3. Design, then go through the review checklist before you call the work done.

When the project has its own rules for languages, accessibility or wording, those rules win over this skill.

## Three ideas everything follows from

**Content first, controls above it.** The person came for their content: their pictures, their document, their list. Navigation and controls exist to serve it and should never compete with it. Every visual decision either keeps attention on the content or takes attention away.

**Standard components carry the platform.** A standard button, list, toolbar, sidebar, sheet or menu already has the right look, the right behavior in every state, keyboard access, VoiceOver support, Dark Mode, Increase Contrast and Liquid Glass. A custom component has none of these until you build each one. Reach for a custom component only when no standard one can do the job, and then match the standard ones in size, placement and behavior.

**The Mac is a wide, precise, many-window machine.** People sit at it for minutes or for hours, with several apps open, using a keyboard and a pointer. They resize and move windows, hide what they do not need and expect shortcuts for what they do often. Design for that, not for a phone screen made larger.

## Liquid Glass

Liquid Glass is the material Apple's platforms use for controls and navigation. It behaves like glass: it blurs what is behind it, picks up the color and light of the content around it, and reacts to the pointer and to touch as they happen. It has no color of its own.

Its purpose is hierarchy. Liquid Glass forms a separate **functional layer** that floats above the **content layer**. Toolbars, sidebars, menus, sheets, popovers and controls sit in the functional layer. Content scrolls and shows through beneath them, so the interface feels deep and alive while the controls stay readable.

Standard components from SwiftUI and AppKit use Liquid Glass without any work from you. So the first rule of using it well is to do less:

- **Use standard components and take their backgrounds away from your code.** A custom background, blur or tint on a toolbar, sidebar, split view, sheet or popover sits on top of the glass or fights it. Remove it and let the system draw.
- **Never put glass in the content layer.** Glass on list rows, cards, text blocks or the window background flattens the hierarchy, because nothing separates controls from content any more. Content gets plain backgrounds or standard materials.
- **Use custom glass sparingly.** Apply a glass effect to a custom control only when it is one of the few most important functional elements of the screen and floats above content. Glass draws the eye to what is beneath it. Many glass elements draw the eye everywhere.
- **Do not stack or crowd glass.** Glass on glass, or glass controls packed together, turns into visual noise. Keep the system's spacing.
- **Keep color off the glass.** Color belongs to the content, where it shines through. Tint one primary action per view at most, and tint its background, not its symbol or label.
- **Pick the variant by what is behind it.** Regular glass for almost everything. Clear glass only for controls that float over photos or video.
- **Let people turn it down.** People can choose a different look for Liquid Glass and can reduce transparency, increase contrast or reduce motion. Standard components adapt. Anything custom must be tested with each of those settings.

Taste with Liquid Glass is restraint. If a screen looks like a showcase of glass, the content has lost. Read `references/liquid-glass.md` before you write any glass effect, tint or custom bar.

## What makes an app feel like a Mac app

- **Use the space.** A large display can show more at once, with fewer nested levels and fewer modal steps. Show the list and the detail together. Keep density comfortable; do not make people strain.
- **Windows belong to the person.** They resize, move, hide and go full screen as the person likes. Support any reasonable size and restore the window's state at the next launch.
- **Every command is in the menu bar.** The menu bar is where people learn what an app can do. Toolbars and context menus are shortcuts to commands that are also in the menus.
- **The keyboard reaches everything.** Standard shortcuts do what they do everywhere else. The app works with the keyboard alone.
- **The pointer is precise.** Controls can be smaller and denser than on a phone. On a Mac with a touch display, make the area that responds larger, but keep the control's size and density.
- **People customize.** They can change the accent color, the toolbar, the sidebar and which parts of a window are shown. Respect system settings and never offer a private copy of one.
- **The system look is the brand.** No custom window frames, no custom title bar controls, no app-specific appearance switch.

## Foundations at a glance

| Topic | The decision that matters most | Reference |
|---|---|---|
| Layout | Most important content at the top and leading side. Nothing critical at the bottom edge of a window. | `visual-design.md` |
| Typography | Use the system text styles. Body is 13 pt on the Mac; never go below 10 pt. | `visual-design.md` |
| Color | Use system colors by their meaning. Any custom color needs light, dark and increased-contrast versions. | `visual-design.md` |
| Materials | Liquid Glass for the functional layer, standard materials for structure inside content. | `liquid-glass.md`, `visual-design.md` |
| Motion | Short, purposeful, cancelable, and never the only way information is conveyed. | `visual-design.md` |
| Symbols and icons | SF Symbols for interface icons, the standard symbol for each standard action. | `visual-design.md` |
| Accessibility | Keyboard alone, VoiceOver labels, contrast, text size, more than color. | `accessibility-and-inclusion.md` |
| Writing | Plain words, verbs on buttons, the platform's capitalization. | `writing-interface-text.md` |
| Privacy | Ask for access only when a feature needs it, and say why in one clear sentence. | `writing-interface-text.md` |

## Workflow for a new screen or window

1. **Name the job.** Write one sentence: who is here, what they came to do, and what content they are looking at. Everything on the screen has to serve that sentence.
2. **Choose the structure.** One window or several, sidebar or not, list and detail, inspector, sheet or separate window. See `references/structuring-a-window.md`.
3. **List the commands.** Put every one in the menu bar with a shortcut where it earns one. Choose the few that also deserve a place in the toolbar. See `references/commands-menus-and-input.md`.
4. **Lay out the content** with standard components, system text styles and system colors. See `references/visual-design.md`.
5. **Decide what interrupts.** Most messages belong in the window, next to what they are about. Few deserve an alert. See `references/presenting-and-feedback.md`.
6. **Write the words.** See `references/writing-interface-text.md`.
7. **Check who can use it.** See `references/accessibility-and-inclusion.md`.
8. **Review** with the checklist below.

## Review checklist

Structure

- [ ] The content is the largest and most prominent thing in the window.
- [ ] The window resizes sensibly from its minimum size to full screen, and nothing critical sits at its bottom edge.
- [ ] Every component that could be a standard one is a standard one.
- [ ] No custom window frame, title bar control or appearance switch.

Commands

- [ ] Every command is in the menu bar, including each toolbar and context menu command.
- [ ] Standard shortcuts are not repurposed. Custom shortcuts use Command first.
- [ ] Menu items that cannot be used now are dimmed, not hidden. In context menus they are hidden.
- [ ] The toolbar holds only the frequent commands, in at most about three groups, with one prominent action at most.

Liquid Glass

- [ ] No custom background, blur or tint on bars, sidebars, sheets or popovers.
- [ ] No glass in the content layer, and no glass on glass.
- [ ] Custom glass appears only on the most important floating controls, grouped in one container.
- [ ] At most one tinted control per view.

Look

- [ ] Text uses system text styles. Colors are system or asset colors with light, dark and increased-contrast versions.
- [ ] It looks right in light and dark, with Increase Contrast and with Reduce Transparency.
- [ ] Icons are SF Symbols, and standard actions use their standard symbols.
- [ ] Animation is brief, and the screen still works with Reduce Motion.

People

- [ ] Everything can be reached and operated with the keyboard alone.
- [ ] Every control, icon and meaningful image has a VoiceOver label.
- [ ] Nothing is communicated by color alone.
- [ ] Alerts are rare, say what happened and what to do, and their buttons are verbs.
- [ ] Labels follow the platform's capitalization, and no message blames the person.

## References

| Read this | When you are |
|---|---|
| `references/liquid-glass.md` | using or reviewing any glass effect, tint, custom bar or floating control, or content that scrolls under controls |
| `references/structuring-a-window.md` | choosing windows, sidebars, split views, inspectors, toolbars, search placement, a settings window, full screen or what happens at launch |
| `references/commands-menus-and-input.md` | building the menu bar, context or Dock menus, keyboard shortcuts, pointer and touch behavior, drag and drop, undo |
| `references/presenting-and-feedback.md` | deciding between a sheet, an alert, a popover, a panel or an inline message, or showing progress, errors, empty states or onboarding |
| `references/visual-design.md` | laying out a view or choosing type, color, materials, motion, symbols, icons or image assets |
| `references/accessibility-and-inclusion.md` | checking that everyone can use a design, or handling languages and right-to-left layouts |
| `references/writing-interface-text.md` | writing labels, menu items, alerts, errors, empty states, settings or permission requests |
| `references/app-icon.md` | designing or changing the app icon |

## Working with other skills

This skill decides what to build and why. For how to write it in SwiftUI (current APIs, view structure, performance), use `swiftui-pro`. Where the two differ on a size or a number, this skill's Mac figures apply to Mac apps: several of that skill's figures are for iPhone.
