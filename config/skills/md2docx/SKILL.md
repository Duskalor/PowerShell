---
name: md2docx
description: Convert a Markdown document into a Word (.docx) file whose formatting comes from a reusable YAML profile controlling fonts, margins, cover page, table of contents, page numbers and heading numbering. Use this whenever someone needs a document delivered as a Word file that has to obey a specific format - academic coursework ("producto académico", "entregable", "informe", "monografía", "trabajo de investigación", tesis), APA manuscripts, or professional reports, proposals and deliverables with a house style. Also use it when content already exists in Markdown and the request is for it "en Word", "como .docx", or for a document to be regenerated after the text changed. Prefer it over hand-building a .docx with python-docx, and over a generic docx skill, whenever the same format will be applied more than once.
---

# md2docx

Renders Markdown into a Word document whose formatting comes from a YAML
profile. The point is separation: content lives in the `.md`, every formatting
decision lives in the profile. That makes the document **regenerable** - edit a
paragraph, rerun one command, and the formatting comes out identical instead of
being re-applied by hand and drifting from the spec.

That property is worth most where the format itself is graded or audited, but it
applies to any document that gets revised more than once.

## Workflow

1. Write or edit the content as Markdown. No formatting concerns in this file.
2. Pick a profile (`--list-profiles` shows what is visible from here).
3. Convert, passing the profile by name:

```bash
python scripts/md2docx.py INPUT.md -o OUTPUT.docx -p continental-pa2
```

4. Verify before handing it over (see *Verifying output*).

`-p` also accepts a path, which is useful for a profile that lives outside the
search path. Omit `-p` entirely for a plain document with no cover or TOC.

On Windows the interpreter is often `py`, not `python` - Git Bash frequently has
no `python` on PATH at all. Check with `py --version` if `python` fails.

Dependencies: `python-docx` and `PyYAML` (`py -m pip install python-docx pyyaml`).
Documents containing SVG also need Chrome or Edge installed - see *Figures*.

## Supported Markdown

