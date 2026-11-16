# PSN_SurfaceMerge 1.1

Places a sticker **tangentially** on a picked point of a surface. The sticker's plane is the
tangent plane of the surface there; its two axes run along the two orthogonal tangents, so the
placement is foreshortened exactly as the plane is and its axes stay perpendicular in 3D.

No shadow, no lighting, no occlusion â€” those belong to the blend and the comp.

## Inputs

| Input | Required | Meaning |
| --- | --- | --- |
| Background | yes | The scene. |
| Sticker | yes | The image placed. Premultiplied alpha. |
| Normal | no | Normal map, R,G,B = x,y,z. Unconnected: the plane is parallel to the screen (flat placement). |

## Controls

`Position` (pick), `Size` (width in the plane, fraction of frame height), `Aspect`, `Rotation`
(spin inside the plane), `Edge Softness`, `Flip Normal Y`, `Blend`, `Opacity`, `View`
(Result / Tangent frame).

**Blend modes** (23, Fusion Merge order): Normal, Add, Subtract, Multiply, Screen, Overlay,
Soft Light, Hard Light, Color Dodge, Color Burn, Darken, Lighten, Difference, Exclusion, Hue,
Saturation, Color, Luminosity, Vivid Light, Linear Light, Pin Light, Hard Mix, Divide.

## How it works

1. Sample the normal map bilinearly **at the picked point** (not precomputed over the frame).
2. Build an orthonormal tangent frame: `ty` = camera up projected onto the plane (falls back to
   the view axis on a face pointing straight up), `tx = ty Ã— n`.
3. Project the plane: the 2Ã—2 matrix `[[tx.x, ty.x], [tx.y, ty.y]]` maps plane coordinates to
   screen delta. Its **full inverse** turns a screen delta back into plane coordinates â€” this is
   the part that must not be simplified. Dropping `ty.x` (a shortcut I had in earlier versions)
   breaks orthogonality and the placement slides off the tangent.
4. `Rotation` is applied in plane coordinates, then the sticker is sampled with bilinear
   filtering; a square-footprint coverage with a soft edge gates it.
5. Blend and opacity.

## Limits

- **Linear tangent projection, not a 3D card.** Exact for the plane at the anchor; over a large
  placement the missing perspective divide shows up as a slight size drift toward the edges.
- **Needs a normal map for automatic orientation.** Depth alone cannot give an absolute angle
  (relative depth is affine-invariant), which is why there is no depth input any more.
- **Flat when the Normal input is empty** â€” by design.
- **Cost.** The operator adds ~1 s over a bypass at 4000Ã—4000. Measured: bypass render 20.1 s,
  with the operator 21.2 s. The 20 s is Fusion writing a 16-megapixel PNG, not the node. At
  736Ã—736 a full render is 0.2 s.

## Validation

- Cube plate + hand-authored normal map: sticker lands on the right face foreshortened to
  `cos(nx)`, on the top face lying down, with `Tilt` controls gone entirely.
- Router plate (4000Ã—4000) + its ShN pass with `Flip Normal Y`: sticker lies on the top face;
  whole frame intact, 21.2 s including the 4K save.
- Tangent-frame view (`View = 1`) paints the two axes, which read perpendicular on the face.
- **Blend modes**: each mode was rendered against a grey ramp with a 0.5 grey sticker. Every
  response matches its formula: Add 0.753, Multiply 0.125, Screen 0.627, Overlay 0.251,
  Hard Light 0.255, Color Dodge 0.506, Color Burn 0, Darken 0.251, Lighten 0.502,
  Difference 0.251, Exclusion 0.502, Hue/Sat/Color 0.251, Luminosity 0.502, Hard Mix 0/1,
  Divide 0.502 at a 0.251 ramp value.
- Note: Fusion scripting cannot set a Merge tool's `ApplyMode` in this build (assignment reads
  back None), so the modes were verified by response curve rather than by pixel equality with a
  native Merge.

## Notes for the next session

- `Image:Copy` in a fuse does **not** transfer pixels â€” a bbox-only loop therefore has to copy
  the background with `MultiProcessPixels` first, or accept a full-frame pass.
- Input IDs `BlendMode` / `OpacityAmount` avoid a collision with Fusion's built-in `Blend`.
- Optional image inputs need `INP_Required = false, INP_Optional = true`.
- Fusion rows are bottom-up.
- The previous full-featured version (depth input, occlusion, shadow, wrap, plane fit) is kept
  as `PSN_SurfaceMerge_v08_full.fuse.bak` next to this file.

