# PSN_Vibrance

An approximation of Photoshop's **classic Vibrance** adjustment, with two sliders:

- **Vibrance:** −100 to +100, default **0**. Boosts muted colors selectively, with reduced boosting in red-orange hues. This is hue-based protection, not face or skin detection.
- **Saturation:** −100 to +100, default **0**. Applies a broader saturation adjustment after Vibrance. At −100 the result is grayscale.
- **Preview:** turn off to pass through the original image. Both sliders at zero also give exact passthrough.

This targets the classic algorithm (Photoshop 27.2's `useLegacy=true`), not the newer **Color and Vibrance** adjustment with Temperature and Tint.

## Fusion options

Use **sRGB (Photoshop-style)** for display-referred sRGB. Choose **Linear sRGB / Rec.709 primaries** for linear sRGB images. No ICC, ACEScg or camera-log conversion is performed.

**Pre-Divide / Post-Multiply** defaults on for premultiplied RGB. Disable it for straight RGB. Alpha is retained, including fully transparent pixels. Out-of-range RGB residuals are retained as a compositing extension; Photoshop HDR equivalence is not claimed. Processing uses floating-point intermediates and multithreaded CPU evaluation.

## Install

Copy `PSN_Vibrance.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press **Shift+Space** and search **PSN_Vibrance**. Registry ID: `Fuse.PSN_Vibrance`. No Python or MCP is needed to use the installed node.

## Validation and limitations

Compared actual Fusion Studio 20.0.0.50 renders with Photoshop 27.2.0 classic Vibrance adjustment layers at 20 settings. Each 8-bit sRGB fixture contains 16,384 pixels: gray/red ramps and random colors.

- Saturation-only cases: maximum difference **1/255** per RGB channel.
- Vibrance-only cases: maximum difference **12/255**; mean absolute error below **0.78/255** in each tested case.
- Combined controls: maximum difference **69/255** at Vibrance +100 / Saturation +100, principally near clipped channels. Mean error stayed below **1.21/255** in each tested combined case. The approximation is not suitable when exact Photoshop matching is required, especially with strong combined settings.
- Neutral settings matched exactly. Additional checks passed for Preview bypass, premultiplied half-alpha, zero alpha, straight RGB, linear/sRGB consistency and saved/reopened slider values.

Reports: [Photoshop comparison](../validation/vibrance-results.json) and [behavior results](../validation/vibrance-behavior-results.json). These measurements do not guarantee matching for other images, profiles, Photoshop versions or bit depths.

The implementation adapts a fitted linear-light curve from Patchy: the gain depends on saturation, maximum channel and hue; Saturation follows it. It does not reproduce Adobe's proprietary implementation exactly.

To try the effect, connect an image and raise Vibrance from zero. Keep Saturation at zero initially to assess the selective adjustment.

## References and license

- [Adobe: Vibrance adjustment](https://helpx.adobe.com/photoshop/using/adjust-vibrance.html)
- [Seth A. Robinson's Patchy calibration](https://github.com/SethRobinson/Patchy/blob/main/docs/adjustment-kinds.md), and [MIT-licensed reference curve](https://github.com/SethRobinson/Patchy/blob/main/src/core/adjustment_layer.cpp). The copyright and license notice are embedded in the Fuse and retained in [MIT notice](../third-party/Patchy-MIT.txt).

No Adobe source code is included.
