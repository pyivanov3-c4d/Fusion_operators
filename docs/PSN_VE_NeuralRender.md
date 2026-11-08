# PSN_VE_NeuralRender

Fusion 20 operator that runs DLSS 5 Neural Rendering from the
[Visual Enhancer](https://github.com/Merserk/dlss5-visual-enhancer) engine (`VE_CLI.exe`)
on the current frame, plus a bake script that processes a whole shot in one engine pass.

## Install

| File | Goes to |
| --- | --- |
| `PSN_VE_NeuralRender.fuse` | `%APPDATA%\Blackmagic Design\Fusion\Fuses\` |
| `PSN_VE_Update.lua` | `%APPDATA%\Blackmagic Design\Fusion\Fuses\` |
| `PSN_VE_Bake.lua` | `%APPDATA%\Blackmagic Design\Fusion\Scripts\Comp\` |
| `VERSION` | `%APPDATA%\Blackmagic Design\Fusion\Fuses\` |

Restart Fusion. The tool appears as **PSN_VE_NeuralRender** (Tools → Fuses → PSN → Neural;
scripting id `Fuse.PSN_VE_NeuralRender`); the bake action appears in the Scripts menu.

Visual Enhancer must be installed separately — its licence does not allow bundling it here.

## Updates

The **Update** page has *Update source*, *Apply parameters*, *Auto update* and
**Check for updates**.

`Check for updates` reads `<Update source>\VERSION`, compares it with the installed
version, and — if the source is newer — copies `PSN_VE_NeuralRender.fuse`,
`PSN_VE_Update.lua`, `PSN_VE_Bake.lua` and `VERSION` into place, then shows a Windows
message box ("Updated from X to Y — restart Fusion"). Equal versions report
"up to date"; an older source is refused.

The source is a folder, by default this package folder. To publish a build: bump
`VERSION`, copy the four files there, and every installation picks it up on the next check.

## Parameters

Pages, left to right: **Neural, Post, Algorithm, Engine, Update, Cache, Setting**.

| Page | Control | Engine setting |
| --- | --- | --- |
| Engine | VE_CLI.exe | executable path |
| | Cache folder | temp TIFFs, results, log |
| | GPU | `--gpu` (auto / index / UUID) |
| | sRGB transfer | 16-bit sRGB ↔ linear conversion around the engine |
| Algorithm | Algorithm | which engine command runs — see below |
| | AI upscale model | VisionNext / RazorNext / PeakMagnetar / OptiMagnetar / TinyMagnetar |
| | Scale | 1× / 2× / 4× / 6× / 8× (AI upscale and RTX) |
| | DLSS SR mode | DLAA / Quality / Balanced / Performance / Ultra Performance |
| Neural | Style | `nr_style` Style 0/1/2 (3 is all the DLSS 5 engine exposes) |
| | Intensity | `nr_intensity` 0–2 |
| | Passes | `nr_passes` |
| | Local tone | `local_tone_strength` |
| | Local structure | `local_structure_strength` |
| | Skin structure | `skin_structure_strength` |
| | Automatic mask | `automatic_mask` |
| Post | Sharpening (CAS) + amount | `cas_sharpening` / `cas_sharpness` |
| | Grain + amount | `grain` / `grain_amount` |
| Cache | Baked result folder | frames produced by the bake script |
| | Collect input frames | used by the bake script only; leave off |

### Algorithms

| Selection | Command | Notes |
| --- | --- | --- |
| Neural Rendering (DLSS 5) | `render` | 3 styles, intensity, passes, tone/structure/skin, auto mask |
| AI Upscale (model) | `upscale --engine <model>` | changes resolution; models download on first use |
| RTX Super Resolution | `upscale --engine rtx --scale N` | changes resolution |
| DLSS Super Resolution | `upscale --engine dlss --mode <mode>` | DLAA = 1× |
| Ray Reconstruction | `reconstruct` | native 1× |

### Update behaviour

There is no staging: any parameter change re-renders the node, and a changed
parameter set means a new cache key, so the engine runs once per distinct setting
and every repeat view of the same frame + settings is instant.

## Known limits

- **Not realtime without baking.** One engine process per uncached frame.
- **Painted control masks are unreachable** from the CLI (presets drop `nr_mask`);
  only Automatic mask is exposed.
- **Colour residual:** ~2/255 mean difference against the engine's own output
  (p99 ≈15 levels) from the Fusion↔sRGB round trip. Toggle *sRGB transfer* off if your
  comp works display-referred.
- Windows + NVIDIA only; 32,768 px per side.
