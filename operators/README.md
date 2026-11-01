# PSN_SelectiveColor for Fusion

Version 1.0 — created for Pavel, tested in standalone Fusion Studio 20.0.0.50 on Windows.

## Use

Press Shift+Space in Fusion and search **PSN_SelectiveColor**. The tool is also registered under **PSN / Color**. Connect an image to its Input.

1. Choose **Colors**: Reds, Yellows, Greens, Cyans, Blues, Magentas, Whites, Neutrals or Blacks.
2. Adjust **Cyan, Magenta, Yellow, Black**, each from -100 to +100 percent.
3. Select **Relative** (default) or **Absolute**.
4. Switch to another family to edit it. All nine families keep independent values and contribute to the result together. Switching the menu does not limit processing to the currently displayed family.
5. Toggle **Preview** for before/after. Fusion's normal Settings tab supplies Blend and mask controls.

Use Fusion's standard per-control reset or the tool's reset command. The node starts with all adjustments at zero. Native Fusion presets/settings can store the entire node; Photoshop .asv preset import is not included.

The interface follows Photoshop's Colors menu and four-slider layout using native Fusion controls. Relative/Absolute are two adjacent buttons rather than Photoshop's radio buttons. A collapsed Fusion Options section contains compositor-specific options. Edit/Reload and the Settings/Comments tabs are supplied by Fusion itself.

Open `../SelectiveColor-Demo.comp` for a color chart connected to a neutral instance. The original is assigned to viewer 1 and the node to viewer 2. Try Reds / Cyan +60 / Absolute, then toggle Preview.

## Color and alpha

Selective Color uses CMYK-named adjustments on RGB channel values; it is not an HSL editor and does not convert the image to a printer CMYK profile.

**RGB as supplied (Photoshop-style)** is the default. For closest Photoshop correspondence, feed the node the same RGB values in the same working color space as the Photoshop document. Matching viewer displays alone is insufficient if one application's processing is linear and the other's is gamma encoded. No ICC conversion is performed automatically.

For linear sRGB/Rec.709-primary images, select **Linear sRGB / Rec.709 primaries**: the node applies the sRGB transfer curve, performs the adjustment, and converts back. This is not an ACEScg, log, or generic Rec.709-camera conversion. Convert those spaces explicitly before/after this node.

**Pre-Divide / Post-Multiply** defaults on for premultiplied compositing images. Disable it for straight-alpha RGB. Alpha itself remains unchanged. Fully transparent premultiplied pixels pass through unchanged. Fusion Background can produce unassociated RGB, so set its RGB consistently with the chosen alpha convention.

The Photoshop-style calculation is defined for SDR values 0–1. For floating-point images, this implementation preserves the out-of-range residual and adjusts only the bounded portion. This is a deliberate Fusion extension, not a claim of Photoshop HDR equivalence. All-zero settings and Preview off return the original image directly.

## Implementation and validation

The Lua Fuse uses multithreaded CPU processing; there is no custom GPU kernel in this version. Sliders can be animated independently. The Colors menu itself is a passive display selector.

The normalized mathematical model is implemented from Clément Bœsch's published research. Family weights use the original pixel's minimum, median and maximum, with separate white/neutral/black weights. Each family's bounded RGB deltas are computed from its CMYK settings and the global Relative/Absolute mode; deltas are summed before final SDR clamping. Families are not applied sequentially to already-adjusted pixels.

Validation on this computer:

- Actual Fusion renders for 24 cases, each with 8,192 test pixels, including randomized colors, neutral boundaries, primaries/secondaries, and the published RGB 180/100/50 example.
- Compared against the installed FFmpeg selectivecolor implementation: at most 1/255 difference for individual families, at most 3/255 for the tested combined extreme settings. Floating-point processing versus integer per-family rounding explains small discrepancies; this is not an exact Photoshop certification.
- Identity and Preview bypass were exact at the tested 8-bit output precision.
- All nine menu states expose exactly the intended four adjustment sliders.
- Saved/reopened compositions preserve selected family and adjustment values.
- Premultiplied half-alpha and opaque fixtures give the same unassociated adjusted RGB, with alpha retained; zero-alpha fixture remains transparent.
- Linear-sRGB conversion checked against a numerical reference.

No current Photoshop executable was used for direct image comparison. Comparing a Photoshop export and its exact settings/working profile is the next step for refining any version-specific differences.

Detailed render comparisons: `../tests/validation-results.json`. Reproducible fixtures and test scripts are in `../tests/`.

## Files

- Source: `C:\Users\Pavel\Documents\ChatGPT\Fusion\operators\PSN_SelectiveColor.fuse`
- Installed: `C:\Users\Pavel\AppData\Roaming\Blackmagic Design\Fusion\Fuses\PSN_SelectiveColor.fuse`
- Registry ID: `Fuse.PavelSelectiveColor`

To install on another standalone Fusion machine, copy the single .fuse file to the user's Fusion Fuses directory and restart Fusion. For development updates, copy the updated source over the installed file and use the node's Reload button; registration changes require a restart. This package does not require Python or MCP to process images after installation.

## Sources

- Adobe's Selective Color behavior and interface: https://helpx.adobe.com/photoshop/desktop/adjust-color/selective-color-adjustments/make-selective-color-adjustments.html
- Mathematical research by Clément Bœsch: https://blog.pkh.me/p/22-understanding-selective-coloring-in-adobe-photoshop.html
- Independent test oracle: https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_selectivecolor.c
- Blackmagic Fuse API: https://documents.blackmagicdesign.com/UserManuals/Fusion_Fuse_SDK.pdf

This is an independent Photoshop-style tool, not an Adobe product. No Adobe code is included.
# Selective Color UI update (1.1)

The Colors dropdown is now a native single-row selector: **R Y G C B M W N K**, with full family names in tooltips. These are Fusion's standard letter buttons, not custom colored rounded swatches. Slider labels are **Red/Cyan**, **Green/Magenta**, **Blue/Yellow**, and **White/Black**. Photoshop's existing value direction is unchanged: negative moves toward the first named color (left); positive adds the second named color (right).

The internal registry and input IDs remain unchanged, preserving existing compositions and adjustments. Saved family selections restore their matching visible sliders. Existing instances can use the Fuse's **Reload** button; newly added nodes use the updated interface.


