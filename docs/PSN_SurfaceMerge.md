# PSN_SurfaceMerge 0.6

Surface-aware place/merge. A second image is laid onto an estimated surface: the placement
plane rotates by the surface normal at its anchor, can bend across a fold, is occluded by
geometry in front of it, picks up the background's shading, and casts a short contact shadow.

Screen-space cheat, not a camera solve.

## Three ways to feed it, no map required

| Connected | Tilt comes from | Occlusion from | Quality |
| --- | --- | --- | --- |
| nothing | background luminance, blurred at the placement's own scale, gradient -> normal | luma as pseudo-depth | works on visibly shaded fabric, walls, product shots; flat lighting degrades it to a flat placement with light adapt and shadow only |
| depth image (`Surface Type = Depth only`) | gradient of that depth | the depth itself | correct geometry, one extra render/tab needed |
| packed RGBA (`Surface Type = Packed`) | the map's own normals | the map's depth | best; tilt is exact, no gradient guesswork |

So a normal map is never required. Depth alone is enough, and nothing at all is still a usable mode.
## Inputs

| Input | Required | Meaning |
| --- | --- | --- |
| Background | yes | The scene the image is placed into. |
| Foreground | yes | The image being placed. Premultiplied alpha. |
| Surface | no | Surface map. Packed RGBA by default (R,G = folded normal, B = relative depth). Or a plain depth image with `Surface Type = Depth only`. Unconnected: geometry from background luminance. |
| Mask | no | Matte multiplied into the placement. Only alpha is used. |

## Controls

**Placement** â€” `Position`, `Size`, `Aspect`, `Rotation`, `Roundness`, `Edge Softness`.

**Surface** â€” `Relief` (scale on the anchor normal), `Perspective`, `Plane Slope` (occlusion
only), `Fit Radius` (occlusion fit), `Wrap`, `Surface Type`, `Depth Nearer = Brighter`,
`Map Encoding`.

**Occlusion** â€” `Occlusion`, `Occlusion Softness`, `Contact Shadow`, `Shadow Width`.

**Merge** â€” `Blend`, `Opacity`, `Light Adapt`.

**View** â€” Result, Surface normal, Depth, Occlusion, FG coordinates, Contact shadow.

## How it works

1. **Geometry grid.** Depth sampled on an 8 px grid (Surface map, or background luminance).
2. **Normals.**
   - Packed map: R,G decoded as a folded normal (`nz = 1 - |nx| - |ny|`, normalised). This is
     the authoritative orientation and is what rotates the placement plane.
   - Depth-only map or luminance fallback: normals from the depth gradient, slope clamped.
3. **Tilt.** The plane's normal is sampled **at the anchor** and scaled by `Relief`; the
   footprint is projected through its tangent frame. A flat depth with a tilted normal still
   tilts the placement.
4. **Perspective.** `(0.5 + 1.5*depth) / 1.25` mixed by `Perspective`, from the anchor depth.
5. **Occlusion.** A depth plane `d = a + b*x + c*y` is least-squares fitted over a disc around
   the anchor (depth only, normals play no part). `resid = surfaceDepth - planeDepth`; where
   the surface is in front, the placement is hidden. `Plane Slope` scales the fit.
6. **Wrap.** With `Wrap > 0` the footprint uses the normal at each pixel, bounded to 22 % of the
   placement and faded out near the silhouette, so the texture bends while the outline stays a
   clean quad.
7. **Contact shadow.** Foreground alpha resampled through an expanded placement; the difference
   is a silhouette band, darkened where the surface sits behind the plane.
8. **Light adaptation.** Multiplied by `clamp(luma*1.55 + 0.16, .16, 1.45)`.

## Limits

- **The depth channel is relative, not metric.** Its gradient is *not* a slope. Never derive tilt
  from it: at the test anchor the depth fit implied 51Â°, the map's own normal said 13Â°.
- **Depth cannot tell absolute tilt.** A side face seen nearly edge-on needs `Tilt X` (~60° for
  the cube side in the test plate); depth-derived normals only order the shape.
- **Wrap is per-pixel, not integrated.** Arc length is not conserved; at 1.0 a sharp fold smears
  and can notch the sprite border. Defaults to 0.
- **The silhouette is always the anchor quad.** Only the texture bends; a fold cuts the
  placement through occlusion rather than deforming its outline.
- **Luma fallback is shading, not geometry.** Fine on fabric, walls, product shots; fails on
  matte, evenly lit surfaces.
- **Cost.** ~0.5â€“0.9 s per 1920Ã—1080 frame; `Wrap` adds ~10 %.

## Validation

- **Normal-driven tilt:** a synthetic map with constant depth (B = 0.5) and a 45Â° normal in X
  narrows the placement by cos 45Â° = 0.71, with nothing in the depth channel to fit. Proves the
  plane rotates by the normal, not by depth.
- **Consistency check:** at the anchor of the cloth plate the packed normal reads 13.3Â°; the
  depth-plane fit implied 51.2Â° â€” hence the rule above.
- **Depth-only mode:** the same depth channel supplied as a grayscale image with
  `Surface Type = Depth only` produces gradient normals and renders without artifacts.
- No-map mode renders at the same placement; the tilt is visibly smaller than the packed-map tilt, as expected for a shading guess.
- Fitted occlusion plane still matches the numpy reference to 3 decimals.
- **Side face placement:** the lower cube's right face lands correctly with `Tilt X = -60`,
  size 0.22: the sticker compresses to the face and reads as applied to it, not pasted flat.
- **Real footage** (concrete still life, 567x851, Depth Anything V2 Small run offline): packed
  map gives an 8° tilt on the cube face and correct occlusion — a 0.30 placement behind the
  sphere keeps only the ears that sit in front of the wall. Depth-only mode gives the same
  placement; the no-map mode gives nearly the same result on that evenly lit face, which is
  expected: the map buys occlusion and curved surfaces, not flat-lit planes.
- Rendered without console errors: default, Surface, Mask, inverted depth, Wrap 0/0.5/1,
  depth-only, no Surface.

## Notes for the next session

- Input IDs `BlendMode` / `OpacityAmount` are deliberate: an ID of `Blend` collides with
  Fusion's built-in common control and silently reads 1.0.
- Optional image inputs need `INP_Required = false, INP_Optional = true`.
- Fusion rows are bottom-up.
- `smoothstep(a, b, x)` here assumes `a < b`; a reversed range silently returns 0 or 1.
- A packed map fed as a grayscale depth image yields garbage normals â€” that is why
  `Surface Type` exists. Default is packed.
- No icon PNG yet.
- Fusion quirk: a Saver clip whose stem ends in digits (`occ_soft12.png`) is treated as a frame
  sequence and renamed (`occ_soft01.png`). Name test renders without trailing digits.
- Next real improvement: precomputed arc-length field (4 px cells) with a depth-continuity gate
  inside the integration, replacing the per-pixel tangent frame for `Wrap`.



