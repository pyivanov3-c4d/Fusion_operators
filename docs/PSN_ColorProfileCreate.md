# PSN_ColorProfileCreate (profile format v5)

Builds a reusable, brand-neutral colour-style profile (`*.psncol.json`) from finished reference images. `PSN_ColorProfileMatch` applies it to any other image. Nothing is tied to one brand: a style is data in the file.

## What a profile stores
- **Chroma per luminance band**: mean of CIELab `a`/`b` for each band, plus the global colour spread.
- **Tonal distribution** (`p`): the share of pixels in each band, used for histogram tone matching.
- **Tonal range**: pooled black and white points.
- **Hue gamut** (v5): how populated each 15° hue sector is, and the chroma the style rarely exceeds (85th percentile) per hue sector and lightness zone (dark / mid / light). This is what lets the matcher turn hues the style never uses (e.g. cyan) into the nearest hue it does use, and limit saturation per hue.
- **Palette** (optional): *anchor* colours (`snap`) and *accent* colours (`hold`).

It is not a LUT: only target statistics are stored, so the matcher adapts to each incoming image.

## Workflow for a new brand / style
1. Connect 3–16 finished photos to Ref 1…16 (flat swatch sheet optional on Palette Image).
2. Optional: type the brand colours as hex in **Anchor Colours**, brand accents in **Accent Colours**.
3. Set **Profile File**, press **Build Profile**.
4. Check the `<name>.png` preview next to the JSON (ramp, band swatches, palette strip).
5. Point `PSN_ColorProfileMatch` at the JSON.

## Parameters
- **Ref 1…16 / Weight** — every reference contributes its weight in total, whatever its pixel size (a big image cannot outvote a small one). 0 disables it.
- **Palette Image** — optional swatch image; distinct chromatic colours (≥1 % of its chromatic area) are read as anchors. Neutrals are ignored.
- **Profile Name** — free text stored in the file.
- **Anchor Colours (hex)** — brand colours; the matcher rotates nearby hues onto them.
- **Accent Colours (hex)** — colours the matcher never restyles. Their pixels are also kept out of the statistics so a small accent cannot skew a band.
- **Luma Bands** (4–64, default 16), **Min Pixels per Band** (default 512; sparse bands are interpolated), **Sample Frame**.
- **Auto Rebuild** — off by default. Off: the file is only written when **Build Profile** is pressed. On: also rewritten when settings or the reference set change; it refuses to overwrite a profile that had more references.
- **Profile File** — empty = `colorprofiles/profile.psncol.json` next to the comp; `Comp:` and other aliases work. The file is written to a temp file and swapped in.

If no palette is given, the palette already stored in the file is kept (and reported in the console).

## Profile file (v4)
`format`, `version` (5), `name`, `created`, `space`, `sample_frame`, `bins`, `min_bin_pixels`, `refs[]`, `global` (black, white, mean/std of L/a/b), `luma[]` (per band: `t`, `n` raw samples, `p` share, `L`, `a`, `b` as `[mean, std]`), `hue` (`sectors`, `zones`, `cap_pct`, `dens[]`, `cap1..3[]`, `n1..3[]`), `palette[]` (`hex`, `mode`, `L`, `a`, `b`). L is 0–1; a/b are Lab units /100. v3 and v4 files still load in the matcher (without the hue features).

## Changes from v3
- Per-reference normalisation (v3 weighted by sample count: two large images were 34 % of a 9-image pool).
- Accent pixels excluded from statistics (v3: a red object tripled the a-spread of one band).
- Transparent pixels ignored; straight colour recovered from premultiplied input.
- Palette from exact hex or Lab clustering (v3 hue-binning merged mid blue into blue and kept anti-aliased edge colours).
- No auto-overwrite on comp open; no hardcoded developer paths or log files.
- Lab→sRGB inverse fixed near black (preview only).

## Install
Copy to `%PROGRAMDATA%\Blackmagic Design\Fusion\Fuses\`, restart Fusion. Registry ID `Fuse.PSN_ColorProfileCreate`, category **PSN / Color**. Inputs `Ref1…Ref12` keep their IDs; `Ref13…16` are new.

## Validation
Executed in LuaJIT 2.1 with a mocked Fusion API (inputs, Pixel, Image) on 9 reference photos. **Not yet run inside Fusion itself** — test the Build button and the file dialog there first.
