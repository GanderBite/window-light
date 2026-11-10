# Visual design

Sources (Apple Human Interface Guidelines, read 2026-11-10): layout, typography, color, dark-mode, materials, motion, sf-symbols, icons, images, branding. All under https://developer.apple.com/design/human-interface-guidelines/

## Contents

1. Layout
2. Typography
3. Color
4. Dark Mode
5. Standard materials
6. Motion
7. SF Symbols
8. Interface icons
9. Images
10. Branding

## 1. Layout

**Hierarchy**

- Order by importance. People read from the top and the leading side, so the most important things go there.
- Align things so they are easy to scan. People read aligned items as related and indented items as subordinate, so use both on purpose.
- Group related items with space, a container shape or a separator.
- Reveal progressively. Too much at once makes everything harder to find. Use disclosure controls, menus and detail views to hold back what is not needed yet.
- Set controls apart from content with the Liquid Glass layer and the scroll edge effect, not with a colored strip behind them.
- A background that fills the window runs to its edges, beneath sidebars and toolbars.

**Adapting**

- A window can be any size, including very wide and short or tall and narrow. Check the smallest and the largest first.
- Keep the same functions at every size. Change only how much is shown.
- Respect safe areas and the system's margins.
- Text gets longer in other languages. Leave room and test.
- When artwork must fill a different shape, scale it to fill. Never change its aspect ratio.

**On the Mac**

- Nothing critical at the bottom of a window. People often move that edge off screen.
- Nothing behind the camera housing at the top of the display.

**Sizes and spacing**

- Controls: 28×28 pt by default on the Mac, and never smaller than 20×20 pt.
- Padding: about 12 pt around an element with a bezel, and about 24 pt around the visible edges of one without.
- Apple's general guidance for buttons asks for a hit region of at least 44×44 pt. On the Mac, follow the Mac figures above for pointer use. On a Mac with a touch display, make the region that responds larger without making the control look bigger.
- Use the system's spacing. Do not override it, and do not crowd controls.

## 2. Typography

The Mac's system font is SF Pro. Use it through the system text styles and never embed it.

**Sizes**

- Default text size on the Mac is 13 pt. The minimum is 10 pt.
- The Mac does not have Dynamic Type. Text still has to hold up when people enlarge it or turn on bold text, so build with text styles and layouts that can grow.

**macOS text styles**

| Style | Weight | Size (pt) | Line height (pt) | Emphasized weight |
|---|---|---|---|---|
| Large Title | Regular | 26 | 32 | Bold |
| Title 1 | Regular | 22 | 26 | Bold |
| Title 2 | Regular | 17 | 22 | Bold |
| Title 3 | Regular | 15 | 20 | Semibold |
| Headline | Bold | 13 | 16 | Heavy |
| Body | Regular | 13 | 16 | Semibold |
| Callout | Regular | 12 | 15 | Semibold |
| Subheadline | Regular | 11 | 14 | Semibold |
| Footnote | Regular | 10 | 13 | Semibold |
| Caption 1 | Regular | 10 | 13 | Medium |
| Caption 2 | Medium | 10 | 13 | Semibold |

**Rules**

- Use the built-in styles to express hierarchy. Do not set sizes by hand.
- Build hierarchy from weight, size and color together, and keep it when text is enlarged.
- Avoid Ultralight, Thin and Light. Prefer Regular, Medium, Semibold and Bold.
- Use as few typefaces as possible.
- For emphasis within a style, use its emphasized weight (`bold()` in SwiftUI).
- Three or more lines of text should not have tight leading. Wide columns and long passages read better with looser leading.
- Truncate as little as possible. Let a label take the lines it needs.
- For text that should look like the text in standard controls, AppKit offers system font variants for control content, labels, menus, the menu bar, messages, palettes, titles and tooltips.
- A custom font has to be legible at every size and support the same accessibility behavior as the system font. If the brand needs one, use it for headlines and keep the system font for body text and captions.

## 3. Color

**Principles**

- Use color sparingly and to communicate: status, interactivity, emphasis, continuity.
- One color, one meaning. If the accent color marks what can be clicked, do not use it for text that cannot.
- Never use color alone to carry meaning. Add text, a symbol or a shape.
- Every color has to work in light, in dark and with Increase Contrast. System colors already do. A custom color needs a light and a dark version, each with an increased-contrast version that differs clearly. Provide both appearances even if the app ships in one, so Liquid Glass can adapt.
- Never hard-code the values of system colors. They change between releases. Use the color APIs.
- Use each semantic color for its purpose. The separator color is not a text color. A label color is not a background.
- Translucency and nearby artwork change how a color looks. Check colors where they will actually sit, including behind and on glass.
- Colors carry different meanings in different cultures. Check that a color says what is intended everywhere the app is offered.
- Where people choose a color, use the system color picker (`ColorPicker`).

