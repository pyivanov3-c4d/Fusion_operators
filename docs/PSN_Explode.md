# PSN_Explode

Splits one image into four separate image outputs, one per channel, ready to be used as masks:

- **Input:** a single image.
- **Four separate output pins** on the node: **Red** is the main output on the right edge of the tile, **Green**, **Blue** and **Alpha** are the extra output squares along the bottom edge (in that order, left to right).
- **What each output carries:** the channel value goes into RGB *and* into the alpha channel. Mask inputs in Fusion (Effect Mask, Garbage Matte, Solid Matte, …) are driven by the alpha channel, so any output can be dropped straight onto a mask input of the next node — no Boolean, Bitmap or extra node in between.
- **Red** = R in RGB and in alpha, **Green** = G, **Blue** = B, **Alpha** = A. Values are copied exactly: nothing is clipped, unpremultiplied or recombined; out-of-range and negative values survive as-is.

## Install

Copy `PSN_Explode.fuse` **and** `PSN_Explode.png` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press **Shift+Space** and search **PSN_Explode** (category **PSN > Channel**). Registry ID: `Fuse.PSN_Explode`. No Python or MCP is needed to use the installed node.

## Icon

`PSN_Explode.png` is the bomb icon shown in the Effects Library and on the toolbar: 32×32, glyph about 20 px inside the canvas, drawn in Fusion's own icon grey (#828282) so it sits at the same brightness as the built-in tool icons. A lighter tone reads as "lit up" next to them.

Fusion only loads a custom icon through `REGS_IconID`, and only as an absolute file path, so the fuse resolves the path itself at load time: first next to the `.fuse` file, then `%APPDATA%\Blackmagic Design\Fusion\Fuses\PSN_Explode.png`, then `%APPDATA%\Blackmagic Design\Fusion\Icons\PSN_Explode.png`. If the PNG is missing the tool falls back to Fusion's default icon. Keep the PNG next to the fuse when installing or copying the operator.

## Typical use

- Drag **Red / Green / Blue / Alpha** onto the **Effect Mask** input of any downstream node to restrict it to that channel.
- Build a luma or channel matte, then use it for a key, a blur, a grade or a merge.
- Feed the **Alpha** output into a matte cleanup chain.

## Premultiplied note

Because the channel also sits in alpha, each output is a *premultiplied* image: grey where the channel is bright, transparent where it is black. Viewers show it correctly over black, but a node that unpremultiplies (most colour tools have Pre-Divide/Post-Multiply on) sees white, and a Saver without alpha writes white. That is the normal Fusion mask convention; for straight-image work, use the output as a mask or turn pre-divide off on the receiving node.

## Validation

Measured on Fusion Studio 20.0.0.50:

- Flow view shows four output squares on the node: one on the right edge and three along the bottom edge.
- A 128×128 fixture with different values per quadrant: Red output alpha 51 / 0 / 0 / 102, Green 0 / 128 / 0 / 153, Blue 0 / 0 / 204 / 51, Alpha 255 — i.e. each output's alpha carries that channel.
- A 1536×1024 photo matched its source channel values exactly (R=26, G=44, B=85 → Red 26, Green 44, Blue 85 in RGB and alpha).
- A cropped (DoD) input stayed aligned: a 64×64 crop of the fixture produced a 64×64 output with the same content position.
- No errors in the Fusion console for any of the renders above.

Fuse notes:

- Every output needs its own `LINK_Main` value (1, 2, 3, 4 …). Giving several outputs the same `LINK_Main` silently collapses them into a single pin in the flow view, even though the tool reports all of them through scripting.
- The four ports cannot be coloured or labelled: Fusion draws all output ports in the same grey and exposes no per-output colour (the tool colour is one value per node). Output identity comes from the port order and the hover tooltip.

## Limitations

- Processing is CPU-based and runs one full-frame pass per output, so a 4K plate is scanned four times.
- No mask input and no channel reordering: it is a pure splitter.
- Top-level only: it does not split Z, coverage, or object/material ID channels.
