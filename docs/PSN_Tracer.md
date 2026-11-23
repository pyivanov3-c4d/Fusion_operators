# PSN_Tracer

A simple 2D point tracker. It follows a pattern around a **Point** on the **Tracer** image and places the second **Image** at that position, with optional scale and angle.

- **Tracer** (main input 1): the image that is searched. The pattern is taken around the Point on the reference frame.
- **Image** (main input 2): what gets placed; its centre sits on the tracked point.
- **Output**: a plate-sized image (same size as **Tracer**) with the Image placed on it, alpha-composited over transparency. Connect a Merge to put it over the plate, or drive any input with it.

## Install

Copy `PSN_Tracer.fuse` **and** `PSN_Tracer.png` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. Press **Shift+Space** and search **PSN_Tracer** (category **PSN > Tracking**). Registry ID: `Fuse.PSN_Tracer`.

## Controls

| Control | What it does |
| --- | --- |
| **Point** | The point that is tracked, relative 0-1 like Fusion's other point controls (0.5, 0.5 is the centre; 0.001 is ~2 px on a 1920 frame). Drag the value to scrub it; the marker follows. Moving it re-anchors the track at the current frame, so press **Cache Track** again for a stored track. |
| **Handle** | Optional viewer handle: one point of a polyline; when it has a point it overrides **Point**. Click in the viewer to place it. |`n| **Track** | Off: the Image just sits on the Point. On: the point is tracked with pattern matching. |
| **Search Radius** | How far, in pixels, the point may move between two frames. Must cover the fastest motion in the shot. |
| **Scale**, **Angle** | Transform of the placed Image, around its own centre. Animatable. |
| **Track Cache > Set Reference** | Uses the current frame and the current Point as the reference (the pattern is taken there). |
| **Track Cache > Cache Track** | Tracks forward from the reference to the end frame and stores every position in the comp. |
| **Track Cache > Delete Cache** | Throws the stored positions away and returns to live tracking. |
| **Track Cache > Cache To** | Last frame to cache. 0 means the project end frame. |
| **Track Cache > Status** | What the tracker is doing: live, cached, reference frame, cache size. |
| **Advanced > Pattern Size** | Half-size of the tracked patch, in pixels. Smaller follows detail, bigger is steadier. |
| **Advanced > Match Threshold** | Below this correlation (0–1) the point holds its position instead of jumping to a wrong match. |
| **Advanced > Subpixel** | Refines the match to fractional pixels. |
| **Advanced > Track Scale** | Also follows a change of the pattern's size (camera push-ins, zooms). On by default. |
| **Advanced > Show Marker** | Draws a yellow cross at the tracked point so the position is visible in the viewer. On by default; turn it off for the final render. |

## Workflow

1. Connect the plate to **Tracer** and the thing you want to place to **Image**.
2. Park on the frame where the target is clearly visible, drag **Point** onto it. That frame becomes the reference.
3. Play forward. Without a cache the tracker follows frame by frame; each frame is matched against the reference pattern.
4. For a final render (or a long jump), press **Cache Track**. The whole range is computed once, stored in the comp, and playback then just reads the stored positions.
5. **Delete Cache** to go back to live tracking, or move the Point to re-anchor.

## How it works

- The pattern is a square patch of luminance around the Point on the reference frame, zero-mean and matched with normalized cross-correlation (so exposure and contrast changes are tolerated).
- With **Track Scale** on, every frame also tests the pattern slightly larger and slightly smaller, so a push-in or zoom does not throw the match off.
- For every frame the tracker searches offsets in ±Search Radius around the previous position: a coarse pass on position steps, then a full-resolution refine, then an optional parabola fit for subpixel accuracy.
- A match below **Match Threshold** is rejected: the point holds instead of jumping.
- Live mode is frame-order independent: if Fusion asks for a frame with no earlier result, the missing frames are tracked first, so a render with several threads produces the same track as playback.
- The cache is a compact text table in a hidden input, so it travels with the comp file and survives a reload. It holds the reference frame and the positions; changing the Point or the reference invalidates it.
- The yellow marker is drawn into the output image, on top of the placed Image, so the point is always visible; switch **Show Marker** off for delivery.
- Placement samples the Image bilinearly, rotates and scales around its centre, and composites it over the plate-sized transparent canvas.

## Validation

Measured on Fusion Studio 20.0.0.50 with a 960×540 synthetic sequence (36 frames, target moving up to 49 px per frame over a noisy static background) and a 121×81 sticker with an exact centre mark:

- Live tracking, all 36 frames: measured centre within **0.5 px** of the generated ground truth on every frame (the residual is the dot centroid quantisation).
- Cached track, all 36 frames: same positions, status `Cached 36 frames (0-35), radius 60, pattern 16`.
- Cache deletion: status returns to live tracking and the same 36 frames still match.
- Cold start on frame 20 with no cache (template rebuilt from the reference frame): centre 315.5 / 325.5 vs truth 315.45 / 325.0.
- Scale 2 and Angle 30 on a cached frame: the sticker centre stays on the tracked point, and the sticker is scaled and rotated around it.
- Cache build for 36 frames: 0.21 s. Rendering 36 frames live or cached: 1.4 s each (bounded by decoding and PNG writing, not by the tracker).
- No errors in the Fusion console during any of the renders above.

## Limitations

- Translation plus optional scale; rotation of the target is not estimated. **Scale** and **Angle** are the transform of the placed Image, not tracked values.
- A target that changes shape (an animated or AI-generated subject, a moving limb through the pattern) will drift; the pattern is taken once at the reference frame.
- Motion per frame must stay inside **Search Radius**; beyond it the match is rejected and the point holds.
- It needs texture. A flat or repeating pattern gives no reliable match; a periodic pattern can lock one period off.
- The pattern is taken once at the reference frame; if the target changes appearance a lot (rotation, occlusion, lighting direction), the match degrades.
- Cache is capped at 5000 frames, and long live jumps fill up to 240 frames before falling back to a single search.
- CPU only, one full-frame pass for the placement plus the patch search per frame.
- No mask input. Use the **Track** checkbox or the threshold to control when it follows.
