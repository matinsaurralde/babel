# Branding

The master art for Babel.

## App icon — "Sonar"

The canonical mark. A glass orb in deep violet with a luminous text-caret at the center and a soft sonar-ripple emerging from below — voice becoming text, refracted through Apple's Liquid Glass material.

- `Babel-Sonar-1024.svg` — vector master
- `Babel-Sonar-1024.png` — 1024 × 1024 raster master

Generated with [Claude Design](https://www.anthropic.com/news/claude-design-anthropic-labs).

## Palette

| Token       | Hex       | Use                                   |
|-------------|-----------|---------------------------------------|
| Orb deep    | `#0a0725` | outer rim of the glass body           |
| Orb mid     | `#1c154a` | primary body color                    |
| Orb near    | `#3a2d7a` | inner body highlight                  |
| Caret white | `#ffffff` | top of the caret                      |
| Caret blue  | `#bdd1ff` | bottom of the caret                   |
| Halo        | `#9ec0ff` | sonar ripple + halo glow              |
| Rim light   | `#a9b8ff` | specular top highlight                |

## Asset pipeline

The 1024 master is resized with `sips` into the ten sizes macOS asks
for (16 → 1024, @1x + @2x), written under
`Babel/Resources/Assets.xcassets/AppIcon.appiconset`. Re-run when the
master changes:

```bash
MASTER=branding/Babel-Sonar-1024.png
OUT=Babel/Resources/Assets.xcassets/AppIcon.appiconset
for spec in 16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x \
            128:icon_128x128 256:icon_128x128@2x 256:icon_256x256 \
            512:icon_256x256@2x 512:icon_512x512; do
  size=${spec%%:*}; name=${spec#*:}
  sips -z "$size" "$size" "$MASTER" --out "$OUT/$name.png" >/dev/null
done
cp "$MASTER" "$OUT/icon_512x512@2x.png"
```
