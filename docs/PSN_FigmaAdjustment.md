# PSN_FigmaAdjustment

Figma-style image adjustments for Fusion Studio. It reproduces the seven sliders of **Figma's image Adjust panel** â€” Exposure, Contrast, Saturation, Temperature, Tint, Highlights, Shadows â€” in Figma's order, using Figma's own maths, measured from Figma's renderer.

Add it with **Shift+Space**, search **PSN_FigmaAdjustment**, and connect an image. The house `PSN_` prefix covers the tool name, file name and registry ID (`Fuse.PSN_FigmaAdjustment`).

| Slider | Range | Figma's operation (measured) |
| --- | --- | --- |
| Exposure | âˆ’100 â€¦ +100 | Tone curve on CIELAB L\*; compresses chroma as it lifts |
| Contrast | âˆ’100 â€¦ +100 | L\* only; negative mutes toward mid-grey |
| Saturation | âˆ’100 â€¦ +100 | Chroma scale in CIELAB; âˆ’100 is grey, L\* preserved |
| Temperature | âˆ’100 â€¦ +100 | **b\* += 29.3** at +100 (cool â†’ warm) |
| Tint | âˆ’100 â€¦ +100 | **a\* += 29.3** at +100 (green â†’ magenta) |
| Highlights | âˆ’100 â€¦ +100 | L\* only, acting above L\* 53.6 |
| Shadows | âˆ’100 â€¦ +100 | L\* only, acting below L\* 53.6 |

All seven default to 0, and all-zero is a bit-exact passthrough.

## How this was derived

Figma does not document the maths, so the behaviour was measured directly. A development plugin created an image fill, set `paint.filters` to exact values and exported each result 1:1 with `exportAsync` â€” 93 reference renders (7 sliders Ã— 13 values, plus two combined looks) on a chart holding grey, R, G and B ramps and eight colour patches.

Findings that drove the rebuild:

- The plugin API rejects filter values outside **âˆ’1â€¦1**, so the sliders are normalised. This node's âˆ’100â€¦100 maps by `/100`.
- The adjustments are **CIELAB (D65)**, not RGB gamma. Temperature moves b\* by a constant 29.3 across lightness levels and across hues; tint moves a\* the same way; L\* and the other axis stay put.
- **Contrast, Highlights and Shadows touch L\* only** â€” a\*/b\* are unchanged. Highlights are zero for L\* â‰¤ 53.6, shadows zero for L\* â‰¥ 53.6.
- **Saturation** scales chroma with L\* fixed; at âˆ’100 the result is the L\*-preserving grey (which is why it equals linear-light Rec.709 luma).
- **Exposure is a luminance gain plus a lift proportional to luminance** in linear light, fitted from Figma's renders (lift 0 at neutral and below, rising to 3.0 at +100), which is why it desaturates in both directions: a lifted pure green becomes near-white in Figma, not a brighter green. The node reproduces that by clamping chroma to the sRGB gamut boundary at the adjusted L\* (measured: this is what Figma's exposure does to most saturated colours).

The L\* curves for Exposure, Contrast, Highlights and Shadows are baked from the measurements (51 knots of L\*) and interpolated at render time, so the node follows Figma's actual curve shape rather than an invented one.

## Accuracy against Figma

Rendered in Fusion 20 with this Fuse and compared pixel for pixel with the 93 Figma exports:

| Slider | mean error | max error |
| --- | --- | --- |
| Contrast | 1.7 levels | 25 |
| Temperature | 1.6 levels | 25 |
| Tint | 1.5 levels | 33 |
| Highlights | 1.5 levels | 136 |
| Shadows | 1.8 levels | 46 |
| Saturation | 4.1 levels | 115 |
| Exposure | 5.4 levels overall (1.7–1.9 below 0, 5–29 above) | 122 |

The grey axis and ordinary colours match to 1â€“2 levels, and exposure now desaturates as it lifts instead of getting more vivid. The remaining exposure gap is on **saturated** colours: measured Figma lifts them much further than the neutral tone curve implies (blue 64 -> (10,10,171) at +50, where an L\* curve gives (26,24,87)), and no simple model â€” gain, additive light, luminance scaling, L\* curve, gamut clamp, or soft gamut clamp â€” reproduced it across the ramps. Figma's exact exposure operator is not public. Closing this needs a dense colour-grid capture from Figma and a fitted model.

## Color and transparency

**RGB as supplied** is the default and matches Figma, which treats image fills as gamma-encoded. **Linear sRGB / Rec.709 primaries** treats input as linear and returns linear; it is not an ACES or camera-log transform.

**Pre-Divide / Post-Multiply** is on by default for premultiplied images. Alpha is preserved. Out-of-range RGB residuals are preserved, so float comps are not clipped by an SDR adjustment.

## Validation

- 93 Figma reference renders and 93 Fusion renders compared pixel for pixel (`figma_probe/out` and `figma_probe/fusion`).
- All-zero is a bit-exact passthrough; Preview bypass is exact.
- Clean Fusion console (no Lua errors or warnings from the node).
- Curve tables are interpolated, not sampled per pixel, and the conversion runs through cached transfer LUTs.

## Limits

- Extreme saturated colours differ from Figma because of its unpublished out-of-gamut conversion.
- No crop/fill-mode/rotation controls â€” colour adjustments only.
- Multithreaded CPU implementation with a CIELAB conversion per pixel; heavier than an RGB LUT, suitable for stills and short shots.

## Installation

Copy `PSN_FigmaAdjustment.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Registry ID: `Fuse.PSN_FigmaAdjustment`.

Local demo: `PSN_FigmaAdjustment-Demo.comp` in the project root, using `tests/SelectiveColor-Chart.png`.

## Research

- [Figma Learn: Adjust the properties of an image](https://help.figma.com/hc/en-us/articles/360041098433-Adjust-the-properties-of-an-image)
- Figma plugin API `ImageFilters` interface and the Figma REST schema (same seven fields, range âˆ’1â€¦1)
- Measurement harness and findings: `figma_probe/` in the working session (`FINDINGS.md`, plugin, upload server, 93 exports)

Not affiliated with or endorsed by Figma. No Figma code is included; the model is an independent implementation derived from measurements.

