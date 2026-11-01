# PSN_PhotoFilter

Photoshop-style Photo Filter for Fusion, with a warming/cooling filter or custom color, Density and Preserve Luminosity.

## Controls

- **Color swatch:** always visible below Filter. Choosing a preset updates the swatch; editing any color component switches Filter to **Custom**, the last dropdown entry. Choosing Custom manually retains the current swatch.
- **Filter:** Warming Filter (85), Cooling Filter (80), Sepia, Red, Orange, Yellow, Green, Cyan, Blue, Violet, Magenta and **Custom**.
- **Density (%):** 0–100, default **25**. Zero passes the original through unchanged.
- **Preserve Luminosity:** enabled by default. Compensates for the filter's change in brightness.
- **Preview:** bypass the adjustment when disabled.

Default: **Warming Filter (85)**, using the sRGB swatch sampled from Photoshop 27.2's default adjustment (`#ED8A00`), Density 25 and Preserve Luminosity enabled. The other swatches are convenient RGB approximations; they are not a complete or exact copy of Photoshop's preset library.

## Fusion options

Input is assumed to be sRGB. For linear sRGB with Rec.709 primaries, choose the linear option. The node does not interpret ICC profiles or convert ACEScg/log images.

**Match Photoshop 8-bit steps** defaults on: intermediate filtered values and luminosity values are rounded to byte levels. Disable it for continuous floating-point processing; this mode is not claimed to match Photoshop's higher-bit-depth paths.

**Pre-Divide / Post-Multiply** defaults on for premultiplied RGB; disable it for straight RGB. Alpha and hidden RGB at zero alpha are retained. Out-of-range RGB residuals are preserved as a Fusion-specific extension.

## Installation

Copy `PSN_PhotoFilter.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press **Shift+Space** and search **PSN_PhotoFilter**. Registry ID: `Fuse.PSN_PhotoFilter`. No Python or MCP is required to use the node.

## Method and validation

Filtering uses sRGB linearization, Bradford-adapted XYZ D50 component attenuation, conversion back to RGB, and an optional SetLum/ClipColor luminosity restoration. It is a calibrated approximation, not a normal color-overlay blend.

Tested in Fusion Studio 20.0.0.50 against Photoshop 27.2.0 with 24 cases: six custom colors, Density 25/100, and Preserve Luminosity off/on. The fixture has 16,384 pixels containing gray/red ramps and random colors. Maximum observed RGB difference was **1/255 with Preserve Luminosity off** and **6/255 with it on**, principally at gamut boundaries. Exact equivalence is not claimed for other colors, profiles or bit depths.

Additional checks passed for defaults, preset/swatch synchronization, automatic Custom selection, reopening a custom color and migration from the old Filter/Color interface, alpha preservation, linear-sRGB processing, density-zero bypass and Preview bypass. Reports: [Photoshop comparison](../validation/photofilter-results.json) and [behavior results](../validation/photofilter-behavior-results.json).

To try the effect, connect an image and select a filter. Edit the swatch below the dropdown to switch automatically to Custom.

## References

- [Adobe: adjusting colors with Photo Filter](https://www.adobe.com/us/learn/photoshop/web/adjust-correct-color-balance-photoshop)
- [Seth A. Robinson's Patchy calibration research](https://github.com/SethRobinson/Patchy/blob/main/docs/adjustment-kinds.md), MIT licensed; notice embedded in the Fuse and retained in [MIT notice](../third-party/Patchy-MIT.txt).

Independent implementation; no Adobe source code is included.