| Syntax | Result |
| --- | --- |
| `# H1` … `### H3` | Heading 1-3, auto-numbered (`1.`, `1.1.`) when the profile enables it |
| `**bold**`, `*italic*` | Inline runs |
| `- item` | Bulleted list, nested by indentation up to three levels |
| `1. item` | Numbered paragraph with hanging indent, nested the same way |
| `> quoted` | Block quote: indented, and joined across the lines it wraps over |
| `\| a \| b \|` | Table with a styled header row, columns sized from their content |
| `![caption](path.png)` | The image, centered and captioned, fitted to the text column |
| `![caption](path.svg)` | Same, rasterized first - see *Figures* |
| `![caption](KEY)` | Boxed screenshot placeholder, when the path resolves to no file and `features.image_placeholders` is on |
| `<svg …>…</svg>` | Inline diagram, rasterized and embedded - see *Figures* |
| `---` | Ignored - safe to use as a section separator |
| `` `code` `` | Inline run in Consolas, same size, backticks removed |
| fenced ``` block | Shaded paragraph, Consolas 9 pt, line breaks kept verbatim (language tag ignored) |

A leading `---` YAML frontmatter block is dropped, so Markdown written for a
static site renders without its `title:` keys becoming the first paragraphs. A
`---` anywhere else is still just a horizontal rule.

Paragraphs following the references heading get an APA-style hanging indent when
`features.hanging_references` is on, so a reference list needs no special markup.

A block quote breaks into paragraphs on a bare `>`, the way Markdown does, not
on every newline - a quote soft-wrapped across five source lines is one
paragraph, not five. Nesting is read from leading whitespace, two spaces per
level by default (`lists.spaces_per_level`).

Anything outside this table (inline links, for example) renders as plain
text. If one of those is needed, extend
`scripts/md2docx.py` rather than working around it in the Markdown - a workaround
in the content file defeats the separation the tool exists for.

## Figures

Image paths resolve **relative to the Markdown file**, not the working
directory, so a document moves between machines without rewriting its links.

A raster image (`.png`, `.jpg`, `.gif`, `.bmp`, `.tif`) is embedded directly. It
is scaled down to the text column when it is wider, and otherwise left at its
natural size - a 120 px screenshot stays small rather than being blown up into a
blurry full-width banner. `images.max_width_cm` caps figures below the column
width when a document wants them smaller.

**SVG is rasterized, not embedded.** Word's own SVG support varies by version
and mangles many generated diagrams, so an SVG - whether referenced by path or
written inline in the Markdown - is rendered to PNG by headless Chrome first.
That needs a Chromium-family browser, found in this order:

1. `images.chrome` in the profile
2. `$MD2DOCX_CHROME`
3. the usual Chrome and Edge install paths

With no browser available, SVG figures are **skipped with a warning on stderr**
and everything else still renders. Read stderr - the document opens fine and the
gap is easy to miss.

`images.scale_factor` (default 2) is the device pixel ratio of the final figure:
a full-column figure lands near 190 dpi, and 3 clears 280 dpi at a larger file
size. An inline `<svg>` with an `aria-label` uses it as the caption when the
Markdown gives none, so an accessible diagram is captioned for free.

## Bundled profiles

| Profile | Format |
| --- | --- |
| `plain` | Clean document, no cover or TOC. The base every other profile extends |
| `report-es` | Spanish report: A4, numbered headings, índice, page numbers, shaded table headers, hanging references. No cover |
| `apa7-es` | APA 7th: Times New Roman 12, double spacing, 2.54 cm margins, hanging references |
| `continental` | Universidad Continental house format: `report-es` plus a cover page, with no deliverable-specific text |
| `continental-pa1` | Universidad Continental PA1: Arial 12, no cover, no TOC |
| `continental-pa2` | A worked example of `continental` filled in for one assignment |

## Format is reusable; cover text is not

A cover names a course, a title, a student and a teacher. Those change with every
deliverable, so they do not belong in a shared profile - reusing a filled-in
profile like `continental-pa2` for a different assignment silently produces a
document with the wrong cover, which looks fine until someone reads it.

Keep the split: extend the house format (`continental`) and supply the cover in a
per-deliverable profile, ideally in the project's own `.md2docx/` directory.

```yaml
extends: continental

cover:
  lines:
    - {text: UNIVERSIDAD CONTINENTAL, bold: true, size: 16}
    - {text: Arquitectura de Software, bold: true, size: 13, before: 36}
    - {text: Diseño Hexagonal de un Sistema de Reservas, bold: true, size: 15, before: 48}
  members:
    - {name: "Apellidos, Nombres", participation: 100 %}
  footer_lines:
    - {text: "Docente: ...", size: 12, before: 36}
```

`lines`, `members` and `footer_lines` are replaced wholesale by a child profile
rather than appended to, so list every cover line the deliverable needs.

## Making a profile for a new format

Profiles compose through `extends`, so a new format is usually a handful of
lines rather than a full copy. Start from the closest existing profile and
override only what the new spec actually changes:

```yaml
extends: report-es

font: {name: Calibri, body_size: 12}
page:
  margins_cm: {top: 3, bottom: 3, left: 3, right: 3}
features: {cover: true}
cover:
  lines:
    - {text: NOMBRE DE LA ORGANIZACIÓN, bold: true, size: 16}