**System colors** with built-in variants for light, dark and increased contrast: red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown.

**Semantic colors on the Mac** (AppKit names). Choose by role:

| Role | Color |
|---|---|
| Primary text of a label | `labelColor` |
| Less important text, in three steps | `secondaryLabelColor`, `tertiaryLabelColor`, `quaternaryLabelColor` |
| Text in a document | `textColor` |
| Placeholder text | `placeholderTextColor` |
| Text of an unavailable control | `disabledControlTextColor` |
| A link | `linkColor` |
| Window background | `windowBackgroundColor` |
| Background of a large element such as a table or browser | `controlBackgroundColor` |
| Background behind text | `textBackgroundColor` |
| Alternating table rows | `alternatingContentBackgroundColors` |
| Separator between sections | `separatorColor` |
| Table grid lines | `gridColor` |
| Selected content in the key window | `selectedContentBackgroundColor` |
| Selected content in a window that is not key | `unemphasizedSelectedContentBackgroundColor` |
| Selected text background | `selectedTextBackgroundColor` |
| The accent color the person chose | `controlAccentColor` |
| Keyboard focus ring | `keyboardFocusIndicatorColor` |

**Accent color**

- The app can define an accent color for buttons, selection highlighting and sidebar icons.
- It applies only while the person's accent color setting is multicolor. If they chose a specific color, their color replaces the app's everywhere. Design so the app works with any accent color.
- A sidebar icon with a fixed color keeps it. Use that only where the color itself is the meaning.
- Use the accent color with intent, for primary actions and status, not across the whole interface.

**Color and Liquid Glass.** See `liquid-glass.md`, section 5.

**Color management**

- Embed a color profile in every image. sRGB is accurate on most displays.
- Use Display P3 for richer color where it helps, at 16 bits per channel, exported as PNG.
- Two similar P3 colors can be hard to tell apart on an sRGB display, and P3 gradients can clip. Supply separate assets per color space when that happens.

## 4. Dark Mode

- Follow the system appearance. Never add an appearance switch to the app. People would have to set it twice and might think the app is broken.
- The appearance can change while the app is running, when people use the automatic setting.
- Dark colors are not simply the light ones inverted. Use semantic colors, and define custom colors as color sets with both versions in the asset catalog.
- Contrast: never below 4.5:1. For custom foreground and background pairs aim for 7:1, especially for small text.
- Test both appearances with Increase Contrast and with Reduce Transparency, each alone and both together. Dark text on dark backgrounds is where it fails.
- An image with a white background glows in Dark Mode. Darken it slightly.
- Use SF Symbols. They adapt. Draw separate light and dark versions of a custom icon only when one cannot work in both.
- Use the label colors for text and system views for text fields and text views.
- A permanently dark interface is right only in rare cases, such as immersive media viewing.
- **Desktop tinting.** When people choose the graphite accent color, window backgrounds take a little color from the desktop picture. Give a custom component with a visible background or bezel some transparency in its neutral state so it joins in. Add none in a state that uses color.

## 5. Standard materials

Liquid Glass is for controls and navigation. **Standard materials** give structure inside the content layer, beneath the glass.

- Pick a material for its purpose, never for the color it seems to have. System settings change how it looks.
- Put vibrant system colors on top of materials. They stay legible in every context.
- Thicker materials are more opaque and give better contrast for text and fine detail. Thinner ones keep more of the background visible and preserve context.
- The Mac has two blending modes: behind the window, which shows what is behind the window, and within the window, which shows the window's own content beneath.
- Decide deliberately where a custom view allows vibrancy, and test it over different backgrounds.
- Inactive windows drop vibrancy. Check both window states.

## 6. Motion

- Motion has a job: showing status, giving feedback, teaching, showing where something went. Motion with no job is a distraction and can make people feel unwell.
- Never make motion the only way information reaches people.
- Realistic and consistent. Something that slid down from the top goes away upward, not sideways.
- Brief and precise. Short feedback is lighter and often says more than a prominent animation.
- No custom animation on interactions that happen all the time. The system already animates standard controls subtly.
- People can act before an animation ends. Never make them wait for one.
- Standard components already adjust their motion to the input method and to accessibility settings.

**With Reduce Motion on**, cut automatic and repeating animation, including zooming, scaling and movement at the edge of vision, and:

- tighten springs so there is less bounce;
- follow the person's gesture directly;
- do not animate changes in depth;
- replace movement along an axis with a fade;
- do not animate into or out of a blur.

Be very careful with flashing and rapid blinking. In excess they distract, cause dizziness and can trigger seizures.

## 7. SF Symbols

Symbols match the system font in weight and align with text at every size. Use them wherever an interface icon is needed.

**Rendering modes**

