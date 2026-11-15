# PSN_DotProduct

Normal-map direction matte. One texel is sampled at a screen position, and every pixel of the image is compared with it as a 3D vector. The dot product of the two unit vectors, clamped to 0-1 and raised to a power, is written to R, G, B and A.

## Use

Press Shift+Space in Fusion and search **PSN_DotProduct**. The tool is registered under **PSN / Mask**. Internal registry ID: `Fuse.PSN_DotProduct`.

1. Connect the normal map to **Input**. Its alpha is not required; the mask is generated from RGB.
2. Select the node in the viewer. A crosshair appears over the image - drag it, or type **X / Y** in the Inspector, to choose the texel that everything is compared against. The default is the image centre (0.5, 0.5). Coordinates are normalised and clamped to the frame.
3. Set **Power** (0-1, default 1) to shape the falloff. The exponent is `1 + 9 x (1 - Power)`: 1 gives the plain dot product, 0 gives the dot product to the power of 10, and values in between interpolate linearly. Sliding left increases the exponent.
4. **Decode Normal Map** (default on) converts RGB to a vector with `2 x RGB - 1`, the standard tangent-space normal-map decode. Turn it off when the input already holds signed vector data and raw RGB should be used as the vector.

The output is a black-and-white matte in all four channels: R, G, B and A all carry the mask value.

## The calculation

- The picked texel is `floor(X x Width), floor(Y x Height)`, clamped to the frame. Fusion's image space is bottom-up, and so is the viewer position control, so Y = 0 samples the bottom row.
- Both the picked texel and each image pixel become a vector: `2 x RGB - 1` with decoding on, RGB as stored with it off.
- Both vectors are normalised, so a texel whose normal equals the picked one is exactly 1 (white) whatever the length of the stored vector.
- `mask = clamp(dot, 0, 1) ^ exponent`. Matching direction is white, perpendicular and opposite directions are black, and a zero-length vector (a black texel, or mid-grey decoded) is black.
- Premultiplied input is un-premultiplied before decoding when `0 < alpha < 1`; the stored data values decide the mask.

## Notes

**Premultiplied output.** Fusion stores premultiplied pixels, so the node writes `RGB = alpha = mask`. In the comp that reads as a black-to-white matte, and any Effect Mask input takes the alpha. When a still is written by a Saver, the default **Pre-Divide** un-premultiplies the image, producing white RGB plus the mask in alpha; disable Pre-Divide in the Saver, or enable **Save Alpha To Color**, to bake the matte into RGB as well.

**Colour management.** Load normal maps with colour management set to **No Change** (Loader: Color Space and Gamma). With an automatic sRGB/linear conversion, the texels the node receives are no longer the stored values and the decoded vectors are wrong. Fusion's working-space conversion is not compensated for here.

**Normal maps whose blue channel is empty.** Some pipelines write only X and Y and leave B at 0. Decoding then yields Z = -1 for every texel, the dot product keeps a large constant term, and the mask gets its contrast from the Power control rather than from the dot product alone. The operator still behaves as described, but the range is compressed.

**Cost.** CPU, multithreaded through `MultiProcessPixels`: about 2.8 s per 4000 x 4000 frame on this machine.

## Validation

Rendered in Fusion Studio 20.0.0.50 through a Loader and Saver set to No Change, and compared with an independent NumPy implementation of the formula above.

- 1024 x 1024 fixture with four constant normals. Picks at (0.25, 0.25), (0.75, 0.25) and (0.25, 0.75) landed in the expected quadrants and matched the reference within one 8-bit step per quadrant (max 0.0038, step 0.0039).
- Power 0.5 (exponent 5.5) and Power 0 (exponent 10) matched the reference within 0.0013 and 0.0002.
- Decode off matched within 0.0023.
- Edge cases: a 3 x 2 image with a zero-length texel, an out-of-frame pick (clamped to the corner texel) and an unconnected input all rendered without a crash; an unconnected input produces no image, as with any Fusion tool whose image input is empty.
- The supplied 4000 x 4000 map (`optimus_5_simple__ShN_0038.png`) renders in 2.8 s per frame; its blue channel is 0 on average 8.6/255, max 126/255, so it falls under the note above.

## Install

Copy `PSN_DotProduct.fuse` and `PSN_DotProduct.png` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion. The PNG supplies the Effects Library and toolbar icon; without it the tool falls back to Fusion's default icon.