```

Anything not named falls back through the chain to the built-in defaults.

**Where to put it.** Profiles are found by name in this order, nearest first:

1. `./.md2docx/` and `./` - profiles belonging to one project
2. `~/.claude/md2docx/profiles/` - personal profiles reused across projects
3. the skill's own `assets/profiles/` - the bundled set

Nearer scopes shadow further ones, so a project can pin its own `report-es`
without touching the shared copy. Put an institution- or client-specific profile
in scope 1 or 2 rather than editing a bundled profile, which keeps the bundled
ones working as clean starting points.

When format requirements arrive in conversation ("Arial 11, interlineado 1.5,
márgenes 3 cm"), translate them into a profile rather than asking the user to
learn the YAML - then show the profile so they can confirm it matches the spec.

Read `references/profiles.md` for the full key reference before writing a
profile or debugging one that is not behaving.

## Verifying output

A `.docx` is a zip of XML, so it is easy to produce a file that opens fine and
still silently lost a table or dropped the numbering. Two checks worth running:

**Structural check** - confirms nothing was lost:

```python
from docx import Document
d = Document("OUTPUT.docx")
print(len(d.paragraphs), "paragraphs,", len(d.tables), "tables")
```

**Regression check** - when changing the script or a profile, regenerate with the
old version and the new one into a scratch directory, then diff
`word/document.xml` from each zip. Compare generated against generated.
Comparing against a previously delivered `.docx` is misleading, because that file
may have been edited by hand in Word after it was produced.

```python
import zipfile
def xml(p):
    with zipfile.ZipFile(p) as z: return z.read("word/document.xml").decode("utf-8")
print(xml("old.docx") == xml("new.docx"))
```

If the XML differs, check whether the *text* still matches before assuming a
regression - a formatting-only delta is usually intended.

## What the user still does in Word

Be explicit about this when handing over the file, so nothing is missed:

- **The table of contents is a real Word field, and starts empty.** It shows
  "Clic derecho > Actualizar campo" until updated. Select all (Ctrl+E) then F9.
- **Screenshot placeholders are empty boxes** labelled with their key. These now
  appear only where a path resolved to no file, so a box in the output means a
  missing image, not a normal step. Check stderr before handing the file over.

## Verifying figures

A figure is the easiest thing to get silently wrong: the document opens, the
picture is there, and the aspect ratio is off. Check the embedded sizes against
the source rather than eyeballing the page.

```python
from docx import Document
for i, s in enumerate(Document("OUTPUT.docx").inline_shapes, 1):
    print(f"fig {i}: {s.width/360000:.2f} x {s.height/360000:.2f} cm  "
          f"aspect {s.height/s.width:.3f}")
```

Each aspect should match the corresponding SVG's viewBox (`height/width`) or the
source image's own ratio. A figure metres tall, or one squashed flat, means the
sizing was read from the wrong place - see *Gotchas*.

## Gotchas

`python-docx` writes only `w:ascii` and `w:hAnsi` for run fonts. Without
`w:eastAsia`, Word substitutes a different font for some glyphs, which shows up as
inconsistent characters in an otherwise correct document. The script sets it on
every run - preserve that when editing `style_run`.

Word fields (`TOC`, `PAGE`) have no `python-docx` API and are built as raw OOXML
via `OxmlElement`/`qn`. That code looks odd but is load-bearing.

**Column widths must be written to every row, not just the first, and the table
must be taken off autofit.** Word recomputes the grid otherwise and the
computed widths vanish - the document still opens, so this fails quietly.
`python-docx` 1.2 has no `layout_type`; `autofit = False` is what writes
`tblLayout fixed`, and `set_table_width` pins `tblW` alongside it.

Unknown profile keys warn on stderr at every nesting level, so a misspelled key
is reported rather than silently ignored. Read stderr when a setting appears to
have no effect.

**An SVG's size lives on its opening tag only.** Scanning the element for
`width=`/`height=` picks up the first child carrying them, so a
`<rect width="10" height="1000">` becomes the figure's aspect ratio and Word
renders a 15-metre-tall picture. `svg_open_tag` exists to prevent exactly that -
read dimensions through it, never from the raw source.

**A generated SVG usually carries `style="width:100%;height:auto"` inline, and
an inline style beats a stylesheet rule.** The rasterizer therefore opens the
browser window at the SVG's own viewBox size *and* sets the size with
`!important`. Either alone is fragile: headless Chrome screenshots the full
page, so an SVG that resizes itself a pixel past the viewport stretches the
capture. Keep both when editing `rasterize_svg`.

An image path that resolves to no file is warned about and skipped when
`features.image_placeholders` is off. It used to render as literal `![…](…)`
text in the document.
