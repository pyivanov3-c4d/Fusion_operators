# PSN_CleanSharp

High Pass sharpening followed by Overlay blending with the original image.

- **Radius (pixels)**: default **10**, adjustable from 0 to 1000 (slider scale 0–100).
- **Intensity (%)**: Overlay opacity from 0 to 100, default **20**.
- **Show High Pass**: inspect the intermediate detail image against neutral gray; disabled by default. This diagnostic view ignores Intensity.
- **Preview**: bypass the effect when disabled.
- **Pre-Divide / Post-Multiply**: enabled for premultiplied inputs. Disable for straight-alpha RGB.

The intermediate RGB image is `clamp(0.5 + original - GaussianBlur(original), 0, 1)`. Overlay uses the original as its base, then Intensity interpolates between the original and the Overlay result. Zero radius or zero intensity bypasses sharpening; Show High Pass at zero radius displays neutral gray.

Processing uses 32-bit float intermediate images and Fusion's native Gaussian blur. The blur is alpha-normalized to avoid dark fringes around transparent content; original alpha is retained. RGB beyond the 0–1 range keeps its residual as a compositor-specific extension. Use matching, display-referred RGB values for Photoshop comparisons; this operator performs no automatic ICC, log, ACES or linear-light conversion.

## Installation

Copy `PSN_CleanSharp.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press **Shift+Space** and search **PSN_CleanSharp**. Registry ID: `Fuse.PSN_CleanSharp`. No Python or MCP is needed to use the installed operator.

## Validation and limits

Tested in Fusion Studio 20.0.0.50 against Photoshop 27.2.0 using a 1000 × 720 chart. Radius 10 and 30, at 20% Overlay opacity, differed by at most 1/255 per RGB channel; radius 1 differed by at most 2/255. Intermediate High Pass differences were up to 2/255 at radius 10 and 30, and 20/255 at radius 1. Gaussian radius scaling is calibrated, but Photoshop's small-radius kernel and integer behavior are not reproduced exactly. Other images, radii, image boundaries and bit depths may differ more.

Checks also passed for default values, unchanged flat colors, half-alpha flat images, neutral High Pass, zero-radius bypass, Preview bypass, and exact zero-intensity passthrough. Reports are in [Photoshop comparison](../validation/cleansharp-comparison.json) and [behavior results](../validation/cleansharp-behavior-results.json).

To try the effect, connect an image to the node and leave Radius at 10 and Intensity at 20. Toggle Show High Pass to inspect the detail layer.

Reference: [Adobe's High Pass sharpening workflow](https://www.adobe.com/creativecloud/photography/hub/guides/sharpen-image-high-pass-filter.html). Independent implementation; no Adobe source code is included.
