# PSN_GradientMapExt

Photoshop-style Gradient Map with an **external ramp**: the gradient is not stored inside the operator. It is sampled live from the second (green) **Ramp** input — one full row of that image is read left-to-right as gradient positions **0 (shadows) to 100 (highlights)**. Any node can feed the ramp: a Gradient tool, a Loader with a painted strip, or a live color grade, and the map updates every frame.

- **Input:** the image to remap (first green input).
- **Ramp:** the image supplying the gradient (second green input). Width defines ramp resolution; alpha is ignored; values are bounded to 0–1.
- **Ramp row (Y):** which row to sample, counted from the **top as shown in the viewer**. Default **0** is the first (top) row. The full row width maps positions 0–100 regardless of image size; values between pixels are linearly interpolated.
- **Reverse:** flips the brightness key, like Photoshop's Reverse checkbox.
- **Preview:** disable to pass the original image through unchanged. With no Ramp connected, the node also passes through.
- **Input encoding:** RGB as supplied by default. The optional linear-sRGB setting applies the sRGB transfer curve before computing brightness and converts the mapped color back; it is not an ACEScg or log conversion.
- **Match Photoshop 8-bit tones:** quantizes the brightness key to 256 steps before sampling the ramp, matching Photoshop's 8-bit adjustment behavior.
- **Pre-Divide / Post-Multiply:** enabled by default for premultiplied images. Disable for straight RGB. Alpha is preserved; fully transparent pixels pass through untouched.

The brightness key is Photoshop's calibrated luminance `0.30 R + 0.59 G + 0.11 B`. Unlike the internal-gradient [PSN_GradientMap](PSN_GradientMap.fuse), there are no stops, interpolation modes, or smoothness controls — the ramp image is the gradient, sampled at its own pixel resolution.

## Install

Copy `PSN_GradientMapExt.fuse` to `%APPDATA%\Blackmagic Design\Fusion\Fuses\` and restart Fusion (or reload fuses). Press **Shift+Space**, search **PSN_GradientMapExt**, connect the image to **Input** and a horizontal gradient strip to **Ramp**. Internal registry ID: `Fuse.PSN_GradientMapExt`.

## Notes

A one-pixel-wide ramp is treated as a solid color map. Ramp rows below/above the image bounds are clamped to the edge rows. Independently implemented; no Adobe source code is included.
