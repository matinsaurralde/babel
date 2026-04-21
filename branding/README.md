# Branding

Master art for Babel. Everything ships from here into the app bundle and
the docs.

## Layout

```
branding/
├── Babel-Sonar-1024.{svg,png}      # app icon master ("Sonar")
├── menubar/                        # template glyph for the macOS menu bar
├── social/                         # GitHub / link-unfurl card (1280×640)
├── readme-hero/                    # banner at the top of README.md
├── dmg/                            # background for the distribution DMG
└── sparkle/                        # glyph for the "update available" dialog
```

## App icon — "Sonar"

A glass orb in deep violet with a luminous text-caret at the center and a
soft sonar ripple emerging from below — voice becoming text, refracted
through Apple's Liquid Glass material.

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

### App icon — 10 sizes

The 1024 master is resized with `sips` into every size macOS asks for
(16 → 1024, @1x + @2x), written under
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

### Menu-bar icon — template image

`menubar/Menubar_3arc_{18,36,54}.png` are a monochrome template (pure black
on transparent). They live in
`Babel/Resources/Assets.xcassets/MenuBarIcon.imageset` with
`template-rendering-intent = template`, so macOS tints them for light and
dark menu bars automatically.

### GitHub social preview

`social/Babel-social-1280x640.png` is the card GitHub shows when a link is
shared. It's **set manually** from the repo's *Settings → Social preview →
Upload an image*; there is no API for this.

### README hero

`readme-hero/Babel-readme-hero-1600x900.png` is embedded at the top of
`README.md`. The @2x version is archived alongside.

### DMG background & Sparkle glyph

`dmg/` and `sparkle/` hold art for when we ship notarized DMGs and wire
Sparkle auto-updates. They'll be consumed by build scripts when we get
there.
