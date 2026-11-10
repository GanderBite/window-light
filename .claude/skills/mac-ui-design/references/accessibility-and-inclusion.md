# Accessibility and inclusion

Sources (Apple Human Interface Guidelines, read 2026-11-10): accessibility, inclusion, right-to-left, keyboards, color, typography, motion. All under https://developer.apple.com/design/human-interface-guidelines/

## Contents

1. What accessible means
2. Vision
3. Hearing
4. Mobility and keyboard
5. Cognition
6. Checking a screen
7. Inclusion
8. Languages and regions
9. Right-to-left layouts

## 1. What accessible means

An accessible interface is:

- **Intuitive.** Familiar, consistent interactions make each task straightforward.
- **Perceivable.** Nothing depends on a single sense. The same information is available by sight, hearing or touch.
- **Adaptable.** It follows how people have set up their Mac: system accessibility features and personal settings.

A disability is a spectrum, and everyone meets one at some point: permanently, for a while after an injury, or in a situation such as bright sun or a noisy room. Designing for these cases makes the app better for everyone. Never assume a disability means someone will not want to use a feature.

Standard components bring most of this with them. Every custom component has to be given it by hand.

## 2. Vision

**Text size**

- Default text on the Mac is 13 pt, and the minimum is 10 pt.
- Let people make text and icons larger, ideally up to 200 percent. The Mac has no Dynamic Type, so this comes from the system text styles and from layouts that grow with their text.
- A thin font weight needs a larger size than these to be readable.

**Contrast.** Minimum ratios between text or icons and their background:

| Text size | Weight | Minimum ratio |
|---|---|---|
| Up to 17 pt | Any | 4.5:1 |
| 18 pt and larger | Any | 3:1 |
| Any | Bold | 3:1 |

- If the default colors fall short, provide a higher-contrast scheme when Increase Contrast is on.
- Check in both light and dark.
- System colors have accessible variants built in, so prefer them.

**Color**

- Never convey something by color alone. Add a shape, a symbol or text. Red against green and blue against orange are especially hard to tell apart.
- Where people rely on color-coded content, consider letting them choose the colors.

**VoiceOver**

- Every control has a label that says what it does.
- Every icon and every meaningful image has a description. Decorative images are hidden from VoiceOver.
- A state shown only visually also has to be spoken: selected, unavailable, marked in some way.
- Reading order follows the visual order.

## 3. Hearing

- Nothing important reaches people through sound alone. Pair every audio cue with something visible.
- Media with speech has captions or subtitles, and long recordings have a transcript.
- Let people control playback. Do not start audio or video without visible controls to stop it.

## 4. Mobility and keyboard

**Control size**

- 28×28 pt by default on the Mac, never smaller than 20×20 pt.
- Space matters as much as size: about 12 pt of padding around elements with a bezel, and about 24 pt around those without.

**Gestures**

- Use the simplest gesture for anything frequent. No custom multi-finger gestures.
- Every gesture has another way to do the same thing, such as a button or a menu command.

**Keyboard**

- The whole app works with the keyboard alone. Turn on Full Keyboard Access in the Accessibility settings and go through every window, menu and control.
- Do not override system shortcuts or the accessibility shortcuts.
- Putting every command in the menu bar is what makes it reachable from the keyboard.

**Assistive technology**

- Test with VoiceOver, Voice Control, Switch Control and Pointer Control. Good labels are what make these work.
- Voice Control uses the labels of controls. Name things the way people would say them.

## 5. Cognition

- Keep actions simple and consistent. Prefer interactions people already know from the system.
- Avoid anything that disappears on a timer. People who read slowly or use assistive technology need more time. Let views be dismissed by an explicit action.
- Do not play audio or video automatically without controls.
- Be careful with fast or blinking animation. It distracts, can cause dizziness and can trigger seizures.
- With Reduce Motion on, remove automatic and repeating animation, replace movement with fades, tighten springs, and avoid animating depth or blur. See `visual-design.md`, section 6.

## 6. Checking a screen

Go through this with the app running, not from the code.

1. Tab through the window with Full Keyboard Access on. Can every control be reached, in a sensible order, and operated? Is the focus ring always visible?
2. Turn on VoiceOver. Does each element say what it is and what state it is in? Do icons and images have descriptions?
3. Turn on Increase Contrast, then Reduce Transparency, then both, in light and in dark. Is everything still legible, including text on glass and on materials?
4. Turn on Reduce Motion. Does anything still slide, zoom or bounce?
5. Look at the screen in grayscale. Is anything distinguishable only by color?
6. Enlarge the text. Does anything clip, overlap or truncate?
7. Open Accessibility Inspector and run its audit.

## 7. Inclusion

An inoffensive app is not automatically an inclusive one. The aim is that everyone feels the app was made with them in mind.

**Language**

- Plain and direct. No jargon, and no technical term without an explanation.
- Address people as "you". Do not call them "the user".
- No idioms and no colloquial phrases. They are cultural, they translate badly, and some have origins that exclude people.
- Be careful with humor. It is subjective, it wears thin when repeated and it does not translate.
- Watch the tone. An academic or clever tone suggests the app is for experts only.

**People**

- Leave gender out unless it is needed. "Subscribers can post recipes" in place of "a subscriber can post his or her recipes". It also translates better.
- Depict a generic person with a figure that has no gender. SF Symbols has several.
- Where people are shown, show a range of ages, bodies, backgrounds and abilities, and avoid stereotypes about roles.
- Do not assume one shape of family, one level of income or one kind of home.
- Do not base anything on experiences only some people have had.

**Approachable**

- No special knowledge is needed to begin, and there is a clear path to learning more.

## 8. Languages and regions

- Prepare for other languages from the start: no text baked into images, no layouts that fit only one language's word lengths, no sentences assembled from fragments.
- Dates, times, numbers and currency follow the person's region settings.
- Text grows and shrinks between languages. Leave room and test with the longest language.
- Colors and symbols mean different things in different places. Check both.
- SF Symbols includes variants for different scripts, which makes localization easier.

## 9. Right-to-left layouts

Standard components and standard layouts mirror automatically for right-to-left languages such as Arabic and Hebrew. Use leading and trailing in layouts, never left and right. Then check these by hand.

**Mirror**

- Controls that show progress or a value from start to end, such as sliders and progress indicators, together with the symbols at each end.
- Controls for moving through an ordered sequence: back, next, previous.
- Icons that show reading direction or forward and backward movement.
- The order of images when the order means something, such as a chronological row.

**Do not mirror**

- Photographs, illustrations and artwork.
- Logos, and universal marks such as a checkmark.
- Icons of real objects, such as a clock, and tools drawn for the right hand.
- Controls that refer to a real direction. "Right" stays right.
- The digits within a number, a phone number or a card number.

**Text**

- One or two lines of text align to the reading direction of the interface. A paragraph of three or more lines aligns to its own language.
- All items in a list share one alignment.
- Arabic and Hebrew text beside all-capital Latin text can look too small. About 2 pt larger often balances it.
