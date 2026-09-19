# Profile reference

A profile is a YAML file that overrides the defaults in `scripts/md2docx.py`
(the `DEFAULTS` dict). Only name the keys you want to change - everything else
falls back to the default.

Unknown keys print a warning on stderr at every nesting level (`body.line_spacng`
is reported, not silently dropped), so read stderr when a setting seems to do
nothing.

## Contents

- [Finding profiles](#finding-profiles)
- [extends](#extends)
- [font](#font)
- [page](#page)
- [body](#body)
- [headings](#headings)
- [tables](#tables)
- [lists](#lists)
- [references](#references)
- [images](#images)
- [toc](#toc)
- [features](#features)
- [cover](#cover)
- [Recipes](#recipes)

All sizes are in points unless the key ends in `_cm`.

## Finding profiles

`-p` takes either a path or a bare profile name. A name is looked up in these
directories, nearest scope first:

| Scope | Directory | Use for |
| --- | --- | --- |
| Project | `./.md2docx/`, then `./` | A format belonging to one repository |
| Personal | `~/.claude/md2docx/profiles/` | Formats reused across your own projects |
| Bundled | the skill's `assets/profiles/` | The shipped set |

The first match wins, so a project profile shadows a bundled one of the same
name. That is the supported way to pin a house style without editing shared
files.

`--list-profiles` prints every visible name with the file it resolved to, which
is the fastest way to confirm which copy is actually in play.

## extends

A profile inherits from another by name:

```yaml
extends: report-es

font: {body_size: 12}
```

The parent is resolved through the same search path, merged recursively, and
then the child's keys are applied on top. Chains of any depth work
(`continental-pa2` -> `report-es` -> `plain`), and a cycle raises an error
instead of hanging.

Inheritance is what keeps profiles small. A new institution or client format is
usually `extends` plus the three or four keys their spec actually dictates -
copying a whole profile means every future fix has to be applied twice.

## font

| Key | Default | Meaning |
| --- | --- | --- |
| `name` | `Arial` | Applied to body, headings and tables |
| `body_size` | `11` | Base size for paragraphs |
| `table_size` | `9` | Size inside table cells |
| `heading_sizes` | `{1: 12, 2: 11, 3: 11}` | Per-level heading size |

## page

Any value left `null` keeps the `python-docx` default, so a profile that does not
care about page setup can omit the section entirely.

| Key | Default | Meaning |
| --- | --- | --- |
| `width_cm` / `height_cm` | `null` | Page size (A4 is `21` x `29.7`) |
| `margins_cm.top/bottom/left/right` | `null` | Page margins |

## body

| Key | Default | Meaning |
| --- | --- | --- |
| `line_spacing` | `1.5` | Multiple, not points |
| `space_after` | `6` | Space below each paragraph |
| `align` | `justify` | `justify`, `left`, `center`, `right` |

## headings

| Key | Default | Meaning |
| --- | --- | --- |
| `align` | `left` | Heading alignment |
| `space_before` / `space_after` | `12` / `6` | Spacing around headings |
| `keep_with_next` | `true` | Prevents a heading stranded at a page bottom |
| `numbering` | `false` | Auto-number H1 as `1.` and H2 as `1.1.` |
| `unnumbered` | `[]` | H1 titles excluded from numbering, e.g. `[Referencias, Anexos]` |
| `page_break_before_unnumbered` | `true` | Start each unnumbered H1 on a new page |

Numbering deliberately skips any H2 whose text starts with `Anexo`, since
annexes are normally lettered rather than numbered.

## tables

| Key | Default | Meaning |
| --- | --- | --- |
| `header_fill` | `null` | Header row shading as a hex string without `#`, e.g. `D9E2F3`. `null` leaves it unshaded |
| `line_spacing` | `1.0` | Spacing inside cells - usually tighter than body text |
| `align` | `center` | Table alignment on the page |

## lists

| Key | Default | Meaning |
| --- | --- | --- |
| `number_indent_cm` | `0.9` | Left indent for `1. item` paragraphs |
| `number_hanging_cm` | `0.6` | Hanging indent so wrapped lines align after the number |

## references

| Key | Default | Meaning |
| --- | --- | --- |
| `heading` | `Referencias` | H1 title that switches on reference formatting |
| `hanging_cm` | `1.27` | Hanging indent for entries (APA uses 1.27 cm) |

Only takes effect when `features.hanging_references` is `true`.

## images

Applies to every figure: embedded images, rasterized SVG, and the placeholder
boxes drawn when a path resolves to no file and `features.image_placeholders`
is `true`.

| Key | Default | Meaning |
| --- | --- | --- |
| `fill` | `F2F2F2` | Placeholder box shading |
| `caption_size` | `10` | Caption font size |
| `box_lines` | `3` | Blank lines above and below the label, controlling box height |
| `max_width_cm` | `null` | Caps figure width. `null` fits figures to the text column |
| `scale_factor` | `2` | Device pixel ratio of a rasterized SVG. 2 is near 190 dpi at full column width, 3 clears 280 dpi |
| `chrome` | `null` | Path to the browser used to rasterize SVG. `null` checks `$MD2DOCX_CHROME`, then the usual Chrome and Edge locations |
| `svg_caption_from_aria` | `true` | Use an inline SVG's `aria-label` as its caption when the Markdown supplies none |

Figure width is the text column - page width minus both margins - so it follows
`page.margins_cm` without being restated. `max_width_cm` only ever narrows it.

An image narrower than that limit keeps its natural size; only oversized ones
are scaled down. A rasterized SVG is always fitted to the full width, because
its pixel size carries `scale_factor` rather than a real print size.

## toc

| Key | Default | Meaning |
| --- | --- | --- |
| `depth` | `"1-2"` | Heading levels included. Quote it - bare `1-2` is not a YAML number |
| `heading` | `Índice` | Title above the field |
| `placeholder` | `Clic derecho > Actualizar campo` | Shown until the field is updated in Word |

## features

Each toggle is `false` by default.

| Key | Effect |
| --- | --- |
| `cover` | Render the cover page described in `cover` |
| `toc` | Insert a Word TOC field plus a page break |
| `page_numbers` | `PAGE` field in the footer, suppressed on the first page |
| `image_placeholders` | Turn `![…](…)` lines into boxed placeholders |
| `hanging_references` | Hanging indent for entries under the references heading |

## cover

The cover is a generic list of centered lines rather than named fields like
`university` or `faculty`. Semantic fields would lock the tool to one
institution's template; a list of lines adapts to any cover layout.

```yaml
cover:
  lines:
    - {text: UNIVERSIDAD CONTINENTAL, bold: true, size: 16}
    - {text: Facultad de Ingeniería, size: 12}
    - {text: Pruebas y Calidad de Software, bold: true, size: 13, before: 36}
  members_header: [Integrante, "% de participación"]
  members:
    - {name: "Cruz Conde, Paul Antonio", participation: 100 %}
  footer_lines:
    - {text: "Docente: José Antonio Castro Flores", size: 12, before: 36}
    - {text: Perú, septiembre de 2026, size: 12, before: 48}
```

Line spec keys: `text` (required), `bold`, `size`, `before`, `after`, `align`.
`before`/`after` are spacing in points and are how vertical position on the cover
is controlled.

`members` renders a participation table between `lines` and `footer_lines`; one
entry per group member, each producing a row. Omit `members` entirely to skip
the table. A page break is added after the cover automatically.

**Lists are replaced, not merged.** A child profile's `lines` overrides the
parent's outright, so list every cover line the deliverable needs. This is why
cover text belongs in a per-deliverable profile while the layout it sits on
(margins, fonts, numbering) belongs in the shared parent - see `continental`
and `continental-pa2` for the split.

## Recipes

**A rubric with different margins** - override just what changed:

```yaml
page:
  margins_cm: {top: 3, bottom: 3, left: 3, right: 3}
```

**A short report with no cover or TOC** - start from `continental-pa1.yaml`; it
already has every feature off.

**Numbered headings but no cover:**

```yaml
headings:
  numbering: true
  unnumbered: [Referencias]
features:
  toc: true
  page_numbers: true
```

**Debugging a profile that seems ignored** - run the conversion and read stderr
for the unknown-key warning, then compare the nested key spelling against the
tables above.
