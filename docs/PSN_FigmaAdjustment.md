# PSN_FigmaAdjustment 3.0

Figma's seven image adjustments for Fusion Studio: **Exposure, Contrast, Saturation, Temperature, Tint, Highlights, Shadows**, in Figma's order. All sliders range from -100 to +100 and default to zero.

Add with **Shift+Space → PSN_FigmaAdjustment**. Existing nodes need **Reload**, or add a fresh instance. Registry ID `Fuse.PSN_FigmaAdjustment` and existing input IDs remain unchanged.

## Version 3 changes

The old fitted curves are replaced by the adjustment mathematics verified from Figma's renderer and checked against its exports. Version 2's saturated-color errors, incorrect saturation model, and unused input-encoding option are fixed. Reloading an old node changes its result to the corrected behavior.

Processing order:
1. Decode RGB with Figma's 2.2 gamma curve.
2. Calculate Highlights/Shadows weights from the original luminance.
3. Apply Temperature, Tint, and Contrast in simplified cube-root Lab space.
4. Apply Exposure plus the local tonal contribution, including negative-exposure color compensation.
5. Apply Saturation in RGB with the positive-saturation gamut limits.
6. Encode RGB and optionally round to Figma's 8-bit output values.

This is an independently written Fusion implementation. No Figma binaries or shader source are included in the operator.

## Verification — 2026-11-05

Tested in Fusion Studio 20.0.0.50 against 93 archived Figma Desktop exports, 43 new dense-chart exports, and 20 additional combined settings. The dense chart contains a 17×17×17 RGB lattice, a 256-step gray ramp, and 3,023 independent random colors.

**156 image comparisons; 4,325,376 pixels.** Each slider was checked separately, with combined positive/negative extremes and randomized settings.

| Adjustment | Previous max error | Version 3 max error |
| --- | ---: | ---: |
| Exposure | 122 | 1 |
| Contrast | 25 | 1 |
| Saturation | 115 | 1 |
| Temperature | 25 | 1 |
| Tint | 33 | 1 |
| Highlights | 136 | 1 |
| Shadows | 46 | 1 |
| Combinations | 90 | 1 |

Errors are in 8-bit levels (0–255), with Figma 8-bit rounding enabled. All compared alpha values match. Exact RGB channel matches: **99.98325%** on the new dense suite, **99.99715%** on combined settings, and **98.37487%** across all suites including the older desktop exports.

**Not universally bit-for-bit identical:** the largest measured difference is 1/255. Figma Desktop and Figma's connector themselves differ by one level on a controlled cross-check; Fusion matched that connector image exactly. Renderer precision and output quantization affect the last bit. Finite tests do not prove equality for every possible image and setting.

Reports: [render comparisons](../validation/figma-adjustment-results.json), [version 2 baseline](../validation/figma-adjustment-v2-baseline.json), and [behavior checks](../validation/figma-adjustment-behavior-results.json). The final report records the tested source hash.

Additional checks cover premultiplied/straight RGB, zero alpha, linear input, exact neutral/bypass behavior, saved defaults, and composition reopening. No Fuse errors occurred during validation.

## Fusion options

- **RGB as supplied (default):** ordinary gamma-encoded images; no automatic profile conversion.
- **Linear sRGB / Rec.709 primaries:** converts linear RGB to sRGB encoding before processing, then back. Not an ACES or camera-log transform.
- **Pre-Divide / Post-Multiply (default on):** handles premultiplied RGB and preserves alpha. Turn off for straight RGB.
- **Figma 8-bit rounding (default on):** rounds adjusted encoded RGB to 256 levels for closer PNG matching. Turn off to retain floating-point precision for downstream grading. Alpha is not quantized by the operator.

**Preview off** and **all-zero controls** pass the image through unchanged, including floating-point precision. Out-of-range RGB residuals are retained; Figma matching is validated for SDR inputs in 0–1.

## Installation

Copy [PSN_FigmaAdjustment.fuse](../Fuses/PSN_FigmaAdjustment.fuse) to:
`%APPDATA%\Blackmagic Design\Fusion\Fuses\`

Restart Fusion or reload existing nodes. The existing registry and input IDs are preserved.

## References

- [Figma image adjustments](https://help.figma.com/hc/en-us/articles/360041098433-Adjust-the-properties-of-an-image)
- [Figma image paint API](https://developers.figma.com/docs/plugins/api/Paint/)
- [Verification file](https://www.figma.com/design/DlRkFPvaehe1Q1dTM9uQFO/Untitled?node-id=6-2)

Not affiliated with or endorsed by Figma.

