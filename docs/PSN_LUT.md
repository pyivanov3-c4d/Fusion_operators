# PSN_LUT

Photoshop-style **Color Lookup** for Fusion: applies a 3D LUT to the image from the free film packs,
and from Photoshop's own Color Lookup presets.

## Controls

- **Category** — the LUT folder's subfolders become categories: **All LUTs**, **Photoshop**,
  **Slay**, **B&W**, **Slide**, **X-Trans**, **Instant**, **Instant Pro**, **Neg Colour**,
  **Neg New**, **Neg Old**, **Print**, plus **User** when the user LUTs folder has files. The LUT menu below shows only the
  chosen category, so picking is a short list instead of 300 entries. Switching category applies
  that category's first LUT.
- **LUT** — the LUTs of the chosen category, or the full flat list (`film/bw/...`,
  `film/print/...`, `slay-...`) under **All LUTs**. The first entry, **(file below)**, means "use
  the file field".
- **LUT file** — always shows the LUT that is in use. Type or browse for a `.cube`, `.3dl` or
  `.look` anywhere on
  disk; the menu switches to **(file below)**. Choosing a menu entry writes that entry's path
  here.
- **Mix (%)** — 0–100, default **100**. Blended in the LUT's own encoding, between the original
  value and the LUT result.
- **Preview** — bypasses the node.
- **Fusion Options** (collapsed)
  - **Input encoding** — *Display-referred (values as supplied)* is the default and matches
    Photoshop on 8-bit sRGB material. *Linear* encodes the image to sRGB with the sRGB transfer
    curve, applies the LUT and decodes back; use it in a linear-light comp.
  - **Interpolation** — **Tetrahedral** (default) or **Trilinear**. On the 13³ pack LUTs the two
    differ by up to 8 levels; on the 33³ slay LUTs by at most 1 level in the tested material.
  - **Preserve over-range** — default on. HDR and negative values keep their excursion instead
    of being clipped at the LUT's edge; only visible in a float comp.
  - **Pre-Divide / Post-Multiply** — default on for premultiplied RGB. The LUT is applied to
    unpremultiplied colour and alpha is untouched.
- **LUT library** (collapsed)
  - **LUT folder** — scanned when Fusion starts. Default
    `C:\__Work\_DeepSeek\Fusion\luts`; the user's
    `%APPDATA%\Blackmagic Design\Fusion\LUTs` is scanned too and listed as `user/...`.
  - **Reload LUT** — re-reads the selected file after it changed on disk.

Default: **slay-04-film** (33³ film look), Mix 100, tetrahedral.

## LUT library

| Folder | Files | Category |
| --- | --- | --- |
| `slay-*.cube` | 5 | Slay |
| `film/bw/` | 25 | B&W |
| `film/colorslide/` | 26 | Slide |
| `film/fujixtransiii/` | 15 | X-Trans |
| `film/instant_consumer/` | 54 | Instant |
| `film/instant_pro/` | 68 | Instant Pro |
| `film/negative_color/` | 13 | Neg Colour |
| `film/negative_new/` | 39 | Neg New |
| `film/negative_old/` | 44 | Neg Old |
| `film/print/` | 12 | Print |