| Mode | What it does | Use it when |
|---|---|---|
| Monochrome | One color for the whole symbol | The default in toolbars and beside text |
| Hierarchical | One color at different opacities per layer | Depth and emphasis are wanted without more colors |
| Palette | Two or more colors, one per layer | The symbol has to match a color scheme |
| Multicolor | The symbol's own colors | The colors add meaning, like green for a leaf |

Check the chosen mode at the real size and against the real background. A mode that reads well large can lose detail small.

**Variants, weights and scales**

- Outline is the default and suits toolbars, lists and anywhere a symbol sits beside text.
- Fill gives more emphasis and suits selection.
- Slash shows that something is unavailable. An enclosing shape improves legibility at small sizes.
- Many views choose outline or fill themselves. A toolbar takes outline.
- Nine weights match the nine weights of the system font. Match the symbol's weight to the text beside it.
- Three scales, small, medium and large, adjust emphasis relative to the text without breaking the weight match.

**Variable color** shows a value that changes, such as signal strength or volume. It is for change, not for depth. Use hierarchical rendering for depth.

**Gradients** can be generated from a single color in any rendering mode. They look best at larger sizes.

**Animations.** Each has a meaning, so choose by meaning.

| Animation | Says |
|---|---|
| Appear, Disappear | Something came into view or left |
| Bounce | An action happened or is needed |
| Scale | This item is selected or in focus |
| Pulse, Breathe | Something is going on |
| Variable color | Progress or ongoing activity |
| Replace, Magic Replace | A state changed |
| Wiggle | Look here, or a direction |
| Rotate | Work in progress |
| Draw On, Draw Off | Progress, or a reinforced meaning |

Use them sparingly. Each one must say something, and together they must suit the tone of the app.

**Custom symbols**

- Start from the template of a similar symbol and match the system's level of detail, optical weight, alignment and perspective.
- Simple, recognizable, inclusive and directly related to what it stands for.
- Give it an accessibility description.
- Build badges and enclosures from the component library. Do not draw them in.
- Never copy an Apple product, and never alter a symbol that represents an Apple product or feature.
- Symbols, and images that could be confused with them, may not appear in app icons, logos or any trademarked use.

## 8. Interface icons

- One idea per icon, highly simplified, with a familiar metaphor.
- Consistent across the app in size, level of detail, stroke weight and perspective.
- The same weight as adjacent text.
- Center optically. An asymmetric shape may need a little padding in the asset to look centered.
- No separate selected version is needed in standard components. The system draws selection.
- Text in an icon only when the text is the meaning, and then localized.
- Custom icons in a vector format, PDF or SVG.
- An accessibility label on every icon.
- No pictures of Apple hardware.

**Standard symbols for standard actions.** Use these wherever the action appears: menus, toolbars, buttons.

| Action | Symbol |
|---|---|
| Cut | `scissors` |
| Copy | `document.on.document` |
| Paste | `document.on.clipboard` |
| Done | `checkmark` |
| Cancel | `xmark` |
| Delete | `trash` |
| Undo | `arrow.uturn.backward` |
| Redo | `arrow.uturn.forward` |
| Compose | `square.and.pencil` |
| Duplicate | `plus.square.on.square` |
| Rename | `pencil` |
| Move to | `folder` |
| Attach | `paperclip` |
| Add | `plus` |
| More | `ellipsis` |
| Select | `checkmark.circle` |
| Search | `magnifyingglass` |
| Find | `text.page.badge.magnifyingglass` |
| Filter | `line.3.horizontal.decrease` |
| Share | `square.and.arrow.up` |
| Print | `printer` |
| Account | `person.crop.circle` |
| Archive | `archivebox` |
| Calendar | `calendar` |

Apple's page lists more, including text formatting, layer ordering and ratings: https://developer.apple.com/design/human-interface-guidelines/icons

**Document icons.** If the app has its own document type, the system can build its icon from the app icon and the file extension. A custom one is composed of a background fill, a center image and a short text, and has to stay recognizable at 16×16 px. Keep important content out of the top-right corner, where the folded corner is drawn.

## 9. Images

- macOS needs bitmap assets at @1x and @2x.
- Design at the lower resolution with control points on whole values, then scale up.
- Formats: PNG for bitmap artwork, JPEG or HEIC for photos, PDF or SVG for icons and flat artwork that must scale.
- Embed a color profile.
- Look at the result on real displays.

## 10. Branding

- The brand shows in the app icon, the voice of the text and an accent color used with intent. It does not show in custom chrome.
- The brand gives way to content. Do not spend screen space on something that only displays the brand, and do not repeat the logo through the app.
- Express the brand through familiar components. If one has to be restyled, keep its size, placement and behavior.
- Put brand color in the content layer, where it shows through the glass. Do not put it on controls.
- No branded splash at launch.
- Apple's trademarks never appear in the app's name or images.
