# PSN_BrightnessContrast

Classic Photoshop-style Brightness/Contrast for Fusion Studio. Add it with **Shift+Space**, then search **PSN_BrightnessContrast**. Connect an image to its main input.

| Control | Modern (default) | Use Legacy |
| --- | --- | --- |
| Brightness | −150 to +150 | −100 to +100 |
| Contrast | −50 to +100 | −100 to +100 |
| Preview | Toggle adjustment | Toggle adjustment |

Modern mode uses nonlinear tonal curves. Legacy uses the older clipping adjustment. Each slider defaults to zero, which passes the original image through unchanged. Fusion's normal mask and blend controls remain available. This implements the classic manual adjustment; Photoshop's Auto analysis and newer Light controls are not included.

## Color and transparency

For Photoshop comparisons, supply the same RGB values in the same working color space. The node does not convert ICC profiles. Under Fusion Options, **Linear sRGB / Rec.709 primaries** encodes linear sRGB before the adjustment and decodes afterward; this is not an ACEScg or camera-log conversion.

**Pre-Divide / Post-Multiply** is enabled by default for premultiplied compositing images. Disable it for straight RGB. Alpha is preserved. Out-of-range RGB residuals are preserved as a Fusion-specific extension; Photoshop-equivalence claims apply only to the tested 0–1 range.

## Validation

Tested in Fusion Studio 20.0.0.50 against actual Photoshop 27.2.0 adjustment-layer exports: 28 combinations covering neutral, extreme, intermediate and combined settings in both modes. The 256 × 64 fixture contains grayscale and red ramps plus random RGB colors. All Fusion PNG comparisons differed by at most **1 level out of 255 per channel**. This is a calibrated approximation, not a guarantee of bit-exact equivalence for all images, bit depths or Photoshop versions.

Additional checks passed for premultiplied transparency, alpha preservation, Preview bypass, linear-sRGB processing, Legacy slider ranges, default PSN_ node naming and saved/reopened values. Results: [Photoshop comparison](../validation/brightness-contrast-results.json) and [alpha results](../validation/brightness-contrast-alpha-results.json).

The node uses multithreaded CPU processing with a cached floating-point curve; it is not a GPU kernel.

## Installation

Copy `PSN_BrightnessContrast.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Internal registry ID: `Fuse.PSN_BrightnessContrast`.

Example starting settings: Brightness +25, Contrast +20. Reset both to zero for neutral output.

## Research

- [Adobe Brightness/Contrast documentation](https://helpx.adobe.com/photoshop/desktop/adjust-color/color-corrections/apply-brightness-and-contrast-adjustment.html)
- [Seth A. Robinson's Patchy calibration research](https://github.com/SethRobinson/Patchy/blob/main/docs/adjustments-calibration.md), MIT licensed. Attribution and license are retained in the Fuse and [MIT notice](../third-party/Patchy-MIT.txt).

