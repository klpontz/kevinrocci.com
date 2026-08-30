# kevinrocci.com

My personal site. Two pages, no build step, no dependencies, no
framework. Plain HTML, one stylesheet, and about forty lines of
JavaScript that draw a dot next to the section you are reading.

**Live at [kevinrocci.com](https://kevinrocci.com)**

---

## The interesting part

`tools/make-swatches.py` paints the six colour swatches on the home
page. It is standard library only — no numpy, no Pillow — and it
encodes the PNGs byte by byte with `zlib` and `struct`.

The model is a cheap version of Curtis et al., *Computer-Generated
Watercolor* (SIGGRAPH 1997), keeping the three effects that make a wash
read as watercolor rather than as a gradient:

1. **Edge darkening.** Water evaporates fastest at the rim, so pigment
   migrates outward and deposits in a dark ring. This is the strongest
   cue, and the one a CSS gradient never has. It is why the first
   attempt at these looked like plastic.
2. **Granulation.** Heavy pigment settles into the paper's low spots,
   so the field is mottled rather than an even film.
3. **Backruns.** Water pushed into a drying wash carries pigment with
   it and leaves a pale island with a harder rim. These took two rounds
   of tuning — at full strength they read as soap bubbles, and at the
   second attempt as outlined amoebas.

Pigment is applied by Beer-Lambert, so a thicker deposit transmits less
light. Output alpha comes from the deposit, which means thin areas let
the page ground through the way real paper does.

```
python3 tools/make-swatches.py
```

Deterministic — change `SEED` for a different set of accidents. The
script also still holds the two palettes that lost the pitch, an
American kestrel and a great blue heron. Render either by naming it.

---

## Design

### Palette

Sampled from a **yellow-billed magpie** (*Pica nuttalli*), a bird that
lives in California's Central Valley and essentially nowhere else. I
see them constantly. It seemed reasonable to let one pick the colours.

The bird is built from two enormous neutral fields interrupted by
exactly two saturated marks — the iridescent wing and the yellow bill.
The page is built the same way: a dark rail, a light column, blue for
links, amber for whatever is currently active. Nothing sits in the
middle.

| | Hex | On the bird |
|---|---|---|
| Wing | `#123F52` | iridescent wing and tail |
| Azure | `#1F6EA8` | the blue that catches the light |
| Chalk | `#F5F3EE` | belly and scapulars |
| Pewter | `#93A5B2` | flight-feather grey |
| Ink | `#161C24` | head and breast |
| Bill | `#F0AD1B` | bill and eye ring |

The black is never `#000`. A magpie's black is structural colour — an
interference effect in the feather barbs — so it shifts with the angle
of the light. The sidebar carries that shift, running violet at the top
and teal at the bottom. The white is warm, not paper-white.

Three details keep it from reading as a generic dark sidebar:

- The rail is not flat, for the reason above.
- The rule under the page title reads left to right the way the bird
  does: bill, head, wing, then a long tail fading out. A yellow-billed
  magpie's tail is longer than its body, so the rule is long and thin
  rather than short and thick.
- Section hairlines start as bill yellow for 34px, then hand off to the
  neutral line colour.

Every colour pair passes WCAG AA at 4.5:1 — body text, secondary text,
links against both the page ground and the note fill, and sidebar
navigation against the rail. Most clear it by a wide margin.

### Type

Fraunces for display, with the `SOFT` and `WONK` axes turned up. Wonk
swaps in the wobbly single-storey alternates, which is where the warmth
comes from. Source Serif 4 for body, because the case study runs to
about two thousand words and Fraunces at reading size would be
exhausting. IBM Plex Mono for labels and data.

### Structure

Experience entries are field-guide records rather than data tables: the
employer reads as a common name, the role as its binomial in italic
underneath. Each carries a span bar on a shared 2013-to-now axis, so
reading down the stack shows the shape of a career without reading a
single date.

---

## The swatches are placeholders

They are generated. The intent is to replace them with real watercolor,
which is why the palette is specified as pigments and not just hex.

| Swatch | Hex | Pigment | Paint |
|---|---|---|---|
| Wing | `#123F52` | PB15 + PBk31 | Phthalo Blue (Green Shade) + Perylene Green, or Daniel Smith Indigo straight |
| Azure | `#1F6EA8` | PB29 / PB15:3 | Cerulean Blue Chromium — it granulates, which is closest to the real sheen |
| Chalk | `#F5F3EE` | — | Bare paper. Do not paint this one |
| Pewter | `#93A5B2` | PB29 + PBk9 | Cerulean + Ivory Black, very dilute — or Payne's Grey at roughly 15% |
| Ink | `#161C24` | PBk31 + PB15 | Perylene Green + Phthalo Blue |
| Bill | `#F0AD1B` | PY150 / PY97 | Nickel Azo Yellow, or Winsor Yellow Deep |

Ink is mixed from a green and a blue rather than from a black, because
mixed darks stay alive on paper and tube black goes dead. Chalk stays
unpainted paper with clear water dropped at the edge, which gives the
rim without any pigment in the field.

To swap them in: export PNGs at 240 x 216 or larger, roughly 10:9, with
a **transparent background** so the page ground shows through the thin
areas. Drop them in `img/magpie/` as:

```
swatch-wing.png    swatch-azure.png    swatch-chalk.png
swatch-pewter.png  swatch-ink.png      swatch-bill.png
```

No CSS or markup changes — the chips use `background-size: contain`.
Each chip carries a small fixed rotation in `style.css`, so do not
pre-rotate the scans.

---

## Layout

```
index.html                          home
work/hiring-automation/index.html   case study
style.css                           one stylesheet, design notes at the top
nav.js                              scroll-spy for the sidebar
favicon.svg                         tab icon: the magpie in its chalk box
img/magpie.svg                      the silhouette, inlined into both pages
img/magpie/swatch-*.png             the six washes
tools/make-swatches.py              generates them
```

## Running it locally

```
python3 -m http.server 8080
```

Then open <http://localhost:8080>. That is the whole toolchain.

---

## License

**Code** — the stylesheet, the swatch generator, the scroll-spy, the
deploy script — is [MIT licensed](LICENSE). Take the watercolor
generator and do something better with it.

**Content** is not. The prose, the résumé, the case study, and the
swatch images are © 2026 Kevin Rocci, all rights reserved. Please do not
republish them as your own.
