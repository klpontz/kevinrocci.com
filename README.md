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

Hosted on Bluehost. Deploy over SSH/SFTP:

```
cp .deploy.env.example .deploy.env   # fill in host, user, remote dir
./deploy.sh --dry-run                # preview
./deploy.sh                          # upload
```

`.deploy.env` holds the credentials and is gitignored. It must never be
committed.

The script prefers `rsync` over SSH, which sends only changed files and
supports a real dry run. If the host allows SFTP but not a login shell
it falls back to an `sftp` batch that mirrors the tree. Force that path
with `./deploy.sh --sftp`.

Only the live payload ships: `index.html`, `style.css`, `nav.js`,
`favicon.svg`, `img/`, and `work/`. The swatch generator, this README
and the git metadata stay local.

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
