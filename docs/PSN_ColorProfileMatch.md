# PSN_ColorProfileMatch

Applies a profile written by `PSN_ColorProfileCreate` (v5; v3/v4 load without the hue features) to an image. Brand-neutral: cast, tonal distribution, range and palette all come from the profile.

The operator measures the incoming image per luminance band and moves it toward the profile:

```
chroma : a' = (a − src_mean)·gain + src_mean + (tgt_mean − src_mean)·Cast
tone   : histogram match to the profile's tonal distribution, soft-limited, blended by Tone Match
```

## Parameters
**Main controls (what you normally touch)**
- **Strength** — mix with the source image.
- **Colour** (default 1) — master amount of the colour restyle: cast, hue pull/gather, chroma limit and saturation together. 0 leaves colour untouched.
- **Tone** (default 1) — master amount of the tonal restyle. 0 keeps the source tone curve exactly.
- **Skin Protect** (default 0.5) — pulls skin-like hues back toward the source colour.

Everything below lives in the collapsed **Advanced** and **Palette** groups. The defaults are calibrated; Colour and Tone scale them together, so you rarely need to open them.

**Match**
- **Strength** — mix with the source (0 = passthrough).
- **Tone Match** (default 0.25) — how far luminance moves to the profile's tonal distribution and black/white points. 0 keeps the source tone curve exactly. Note: this also pulls the white point toward the profile's, so lower it if you need pure white.
- **Max Tone Shift** (default 0.15) — soft limit on any tone move, protecting images dominated by one flat area.
- **Cast Strength** (default 0.85) — how much of the profile's colour cast is applied. 1 = full band-mean match; 0 = only colour spread is matched. Heavily cast inputs (e.g. warm tungsten) need values near 1.
- **Hue Pull** (default 0.8) — rotates hues the style never uses (e.g. cyan) toward the nearest hue it does use (e.g. cold blue). **Hue Pull Range** (default 60°) is the largest rotation; farther hues are only desaturated.
- **Hue Gather** (default 0.6) — pulls every hue toward the dominant hue of its neighbourhood in the style, so all bluish tones converge on the style's one cold blue instead of staying where the photo put them. Hue Pull only handles hues the style never uses; Gather handles the rest.
- **Chroma Limit** (default 0.85) — pulls saturation down toward what the style reaches for that hue and lightness (85th percentile of the references). **Limit Lightens** (default 0.8) makes light tones lighter as they are desaturated (tint toward white, not grey).
- **Match Saturation** — whole-image chroma gain from the profile spread, clamped 0.6–1.5.
- **Neutral Protect** (default 0.5) — shields near-neutral pixels (white walls, greys) from the colour shift. Lower it if the style tints neutrals.
- **Skin Protect** (default 0.5) — pulls skin-like hues (Lab hue ≈ 12–82°, mid chroma) back toward the source. Set 0 if the style should restyle skin, 1 to leave skin untouched.
- **Preserve Luminance** — chroma only.

**Palette** (from the profile)
- **Palette Hold** (default 1) — content near a palette colour keeps its source colour and tone. *Anchors* are held when close in Lab (**Colour Tolerance**, default 12); *accents* are held for any shade of their hue (**Hue Tolerance**). Hue Pull and Chroma Limit also leave held pixels alone.
- **Palette Snap** (default 0.5) — content near an *anchor* colour is rotated onto its hue (lightness-gated).
- **Hue Tolerance** (default 30°), **Protect Saturated** (blunt, off).

**Fusion Options** — Analysis Samples (60000), Clamp Output, Pre-Divide / Post-Multiply.

Removed: *Match Contrast* (it never changed tone; replaced by Tone Match).

## Behaviour notes
- Source band statistics need enough samples; gaps are interpolated and the means smoothed across bands (no chroma banding along luminance).
- Accent pixels are excluded from the source statistics, mirroring the Create operator.
- With Tone 0, Cast 0, Saturation off, Skin 0, Hold 0, Snap 0 the node is an identity (max error 0.0002).
- sRGB-referred like the profile. Feeding log or scene-linear frames gives a meaningless result.
- About 0.5 s for a 600×400 frame in the test harness; expect a few seconds for 2K. Porting the per-pixel pass to a GPU kernel is the next step for long video.

## Why a saturated sky used to stay untouched
Anchor protection was hue-based: a vivid blue sky (chroma 36) counted as "near" a pale brand blue (chroma 15) and was restored to its source colour, so nothing happened. Anchors are now held by Lab distance, and the hue gamut (Hue Pull / Chroma Limit) restyles everything else. On the stock warehouse photo this moves the sky from L68/C36 to L73/C23 (in-style version: L79/C20) and adds the cool tint to the wall and ground.

## Fixes from the previous version
- Lab→sRGB inverse lacked the linear segment near black: pure black came back ≈ 9/255 grey.
- Palette protection dulled the guide red (chroma 65.6→52.3); now 65.6→67.3.
- Skin hue rotation by >20°: 78–100 % of skin pixels in 3 of 8 portraits → 0–14 %.
- Tone and black/white points from the profile were never applied.

## Install
Copy to `%PROGRAMDATA%\Blackmagic Design\Fusion\Fuses\`, restart Fusion. Registry ID `Fuse.PSN_ColorProfileMatch`, category **PSN / Color**.

## Validation
Executed in LuaJIT 2.1 with a mocked Fusion API against 9 guide photos, warm-cast variants and a synthetic studio scene. **Not yet run inside Fusion itself.** Measures tone, accent chroma, skin shift, highlights and identity; it does not claim ΔE accuracy against the references — the target is a consistent look.
