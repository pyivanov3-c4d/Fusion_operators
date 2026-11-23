# PSN_ColorLighting

Photoshop's **Light** adjustment layer (Photoshop 27.10+, 28.0.0 on this machine) for
Fusion: Exposure, Contrast, Highlights, Shadows, Whites, Blacks - one node, six sliders,
measured against the real thing.

Category: `Effects > PSN > Color - Lighting`
Registry ID: `PSN_ColorLighting` (tool `Fuse.PSN_ColorLighting`)

## Why it is measured, not ported

There is no SDK, no public algorithm and no documented formula for the Light adjustment
layer. Adobe ships it as UI only:

- the Photoshop C++ SDK has no Light class;
- UXP `LayerKind` has no `LIGHT` value and the API changelog has no 27.10 entry;
- the cloud API's `AdjustmentLayer` only knows brightnessContrast, exposure,
  hueSaturation and colorBalance;
- there is no Camera Raw engine SDK.

The only exposed surface is the Action Manager descriptor. A Light layer is a
`brightnessContrast` adjustment whose `adjustment` object carries
`brightnessMode = brightnessModeLight` plus `brightnessExposure` (double),
`center` (Contrast), `brightnessHighlights`, `brightnessShadows`, `brightnessWhites`,
`brightnessBlacks`. That is enough to drive Photoshop and measure it, which is how the
curves in this fuse were obtained.

Practical notes for anyone scripting it on Photoshop 28: Action Manager descriptors must
be built with string IDs (`stringIDToTypeID`); classic four-character IDs
(`charIDToTypeID`) are rejected with "Illegal Argument", and `DescValueType.*` constants
throw on read. A `set` that omits `brightnessMode` silently converts the layer to plain
Brightness/Contrast.

## Calibration

Measured on this machine, Photoshop 28.0.0, 8-bit sRGB, no layer mask, Auto untouched:

- a 256 x 256 chart (neutral ramp, hue sweep, primaries, 4 px bars, soft edge, small
  clipped block), exported as PNG for each setting;
- 31 single-slider renders (Exposure -0.5 ... +/-4; Contrast, Highlights, Shadows,
  Whites, Blacks at +/-25, +/-50, +/-100) plus 9 multi-slider renders;
- 36 curves of 33 knots each (encoded 0..1), composed in the order
  `whites -> shadows -> highlights -> exposure -> blacks -> contrast`, the best of all 720
  permutations against the multi-slider renders.

Agreement with Photoshop on the neutral ramp:

| Case | Mean error | Worst pixel |
|---|---|---|
| Exposure +/-0.5 ... +/-4 (8 cases) | 0.2 ... 1.0 /255 | 3 /255 |
| Contrast / Highlights / Shadows / Whites / Blacks at +/-50, +/-100 | 0.8 ... 1.5 /255 | 4 /255 |
| Exposure + Contrast | 0.96 /255 | 3 /255 |
| Contrast + Shadows | 1.41 /255 | 6 /255 |
| All six at once | 2.58 /255 | 6 /255 |
| Shadows + Highlights together | 14.6 /255 | ~40 /255 |

The last row is the known weak spot: Photoshop's Shadows and Highlights are neighbourhood
operators that overlap on the same tones and do not compose as two curves, while this node
is per-pixel. Everything else lands within a few 8-bit levels.

Rendered end-to-end through Fusion 20.0.0.50 on the calibration chart, Exposure +1 differs
from Photoshop by at most 3/255 (mean 1.07).

## Colour behaviour

Photoshop's Light layer works per channel in a wide working space and desaturates strongly
saturated colours (pure red at Exposure +1 becomes 255,63,63; pure cyan becomes
186,255,255). No published model reproduces that, so this node offers both ends:

- **Each channel (Photoshop-style)** - the default; matches the measured curves exactly on
  neutrals and keeps per-channel punch;
- **Luminance, hue preserved** - scales RGB by the luma ratio, so saturated colours keep
  their hue instead of desaturating; more natural on graphics and CG passes.

Neither mode claims to reproduce Photoshop's gamut handling: on saturated primaries both
stay more saturated than Photoshop does.

## Controls

| Control | Range | Default | Notes |
|---|---|---|---|
| Exposure | -5 ... +5 | 0 | stops, linear-light gain; +/-4 measured, beyond that the edge curve is stacked with a linear gain |
| Contrast | -100 ... 100 | 0 | pivot S-curve |
| Highlights | -100 ... 100 | 0 | upper-range recovery/lift |
| Shadows | -100 ... 100 | 0 | lower-range open/deepen |
| Whites | -100 ... 100 | 0 | white end |
| Blacks | -100 ... 100 | 0 | black end |
| Preview | on/off | on | bypass |
| Input encoding | RGB as supplied / Linear sRGB | as supplied | the linear option converts to sRGB for the adjustment and back; not an ACES transform |
| Apply to | Each channel / Luminance | each channel | see above |
| Pre-Divide / Post-Multiply | on/off | on | unpremultiply, adjust, restore alpha |

All six sliders at 0 is a true bypass: output is bit-identical to input (verified).
Out-of-range values (HDR above 1.0, negatives) keep their residual: the adjustment is
clamped internally like an SDR operation, but untouched headroom is not clipped.

## Verification

- Identity render equals the source chart pixel for pixel.
- Exposure +1 against Photoshop: max 3/255, mean 1.07/255.
- Six sliders together against Photoshop: max 6/255, mean 2.58/255.
- Renders clean in Fusion 20.0.0.50, no node error, icon loads (32 x 32, #828282 glyph).
- Tested in a scratch comp `Composition1` that was left open for the session and closed
  without saving.

## Provenance

Calibration harness, measured PNGs and fit scripts live in the operator workspace under
`_cal/`: `gen_chart.py`, `psr_run.jsx`, `fit.py`, `emit_lua.py`, `build_fuse.py`.
Photoshop was driven through its COM scripting interface; the Light layer was created with
`make`/`set` Action Manager descriptors, never by hand.
