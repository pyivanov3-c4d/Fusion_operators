# PSN_Threshold

Photoshop-style Threshold: convert RGB to pure black or white using a single brightness cutoff, preserving alpha.

- **Threshold Level:** integer 1–255, default **128**. Increasing the level makes more of the image black.
- **Preview:** disable to pass the original image through unchanged.
- **Input encoding:** RGB as supplied by default. The optional linear-sRGB setting applies the sRGB transfer curve before testing brightness; it is not an ACEScg or log conversion.
- **Pre-Divide / Post-Multiply:** enabled by default for premultiplied images. Disable for straight RGB. Transparent pixels remain transparent; hidden RGB at zero alpha is cleared to black.

The calibrated RGB brightness is `0.30 R + 0.59 G + 0.11 B`. In byte units, values greater than `Threshold - 0.5` become white; exact half ties become black. A small tolerance handles float32 transport error. The implementation uses floating-point input values without quantizing each RGB channel. RGB is bounded to 0–1 before testing. Photoshop's histogram is not reproduced in this native Fuse interface.

## Install

Copy `PSN_Threshold.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press **Shift+Space**, search **PSN_Threshold**, and connect an image. Internal registry ID: `Fuse.PSN_Threshold`. No Python or MCP is needed to use the installed node.

## Validation

Compared actual Fusion Studio 20.0.0.50 renders against Photoshop 27.2.0 Threshold exports using an 8-bit sRGB fixture containing a full gray ramp, red ramp and random colors. All 16,384 pixels matched exactly at each of nine levels: 1, 32, 64, 127, 128, 129, 192, 254 and 255. Additional render checks covered premultiplied half-alpha, linear sRGB input, Preview bypass and zero alpha. Report: [Threshold validation results](../validation/threshold-results.json).

This validates the tested 8-bit RGB workflow, not all Photoshop modes, profiles or 16/32-bit behavior. For comparisons, supply the same RGB working-space values; the node performs no ICC conversion. Fusion's normal mask and Blend controls can soften/mix the binary result.

To try the effect, connect an image and move Threshold Level. Higher values make more of the image black.

Reference: [Adobe adjustment and fill layers](https://helpx.adobe.com/ca/photoshop/desktop/create-manage-layers/color-adjustment-fill-layers/work-with-adjustment-and-fill-layers.html). Independently implemented and calibrated; no Adobe source code is included.
