# kevinrocci.com

Static personal site. No build step, no dependencies. Three files plus one
page directory.

```
index.html                          home
work/hiring-automation/index.html   case study
style.css                           shared stylesheet, design notes at top
nav.js                              scroll-spy for the rail nav
favicon.svg                         feather mark, also used in the sidebar
img/feather.svg                     source of the same mark
img/swatch-*.png                    generated watercolor washes
tools/make-swatches.py              regenerates those washes
```

## Local preview

```
python3 -m http.server 8080
```

Then open http://localhost:8080

## Design

The full token set lives in the header comment of `style.css`.

## Palette

Sampled from a **yellow-billed magpie** (*Pica nuttalli*), a bird that
lives in California's Central Valley and essentially nowhere else. The
full token set and the reasoning live in the header comment of
`style.css`.

The bird is two large neutral fields interrupted by two saturated
marks — the iridescent wing and the yellow bill. The page is built the
same way: a dark rail, a light column, blue for links, amber for the
one thing that is active. Nothing sits in the middle.

Three details keep it from reading as a generic dark sidebar:

- The rail is not flat. A magpie's black is structural colour, so it
  shifts violet at the top and teal at the bottom, with a soft sheen
  raking across it.
- The rule under the page title reads left to right as the bird does:
  bill, head, wing, then a long tail fading out. A yellow-billed
  magpie's tail is longer than its body, so the rule is long and thin.
- Section hairlines start as bill yellow for the first 34px, then hand
  off to the neutral line colour.

All text, links and nav pass WCAG AA (4.5:1); most clear it by a wide
margin.

`tools/make-swatches.py` still defines the kestrel and heron palettes
that lost, as a record of the exploration. Render either by name.

## Publishing

Live at https://kevinrocci.com, hosted on Bluehost.

The plan has **no shell access**, so deploys always take the SFTP path.
That means every file uploads on every run and nothing is ever deleted
remotely — if you remove a file from the repo, delete it on the server
by hand.

Deploy:

```
./deploy.sh
```

First-time setup on a new machine:

```
cp .deploy.env.example .deploy.env   # fill in host, user, remote dir
```

`.deploy.env` holds the credentials and is gitignored. It must never be
committed.

The script prefers `rsync` over SSH where a login shell exists, since
it sends only changed files and supports a real dry run. It detects the
shell by its **output**, not its exit status — Bluehost accepts the SSH
connection, prints "Shell access is not enabled on your account!", and
still exits 0, so testing `$?` picks the wrong transport. On this host
it correctly falls back to an `sftp` batch.

Only the live payload ships: `.htaccess`, `index.html`, `style.css`,
`nav.js`, `favicon.svg`, `img/`, and `work/`. The swatch generator, this
README and the git metadata stay local.

`.htaccess` carries the canonical-URL rules (force HTTPS, strip www),
directory-listing lockout, MIME types, and cache policy. It lives in the
repo rather than in cPanel toggles so the live behaviour is reviewable
and survives a host move. Note that cPanel cannot set Force HTTPS on
this domain anyway — addon domains inherit that flag from their parent
subdomain — so `.htaccess` is doing the work.

Directory structure matters — the case study lives at
`/work/hiring-automation/`. Do not flatten it.

### The ownership guard

This hosting account carries more than one site. Since the deploy uses
`rsync --delete`, a wrong `REMOTE_DIR` would erase whatever lives at
that path. The script therefore refuses to write into a directory it
does not recognise:

- it drops `.deployed-by-kevinrocci-repo` on first successful deploy
- on every later run it checks for that marker
- a directory that is missing, or occupied by files this script did not
  put there, aborts with instructions rather than deleting anything

The first real deploy into a non-empty directory needs `--claim`, and
only after you have listed the directory and confirmed what is in it.

## Swatches

The six washes in "Off the clock" are the palette itself, painted. They
are currently generated; the intent is to replace them with real
watercolor.

### The six pigments

| Swatch | Hex | Pigment | Paint |
|---|---|---|---|
| Wing | `#123F52` | PB15 + PBk31 | Phthalo Blue (Green Shade) + Perylene Green, or Daniel Smith Indigo straight |
| Azure | `#1F6EA8` | PB29 / PB15:3 | Cerulean Blue Chromium — it granulates, which is closest to the real sheen |
| Chalk | `#F5F3EE` | — | Bare paper. Do not paint this one |
| Pewter | `#93A5B2` | PB29 + PBk9 | Cerulean + Ivory Black, very dilute — or Payne's Grey at roughly 15% |
| Ink | `#161C24` | PBk31 + PB15 | Perylene Green + Phthalo Blue |
| Bill | `#F0AD1B` | PY150 / PY97 | Nickel Azo Yellow, or Winsor Yellow Deep |

