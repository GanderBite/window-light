# The app icon

Sources (Apple, read 2026-11-10):

- https://developer.apple.com/design/human-interface-guidelines/app-icons
- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/design/human-interface-guidelines/sf-symbols

## What the icon is now

An app icon is built from layers: one background layer and one or more foreground layers. The system adds the Liquid Glass qualities itself: highlights, refraction, translucency, shadow and blur. These react to the surroundings and can look different from one system version to the next.

On the Mac the icon is a square canvas of 1024×1024 px. The system masks it to a rounded rectangle whose corners match the rest of the interface and the hardware.

People can choose how icons look: default, dark, clear or tinted, with the clear and tinted looks each in a light and a dark form. The system generates any variant that is not supplied.

## Design

- **One idea.** Find the single concept that captures the app and express it with as few shapes as possible. Fine detail turns to noise under the system's highlights and vanishes at small sizes.
- **Filled, overlapping shapes.** Solid shapes that overlap, with some transparency, give depth and suit the glass treatment.
- **A simple background.** A solid color or a gradient that puts the emphasis on the foreground. The canvas does not need to be filled.
- **Clearly defined edges** on foreground shapes. Soft, feathered edges spoil the system's highlights and shadows.
- **No text** unless it is essential to the brand. It is not localized, not accessible and usually too small to read. Never words like "Play" or "New".
- **Illustration, not a photo.** Photos have detail that does not survive layers, small sizes or the other appearances.
- **Not a picture of the interface.** No screenshots and no copies of standard controls.
- **Nothing of Apple's.** No Apple hardware. No SF Symbol, and nothing that could be confused with one.
- **No thin lines and no sharp corners.** They lose crispness at small sizes.
- **The same design on every platform** the app runs on, optically balanced.

## Let the system do the effects

Do not draw highlights, drop shadows between layers, bevels, blurs or glows into the artwork. They clash with the ones the system adds, and they are static while the system's are live. If a custom effect is truly wanted, add it on purpose and check the result carefully.

## Build it

1. Decide which parts are foreground, middle and background, and draw each as its own layer in a design tool.
2. Export the layers as vectors, SVG or PDF, with text converted to outlines. Use PNG for gradient meshes and raster artwork.
3. Supply square, unmasked layers. The system applies the shape. Pre-masked layers get jagged edges and wrong highlights.
4. Keep the main content centered so the mask cannot clip it. Apple's design resources include the icon grids.
5. Compose in Icon Composer, which comes with Xcode. Set the background there, with a solid color or gradient, and avoid importing a background image. Adjust placement and opacity, group layers that should share effects, and mark up the default, dark and mono variants.
6. Preview with the system effects and in every appearance.

A flat bitmap icon still works. The system then splits it into a foreground and a background by itself and applies glass only to large, simple shapes, so text and thin lines get none. The layered format is what gives control.

## Appearances

- Keep the core features the same in every appearance. Do not swap elements in and out. People must be able to find the icon after changing the look.
- Base the dark icon on the light one, with complementary colors and nothing excessively bright. A colored background usually gives the best contrast in dark.
- Dark icons are more subdued than the default, and clear and tinted ones more subdued still. The icon has to stay visible, legible and recognizable in all of them.

## Checks

- [ ] Recognizable at the smallest size it is shown, such as in a list in system settings.
- [ ] Legible in default, dark, clear and tinted.
- [ ] No text, no photo, no interface copy, nothing of Apple's.
- [ ] No effects drawn in.
- [ ] Layers are square, unmasked and centered.
- [ ] It cannot be mistaken for a system app or for another app.
