# Fusion operators

Custom Photoshop-style operators for Blackmagic Fusion, using the **PSN_** naming convention.

## PSN_CleanSharp

High Pass sharpening blended over the original using **Overlay**.

- **Radius:** 10 pixels by default.
- **Intensity:** 20% by default, adjustable from 0–100% as Overlay opacity.
- **Show High Pass** previews the intermediate detail image; **Preview** bypasses the effect.
- Preserves alpha, with optional pre-divide/post-multiply handling.

Download [PSN_CleanSharp.fuse](Fuses/PSN_CleanSharp.fuse), copy it to `%APPDATA%\Blackmagic Design\Fusion\Fuses\`, restart Fusion, then use **Shift+Space → PSN_CleanSharp**.

Compared with Photoshop 27.2.0: default settings differed by at most 1/255 per RGB channel on the test chart. This is a calibrated approximation; small-radius High Pass results can differ more. See the [usage guide and validation details](docs/PSN_CleanSharp.md).

## PSN_BrightnessContrast

Photoshop-style classic Brightness/Contrast with modern nonlinear curves, **Use Legacy**, and **Preview**. Includes premultiplied-alpha handling and optional linear-sRGB processing.

- Modern: Brightness -150 to +150; Contrast -50 to +100.
- Legacy: both sliders -100 to +100.
- Tested against Photoshop 27.2.0 across 28 settings: maximum difference of 1/255 per RGB channel in the tested 8-bit exports.
- Multithreaded CPU implementation. Auto adjustment and the newer Photoshop Light controls are not included.

Download [PSN_BrightnessContrast.fuse](Fuses/PSN_BrightnessContrast.fuse), copy it to `%APPDATA%\Blackmagic Design\Fusion\Fuses\`, restart Fusion, then use **Shift+Space → PSN_BrightnessContrast**. Python and MCP are not required.

See the [usage guide and validation details](docs/PSN_BrightnessContrast.md).

## PSN_SelectiveColor

A Lua Fuse that provides Photoshop-style Selective Color controls:

- Nine color families: Reds, Yellows, Greens, Cyans, Blues, Magentas, Whites, Neutrals, Blacks.
- Independent Cyan, Magenta, Yellow and Black adjustments from -100% to +100% for every family.
- Relative and Absolute modes, plus Preview bypass.
- Native Fusion animation, Blend and effect-mask controls.
- Optional linear-sRGB processing and pre-divide/post-multiply alpha handling.

### Install on Windows

1. Download `Fuses/PSN_SelectiveColor.fuse`.
2. Copy it to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` (create the folder if needed).
3. Restart Fusion.
4. Press **Shift+Space**, search **PSN_SelectiveColor**, and connect an image.

Tested in standalone Fusion Studio **20.0.0.50** on Windows. Python and MCP are not required to use the installed node. Other Fusion/Resolve versions and operating systems have not been validated.

If upgrading the earlier local development build, move `PavelSelectiveColor.fuse` out of the Fuses directory before installing this file, to avoid duplicate registration. The internal ID remains `Fuse.PavelSelectiveColor` for existing composition compatibility.

### Use

Select a family using the **R Y G C B M W N K** button row (Reds, Yellows, Greens, Cyans, Blues, Magentas, Whites, Neutrals, Blacks). Hover a button for its full name. Switching families preserves all other families' settings; all adjustments contribute to the image together. Relative is the default; Absolute generally produces stronger changes. Toggle Preview to compare with the original.

The sliders are labeled **Red/Cyan**, **Green/Magenta**, **Blue/Yellow**, and **White/Black**: negative values move toward the left-hand color, positive values toward the right-hand color. The original Photoshop value direction and saved input IDs are unchanged. Buttons use Fusion's native styling; custom colored lettering and rounded swatches are not included.

Version 1.1 also restores the selected family's visible sliders when reopening compositions. After replacing the Fuse, click **Reload** on existing nodes or restart Fusion.

For a simple check, an opaque RGB pixel of (180, 100, 50), with Reds / Cyan +60% / Absolute, becomes (132, 100, 50).

This is a selective RGB adjustment using CMYK-named controls, not an HSL editor or a printer-profile CMYK conversion.

### Working space and alpha

Use **RGB as supplied** for gamma-encoded RGB. To compare with Photoshop, use the same source RGB values and working color space. No ICC conversion happens automatically.

For linear sRGB with Rec.709 primaries, select **Linear sRGB / Rec.709 primaries**. This applies the sRGB transfer curve around the adjustment; it is not an ACEScg or log conversion.

**Pre-Divide / Post-Multiply** defaults on for premultiplied images. Disable it for straight-alpha inputs. Alpha remains unchanged. Out-of-range floating-point residuals are preserved as a Fusion-specific extension; Photoshop HDR equivalence is not claimed.

### Validation and limitations

24 actual Fusion render cases, with 8,192 pixels per case, were compared against FFmpeg's independent Selective Color implementation. Individual-family cases differed by at most 1/255; tested combined extreme settings differed by at most 3/255. Zero settings and Preview bypass were exact at tested precision. See the reports in `validation/`.

Additional checks covered the nine menu states, save/reopen persistence, half-alpha processing, zero-alpha processing, and a linear-sRGB reference calculation.

This version uses multithreaded CPU processing. It does not import Photoshop `.asv` presets. Direct pixel-for-pixel matching against a current Photoshop installation has not yet been performed.

### References

- [Adobe: Selective Color](https://helpx.adobe.com/photoshop/desktop/adjust-color/selective-color-adjustments/make-selective-color-adjustments.html)
- [Clément Bœsch: mathematical analysis](https://blog.pkh.me/p/22-understanding-selective-coloring-in-adobe-photoshop.html)
- [FFmpeg: independent comparison implementation](https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_selectivecolor.c)
- [Blackmagic: Fuse SDK](https://documents.blackmagicdesign.com/UserManuals/Fusion_Fuse_SDK.pdf)

Independent implementation; not affiliated with or endorsed by Adobe. No Adobe source code is included.