Two notes. A magpie's black is structural colour rather than pigment,
which is why **Ink is mixed from a green and a blue instead of a black**
— mixed darks stay alive on paper, tube black goes dead. And leave
**Chalk as unpainted paper**, dropping clear water at the edge to get
the rim without pigment in the field. That reads more honestly than
painting an off-white.

### Replacing the generated washes with real ones

Paint them, scan or photograph them, then knock the paper out to
transparency. Export as PNG:

| | |
|---|---|
| Size | 240 x 216 or larger, roughly 10:9 |
| Background | Transparent — the page ground shows through the thin areas |
| Location | `img/magpie/` |

Filenames, exactly:

```
swatch-wing.png    swatch-azure.png    swatch-chalk.png
swatch-pewter.png  swatch-ink.png      swatch-bill.png
```

Then `./deploy.sh`. No CSS or markup changes — the chips are sized with
`background-size: contain`, so anything near that aspect ratio drops in.
Each chip carries a small fixed rotation in `style.css` (`.c1` to `.c6`),
so do not pre-rotate the scans.

### Regenerating the placeholders

```
python3 tools/make-swatches.py
```

Standard library only — no numpy, no Pillow. It encodes the PNGs byte by
byte. The model is a cheap version of Curtis et al., *Computer-Generated
Watercolor* (1997), keeping the three effects that make a wash read as
watercolor rather than as a gradient:

1. **Edge darkening.** Water evaporates fastest at the rim, so pigment
   migrates outward and deposits in a dark ring. This is the strongest
   cue and the one CSS gradients never have.
2. **Granulation.** Heavy pigment settles into the paper's low spots.
3. **Backruns.** Water pushed into a drying wash leaves a pale island
   with a harder rim.

Pigment is applied by Beer-Lambert, so output alpha comes from deposit
thickness and thin areas let the ground through the way paper does.
Output is deterministic — change `SEED` for a different set of
accidents. The script also still defines the kestrel and heron palettes
that lost the pitch; render either by naming it.

## Publishing

Live at https://kevinrocci.com, hosted on Bluehost.

The plan has **no shell access**, so deploys always take the SFTP path.
That means every file uploads on every run and nothing is ever deleted
remotely — if you remove a file from the repo, delete it on the server
by hand.

Deploy:

```
./deploy.sh
```

First-time setup on a new machine:

```
cp .deploy.env.example .deploy.env   # fill in host, user, remote dir
```

`.deploy.env` holds the credentials and is gitignored. It must never be
committed.

The script prefers `rsync` over SSH where a login shell exists, since
it sends only changed files and supports a real dry run. It detects the
shell by its **output**, not its exit status — Bluehost accepts the SSH
connection, prints "Shell access is not enabled on your account!", and
still exits 0, so testing `$?` picks the wrong transport. On this host
it correctly falls back to an `sftp` batch.

Only the live payload ships: `.htaccess`, `index.html`, `style.css`,
`nav.js`, `favicon.svg`, `img/`, and `work/`. The swatch generator, this
README and the git metadata stay local.

`.htaccess` carries the canonical-URL rules (force HTTPS, strip www),
directory-listing lockout, MIME types, and cache policy. It lives in the
repo rather than in cPanel toggles so the live behaviour is reviewable
and survives a host move. Note that cPanel cannot set Force HTTPS on
this domain anyway — addon domains inherit that flag from their parent
subdomain — so `.htaccess` is doing the work.

Directory structure matters — the case study lives at
`/work/hiring-automation/`. Do not flatten it.

### The ownership guard

This hosting account carries more than one site. Since the deploy uses
`rsync --delete`, a wrong `REMOTE_DIR` would erase whatever lives at
that path. The script therefore refuses to write into a directory it
does not recognise:

- it drops `.deployed-by-kevinrocci-repo` on first successful deploy
- on every later run it checks for that marker
- a directory that is missing, or occupied by files this script did not
  put there, aborts with instructions rather than deleting anything

The first real deploy into a non-empty directory needs `--claim`, and
only after you have listed the directory and confirmed what is in it.

## Swatches

The six washes in "Off the clock" are generated, not stock art:

```
python3 tools/make-swatches.py
```

It writes `img/swatch-<name>.png` using the standard library only — no
numpy, no Pillow. The model is a cheap version of Curtis et al. 1997:
edge darkening, granulation, and backruns, with pigment applied by
Beer-Lambert so thin areas let the page ground through. Output is
deterministic; change `SEED` in the script to reroll the accidents.

To use hand-painted scans instead, export PNGs with transparent
backgrounds and drop them in `img/` under the same six filenames. No
CSS change needed.
