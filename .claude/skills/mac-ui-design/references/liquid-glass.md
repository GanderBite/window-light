# Liquid Glass

Sources (Apple, read 2026-11-10):

- https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/design/human-interface-guidelines/color

## Contents

1. What it is
2. What the system already does
3. Do I need custom glass?
4. Regular or clear
5. Color on glass
6. Shape
7. Content beneath glass
8. Toolbars
9. Custom glass in code
10. Settings to test with
11. Smells
12. Keeping the earlier look

## 1. What it is

Liquid Glass is a dynamic material that joins the optical qualities of glass with a sense of fluidity. It blurs the content behind it, reflects the color and light of what surrounds it, and reacts to touch and pointer interaction in real time.

It has one job: to form a **functional layer** for controls and navigation that floats above the **content layer**. Content scrolls and peeks through beneath the controls. That gives depth and keeps people oriented, and the controls stay legible.

How it adapts:

- It has no color of its own. It takes color from the content directly behind it.
- Small elements such as toolbars switch between a light and a dark look depending on what is beneath them. Their symbols and text stay monochrome: darker over light content, lighter over dark content.
- Large elements such as sidebars are more opaque, so they stay readable over busy backgrounds and can hold richer content.
- Its movement is stronger under direct touch and more subdued under a trackpad.
- People can pick a preferred look for Liquid Glass in system settings and can turn on Reduce Transparency, Increase Contrast or Reduce Motion. Each of these can change or remove effects.

## 2. What the system already does

Build with the current SDK and standard components, and all of this arrives without code:

- Bars, sheets, popovers, menus, sidebars and controls use the material, and adapt when elements overlap or gain focus.
- Controls come alive during interaction. The knob of a slider or toggle turns to glass while it is being moved. Buttons morph into the menus and popovers they open.
- Shapes are rounder and follow the curvature of the window and the hardware. Windows, sheets and list sections have larger corner radii. An extra-large control size is available.
- Lists, tables and forms have taller rows and more padding. Section headers use title-style capitalization and are no longer forced to capitals, so write them in title style.
- Menus show icons for common actions. Standard actions get their icon from the standard selector.
- Sheets and popovers draw their own background. A confirmation dialog appears from the control that opened it, so always give it that source.

The consequence for your code: **delete, do not add.** Go through each of these and remove any custom background, visual effect view, tint or hard-coded metric:

`NavigationStack`, `NavigationSplitView`, the title bar, `toolbar(content:)`, `NSToolbar`, `NSSplitView`, sheets, popovers, and the standard controls (`Button`, `Toggle`, `Slider`, `Stepper`, `Picker`, `TextField` and their AppKit counterparts).

## 3. Do I need custom glass?

Ask in this order and stop at the first yes.

1. **Is there a standard component for this?** Use it. You are done.
2. **Is the element content?** A row, a card, a caption, a picture frame, a background. Then it gets no glass. Use a plain background or a standard material.
3. **Is it a button?** Use a glass button style (`.buttonStyle(.glass)`, or `.glassProminent` for the one primary action; `NSButton.BezelStyle.glass` in AppKit) before writing an effect by hand.
4. **Is it a control or navigation element that floats above content, and one of the few most important on the screen?** Then a custom glass effect is justified. See section 9.

Anything else stays without glass. The material exists to point attention at the content beneath it. Each extra glass element spends some of that attention.

One exception is built in: a control inside the content layer that has a moving part, like a slider or a toggle, shows glass on that part while a person is using it. The system does this. Do not imitate it.

## 4. Regular or clear

| Variant | What it does | Use it for |
|---|---|---|
| Regular | Blurs the background and adjusts its brightness so text and symbols on the glass stay legible. | Almost everything. Anything with text. Anything over content that could hurt legibility: alerts, sidebars, popovers, toolbars. |
| Clear | Highly translucent. Keeps the background vivid. | Only small controls floating over visually rich media such as photos and video. |

With clear glass, check the contrast of what is on it:

- Over bright content, add a dark dimming layer of 35% opacity behind the control.
- Over content that is already dark, or with the standard media playback controls, add nothing.

When unsure, use regular.

## 5. Color on glass

- Leave glass uncolored by default. Its color comes from the content.
- Tint is for emphasis: a primary action or a status indicator. The system does this for prominent buttons such as Done.
- To emphasize an action, tint the **background** of the control, not its symbol or text.
- Do not tint the background of several controls in one view. One tinted control is a focal point. Three are a decoration.
- When the content is colorful or visually rich, keep toolbars monochrome. A label colored like the content behind it disappears.
- When the content is mostly monochrome, the app's accent color can carry the brand.
- Move brand color into the content layer. It scrolls under the glass and the glass picks it up.
- Check the resting state. Colorful content may pass under a control while scrolling, but at rest, such as at the top of a scroll view, the control must be clearly legible.
- Supply every custom color in light and dark, each with an increased-contrast version, even if the app ships in one appearance. Glass needs both to adapt.

## 6. Shape

Rounded shapes nest inside each other: control inside bar, bar inside window, window inside display. A shape that shares its center of curvature with its container looks settled. One with an arbitrary radius looks pasted on.