Sources: [slaycamera/luts](https://github.com/slaycamera/luts) (CC BY 4.0) and
[Yahia Angelo's film LUTs](https://github.com/YahiaAngelo/Film-Luts) (G'MIC emulations).
See `luts/ATTRIBUTION.txt` for the licences. Both packs are display-referred, so the
default encoding applies them to the values Fusion supplies.

The list is built at startup. Add files to the folder and restart Fusion to see them; a single
LUT outside the folder can be used immediately through **LUT file**.

## Photoshop presets

**Photoshop** lists the 27 Color Lookup presets that ship with Adobe Photoshop:
`C:\Program Files\Adobe\Adobe Photoshop <version>\Presets\3DLUTs` — 10 `.cube`, 10 `.3dl`
and 7 `.look` files (2Strip, 3Strip, Bleach Bypass, Candlelight, Crisp_Warm, Crisp_Winter,
DropBlues, EdgyAmber, FallColors, filmstock_50, FoggyNight, the Fuji and Kodak looks by Adobe,
FuturisticBleak, HorrorBlue, LateSunset, Moonlight, NightFromDay, Soft_Warming,
TealOrangePlusContrast, TensionGreen).

The folder is found automatically (the newest `Adobe Photoshop *` install is used) and read in
place: the presets are Adobe's assets and are never copied or redistributed with this operator.
Without Photoshop the category is simply absent.

`.look` is XML; the look is read from the 3D table embedded in the file (8³, 16³ for
FallColors). The shader block that Photoshop stores next to it is not evaluated, so a `.look`
can differ from Photoshop's own live rendering of the same file.

## Format support

- 3D `.cube` (`LUT_3D_SIZE`), 1D `.cube` (`LUT_1D_SIZE`), and a file carrying both (1D stage
  first, then the cube, as the spec orders them).
- `DOMAIN_MIN` / `DOMAIN_MAX` and `LUT_3D_INPUT_RANGE`; `.cube` red-fastest value order.
- `.3dl` (Lustre/Flame text mesh: 17³ grid line, integer triples, mesh and 3DMESH headers,
  12-bit data in Adobe's files).
- `.look` (Photoshop XML with a hex-encoded little-endian float32 table).
- Not supported: `.spi1d`, `.asv` presets, ICC profiles, log/ACES conversions.

## Method

The table is parsed once per file and cached for the session. Per pixel: clamp to the table domain,
optional sRGB transfer, interpolate (tetrahedral by default), blend with Mix, clip the table result
to 0-1 (an integer image wraps on overshoot such as a `.look` entry at 1.03), optional transfer
back, restore any over-range residual, re-apply alpha. Processing is multithreaded through
`MultiProcessPixels`.

## Validation

Tested in Fusion Studio 20.0.0.50 against an independent numpy implementation of the same
definition (3D parse, domain, tetrahedral/trilinear, mix, transfer), rendering a 256×64 colour
chart:

| Case | Max | Mean |
| --- | --- | --- |
| passthrough (no LUT) | 0/255 | 0.00 |
| slay-04-film, tetrahedral | 1/255 | 0.50 |
| slay-04-film, trilinear | 1/255 | 0.50 |
| slay-04-film, Mix 50 | 1/255 | 0.51 |
| agfa_apx_100 (13³) | 1/255 | 0.50 |
| kodak_2383_cuspclip (13³), tetra / trilinear | 1/255 | 0.50 / 0.51 |
| slay-01-amber (33³) | 1/255 | 0.43 |
| missing file (bypass) | 0/255 | 0.00 |
| linear mode | 1/255 | 0.49 |

The residual half-level is the 8-bit write (the reference rounds, Fusion truncates). Reports:
`tests/lut/results.json`; renders in `renders/lut/cases/`.

Photoshop presets, same chart, read in place from the Adobe install:

| Case | File | Table | Max |
| --- | --- | --- | --- |
| ps_look_2strip | 2Strip.look | 8³ | 1/255 |
| ps_look_fallcolors | FallColors.look | 16³ | 1/255 |
| ps_3dl_dropblues | DropBlues.3DL | 17³ | 1/255 |
| ps_3dl_moonlight | Moonlight.3DL | 17³ | 1/255 |
| ps_cube_kodak5218 | Kodak 5218 Kodak 2383 (by Adobe).cube | 21³ | 1/255 |

Report: `tests/lut/photoshop-results.json`; renders in `renders/lut/photoshop/`.

Behaviour checks, all passing with a clean console:

- category menu: **Slay** applies slay-01-amber, **B&W** entry 5 applies ilford_delta_100, and typing
  a path in **LUT file** returns the menu to (file below); all four category renders are within
  1/255 of the reference;
- a saved composition reopens with its category and pick (identical render, 0/255);
- premultiplied vs straight alpha — the LUT reads unpremultiplied colour and alpha survives;
- HDR over-range kept (32,38,44) against clipped (6,12,19) in a float32 chain;
- 1D `.cube` (256-entry invert) exact;
- `DOMAIN_MAX 2` cube maps input 1.0 to mid-grey;
- Preview off and Mix 0 are exact passthrough;
- combo selection loads the chosen file and writes its path into the file field;
- a missing or unreadable file leaves the image untouched and reports once in the console.

Local demo: `PSN_LUT-Demo.comp` (Loader → PSN_LUT → Saver, slay-04-film).

## Limits

- About 0.4–1.0 s per 1.5 MP frame on this machine (Lua per-pixel processing).
- The menu reflects the folder at startup, not live changes.
- 1D-only and mixed 1D+3D files are supported, but the bundled packs are all 3D.

## Installation

Copy `PSN_LUT.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press
**Shift+Space** and search **PSN_LUT**. Registry ID: `Fuse.PSN_LUT`. No Python or MCP is needed
to use the node.

## References

- [Adobe: Color Lookup adjustment](https://helpx.adobe.com/photoshop/using/adjusting-color-lookup.html)
- [slaycamera/luts](https://github.com/slaycamera/luts) — CC BY 4.0
- [YahiaAngelo/Film-Luts](https://github.com/YahiaAngelo/Film-Luts) — MIT repository, LUTs shared for creative and educational use
- [G'MIC film emulation presets](https://gmic.eu)

Independent implementation; no Adobe code is included.
