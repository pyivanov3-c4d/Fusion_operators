# PSN_SplineArrange

Version 1.9 — created for Pavel, tested live in standalone Fusion Studio 20.0.0.50 on Windows.

PSN_SplineArrange is a particle-emitter-style generator: it makes copies of a Sample
image and distributes them along a **Shape mask/image**, an **open stroke mask**, or an
optional **Polyline path**. Fusion's Polygon, Ellipse, Rectangle, BSpline, and other
mask tools connect directly to the Shape input.

## Install and use

Copy `PSN_SplineArrange.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\`, restart
Fusion, then press **Shift+Space** and search **PSN_SplineArrange**. The tool is also
registered under **PSN / Generator**.

1. Connect a shape to **Shape** — the first input socket. Any Polygon, Ellipse, mask,
   open stroke, or image works. White/alpha defines the shape; a thin open stroke is
   traced along its centreline.
2. Connect the image to copy to **Sample** — the second input socket.
3. Optionally draw an open or closed **Path** in the Inspector; when present it
   overrides Shape. The path also accepts an animated/edited Polyline path value.
4. Set **Density**, **Color**, **Size**, and the other controls.
5. Use **Blending** to choose how overlapping copies composite.

The output frame size is the **Sample** image's frame size. If a different canvas is
needed, place a Resize or Merge after the node. An empty Shape, an empty/one-point
outline, or Density 0 produces a transparent image.

## Controls

| Control | Default | Meaning |
|---|---|---|
| Shape | unconnected | **Input 1**. Mask/image shape. White/alpha = inside. Closed masks use the outer contour; thin open strokes use their centreline. |
| Sample | unconnected | **Input 2**. RGBA image copied along the shape/path. The output uses this image's frame size. |
| Path (optional) | empty | Open or closed Polyline drawn in the Inspector. When it has 2+ points it overrides Shape. Open paths distribute copies from end to end. |
| Density | 100 | Number of copies distributed around the shape/path, 0–1000. |
| Color | 1,1,1,1 | General RGBA color. RGB is multiplied into every copy; Alpha acts as copy opacity. |
| Random Color | 0 | 0–1. Randomizes each copy's hue by tinting it with a random HSV color. 0 keeps the general color; 1 gives a fully random hue. |
| Size | 1 | General copy size relative to the Sample. |
| Random Size | 0 | 0–1. 0 = uniform; 1 = up to ±100% variation per copy. |
| Random Position | 0 | 0–1. Randomly offsets each copy sideways from the path along its normal (left or right). 1 = up to 20% of frame width. |
| Along Size | 1.0 each | Five-point size profile along the path: **Start**, **25%**, **50%**, **75%**, **End**. Each is a 0–1 multiplier; values are linearly interpolated. All default to 1.0 (full size everywhere). |
| Aligned | off | Rotates each copy to follow the path tangent, so copies bank around curves. |
| Blending | Normal | Normal, Additive, or Multiply. Additive uses Fusion's Linear Dodge merge mode; Multiply uses a white transparent internal backdrop so isolated copies keep their color. |

Randomization is deterministic per Density value (fixed internal seed), so a still frame
renders identically each time and animation does not flicker because of the random
color/size choices.

## Shape tracing

- Shape can be a Mask output or any Image. If the image's alpha varies, alpha is used;
  otherwise luminance is used.
- The threshold is 0.5. Soft mask edges are treated as inside above half coverage.
- If the mask covers most of the frame border (black shape on a white matte), the
  inside/outside polarity is automatically inverted.
- Closed/filled masks use the largest closed outline. Multiple disconnected shapes
  currently use the largest region; a single shape is the intended use.
- Thin open strokes are sampled at full resolution (up to 1920 px), thinned to a
  one-cell skeleton, and traced along their centreline from end to end. This includes
  1 px antialiased open polygon strokes. A filled blob is rejected by the stroke tracer
  and falls back to the closed outline.
- Traced points are smoothed and resampled to about 300–400 points. Copies are
  distributed by arc length.
- A Path value, when present, overrides Shape completely and may be open or closed.

## Notes and limitations

- **Shape is an Image/Mask input**, not a Polyline or ShapeTree/USD input. Fusion's
  Polygon, Ellipse, Rectangle, BSpline, and other mask tools connect directly. Fusion
  20's Shape and sBSpline tools output ShapeTree/USD data and are not accepted.
- **Random Color is a tint**, not a mathematically exact hue rotation of the Sample's
  own colors. White or bright samples show the hue variation most clearly; colored
  samples are multiplied by the random tint.
- **Path is Inspector-only** (no node socket). Draw an open or closed Polyline in the
  Path control; it overrides Shape. Fusion has no general Polyline input socket, so a
  Custom Poly node cannot be wired into Path — draw the path instead.
- **Aligned** rotates each copy to the local tangent. On a closed shape the lower half
  will bank upside down, which is expected tangent-following behaviour.
- **Random Position** offsets along the left/right normal, not along the tangent. It is
  a 0–1 slider; at 1 the maximum sideways offset is 20% of the Sample width.
- **Along Size is a five-point multiplier profile** (Start, 25%, 50%, 75%, End), all defaulting to 1.0. Values are linearly interpolated. Native ColorCurves-style spline widgets require an internal LUTBezier child that a Fuse cannot reliably create on the live node, so this profile is used instead of an empty curve editor.
- The Sample's alpha is preserved. Copies are transformed with linear filtering and
  composited with Fusion's Merge operation.
- The hidden Merge operator input is an internal implementation detail; it is not
  visible in the Inspector.

## Validation

Live Fusion 20 renders checked:

- Ellipse mask connected to Shape.
- Polygon mask (`PolylineMask`) connected to Shape.
- Open stroke masks — a 6 px sine line and a 1 px antialiased sine line — connected to Shape; copies followed the centreline end to end.
- Optional open/closed Path input; open path distributes from one end to the other.
- Aligned on/off on the ellipse; copies rotated to the tangent.
- Random Position 0 and 0.4 on the ellipse; copies moved sideways from the outline.
- Density 0/1/12/20/24; Density slider maximum 1000; Size 0.18–0.25.
- Color multiply verified with blue RGB 0.2/0.8/1.0 and red RGB 0.929/0.079/0.134; output mean RGB matched those tints (red measured about 238/18/32 at 8-bit).
- Additive and Multiply tested with colored copies.
- Random Color, Random Size.
- Along Size profile tested with Start 0.1, 25% 0.4, 50% 1.0, 75% 0.4, End 0.1; sizes varied visibly. Defaults 1.0/1.0/1.0/1.0/1.0 render full-size copies everywhere.
- Empty shape, empty outline, and missing Sample.
- Closed masks render quickly; 1 px open-stroke tracing is slower (full-resolution sampling) but stays interactive for stills.

## Performance

Optimizations in 1.9:

- A coarse 256 px fill-ratio probe decides whether a Shape is a thin stroke. Closed/filled masks skip the full-resolution stroke scan and go straight to contour tracing.
- Full-resolution stroke sampling is reserved for thin/open strokes; closed masks use a lower-resolution contour.
- Density/Size are checked before any shape tracing, so Density 0 or Size 0 returns a blank immediately.
- Color tint is skipped when Color is unity, and Normal blending omits the apply-mode argument.

Measured on this machine, 1920×1080, one frame:

- Closed ellipse mask, Density 100, Size 0.1: about **0.62 s** (was about 0.75 s).
- 1 px open stroke, Density 20, Size 0.1: about **0.55 s**.

Remaining cost is dominated by per-copy `Image:Transform` plus `Merge`, so it scales roughly linearly with Density. For very high Density (hundreds to 1000), lower Density or use a smaller Sample/DoD where possible. Further options not implemented: caching a static shape's arc across frames (risky when the mask animates), precomputing an arc lookup table (small gain versus image compositing), or baking copies into a sprite sheet.

Render artifacts and test compositions are under
`C:\__Work\_DeepSeek\Fusion\renders\arrange\`.

## Files

- Source: `C:\Users\Pavel\Documents\ChatGPT\Fusion\operators\PSN_SplineArrange.fuse`
- Installed: `C:\Users\Pavel\AppData\Roaming\Blackmagic Design\Fusion\Fuses\PSN_SplineArrange.fuse`
- Registry ID: `Fuse.PSN_SplineArrange`

To install on another Fusion machine, copy the single `.fuse` file into the user's
Fusion `Fuses` directory and restart Fusion. Python and MCP are not required to use the
installed node.