- Do not hard-code corner radii for elements near a container's edge. Use `ConcentricRectangle`, or a rectangle shape built with `rect(corners:isUniform:)`, so the corners follow the container.
- A custom component placed in a toolbar must be concentric with the bar's corners, as the standard ones are.
- A glass effect uses a capsule by default. Give larger components a rounded rectangle, because a very large capsule or circle looks odd.
- Use the same shapes for the same kind of control throughout the app.

## 7. Content beneath glass

Glass is only as good as what is under it.

- **Do not put an opaque or colored strip behind controls** to separate them from content. Use the scroll edge effect, which blurs and fades content as it passes beneath. System toolbars have it by default. Style it with `scrollEdgeEffectStyle(_:for:)`. Register a custom bar that sits over scrolling content with `safeAreaBar(edge:alignment:spacing:content:)`.
- **Run full-window backgrounds to the window edge**, beneath sidebars, inspectors and toolbars.
- **When a sidebar or inspector would cover the important part of an image**, use `backgroundExtensionEffect()` (`NSBackgroundExtensionView` in AppKit). It mirrors and blurs the adjacent content beneath the bar, so the image appears to continue without anything real being hidden.
- **Horizontal scroll views** may scroll beneath a sidebar or inspector.
- **Respect safe areas** so the system can place window controls and the title bar relative to your content. Check that content next to a sidebar or inspector shows through as intended.
- **Check sheet edges.** Sheet corners are rounder: look for content crowding them, and remove any visual effect view you added behind sheet or popover content.

## 8. Toolbars

Toolbar items sit on shared glass backgrounds, so grouping carries meaning.

- Group items that do similar things or act on the same part of the interface. Keep the same grouping on every platform the app runs on.
- Separate groups with a fixed spacer (`ToolbarSpacer` with the fixed kind).
- Prefer symbols to text for common actions. Never mix text and symbols among items that share one background: they read as a single control.
- Give every symbol an accessibility label, whatever is visible.
- One prominent, tinted action at most, on the trailing side.
- To hide an item, hide the toolbar item itself with `hidden(_:)`, not the view inside it. Hiding the view leaves an empty glass bubble.
- Do not reproduce system spacing with custom items and manual spacers. It will drift from the system's.

## 9. Custom glass in code

SwiftUI. The effect goes on with `glassEffect(_:in:)`. It defaults to the regular variant in a capsule.

```swift
Text("Preview")
    .padding()
    .glassEffect()

Text("Preview")
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16))

StatusBadge(title: "Out of Date")
    .padding()
    .glassEffect(.regular.tint(.orange))

TimeOfDayDial(selection: $slot)
    .padding()
    .glassEffect(.regular.interactive())
```

`StatusBadge` and `TimeOfDayDial` stand for custom views of your own. A plain button never needs this: it takes a glass button style, as section 3 says.

- Apply `glassEffect` **after** the modifiers that set the view's appearance, such as padding, font and frame.
- Add `interactive()` only to custom controls people actually press or drag. It gives the same fluid reaction that glass buttons have.
- Add a tint only where section 5 allows one.
- AppKit offers `NSGlassEffectView`.

Several glass elements together belong in one `GlassEffectContainer`. It renders them in one pass, and it lets their shapes blend and morph.

```swift
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 24) {
        Image(systemName: "sun.max")
            .frame(width: 56, height: 56)
            .glassEffect()
        Image(systemName: "moon")
            .frame(width: 56, height: 56)
            .glassEffect()
    }
}
```

- The container's `spacing` sets how close two shapes must be before they start to merge. If it is larger than the spacing of the stack inside, the shapes merge while at rest. Keep the two equal unless merging at rest is what you want.
- To make several views share one glass shape at rest, give them the same `glassEffectUnion(id:namespace:)`.
- For shapes that appear and disappear, give each a `glassEffectID(_:in:)` in a `@Namespace` and change the state inside `withAnimation`. Shapes within the container's spacing morph into each other with the matched geometry transition. For shapes farther apart, use the materialize transition. Use only these two, so transitions feel the same everywhere.
- Morphing should mean something: one control opening into several, or a group collapsing into one. Do not morph for decoration.

Performance: many containers, or many glass effects outside a container, cost rendering time. Keep the number of glass elements visible at once small. This is the same rule as the design rule.

## 10. Settings to test with

Standard components adapt to all of these. Anything custom has to be looked at under each.

- Light and dark appearance.
- Increase Contrast, Reduce Transparency and Reduce Motion, one at a time and together.
- The different looks for Liquid Glass that people can choose in system settings.
- Bright, dark and busy content beneath every glass element, and content scrolled halfway under it.
- The window active and inactive.
- The narrowest and widest window sizes.

## 11. Smells

Each of these means the material is being used for decoration.

- A glass effect on list rows, cards, captions or the window background.
- A glass panel placed on top of another glass panel.
- More than one tinted glass control in a view.
- A colored or blurred background added to a toolbar, sidebar, sheet or popover.
- An opaque strip behind floating controls.
- Clear glass with text on it, or clear glass over a plain background.
- Corner radii written as numbers on elements near a container edge.
- Text labels and symbols mixed in one toolbar group.
- Glass elements that appear and vanish with a plain fade while others morph.
- A screen where the eye lands on the controls first and the content second.

## 12. Keeping the earlier look

An app can be built with the latest SDK and still keep the look it had with the previous one by adding the `UIDesignRequiresCompatibility` key to the project's Info settings. Treat this as a temporary measure for an existing app, not as a design choice for a new one.
