"""Markdown -> DOCX converter driven by a YAML format profile.

The Markdown file carries only content. Every formatting decision - fonts,
margins, cover page, table of contents, heading numbering - lives in a
profile, so one document can be re-rendered against different course briefs
without editing the source text.

Usage:
    py md2docx.py INPUT.md -o OUTPUT.docx -p profiles/continental-pa2.yaml
"""

from __future__ import annotations

import argparse
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml
from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Emu, Pt, RGBColor

BLACK = RGBColor(0, 0, 0)

INLINE = re.compile(r"(`[^`]+`|\*\*.+?\*\*|\*.+?\*)")
CODE_FONT = "Consolas"
IMAGE = re.compile(r"^!\[(.*?)\]\((.+?)\)$")
# Leading whitespace is captured, not skipped: it carries the nesting level.
BULLET = re.compile(r"^(\s*)[-*]\s+(.*)$")
NUMBERED = re.compile(r"^(\s*)(\d+)\.\s+(.*)$")
QUOTE = re.compile(r"^>\s?(.*)$")
RULE = re.compile(r"^-{3,}$")

# Raster formats Word embeds directly. SVG is handled separately: Word's own SVG
# support depends on the Word version, so it is rasterized instead of embedded.
RASTER_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tif", ".tiff"}

SVG_OPEN = re.compile(r"^\s*<svg\b", re.IGNORECASE)
SVG_CLOSE = re.compile(r"</svg\s*>", re.IGNORECASE)
SVG_VIEWBOX = re.compile(r'viewBox\s*=\s*["\']([-\d.eE]+[\s,]+[-\d.eE]+[\s,]+[-\d.eE]+[\s,]+[-\d.eE]+)["\']',
                         re.IGNORECASE)
SVG_ATTR_SIZE = re.compile(r'\b(width|height)\s*=\s*["\']([\d.]+)(?:px)?["\']', re.IGNORECASE)
SVG_ARIA_LABEL = re.compile(r'aria-label\s*=\s*["\']([^"\']*)["\']', re.IGNORECASE)

# A leading YAML frontmatter block is metadata for the site that owns the
# Markdown, not document content - rendering its keys as paragraphs would put
# "title: ..." at the top of the Word file.
FRONTMATTER_FENCE = re.compile(r"^---\s*$")

ALIGN = {
    "justify": WD_ALIGN_PARAGRAPH.JUSTIFY,
    "left": WD_ALIGN_PARAGRAPH.LEFT,
    "center": WD_ALIGN_PARAGRAPH.CENTER,
    "right": WD_ALIGN_PARAGRAPH.RIGHT,
}

DEFAULTS = {
    "font": {
        "name": "Arial",
        "body_size": 11,
        "table_size": 9,
        "heading_sizes": {1: 12, 2: 11, 3: 11},
    },
    # Any page value left as None keeps the python-docx default.
    "page": {
        "width_cm": None,
        "height_cm": None,
        "margins_cm": {"top": None, "bottom": None, "left": None, "right": None},
    },
    "body": {"line_spacing": 1.5, "space_after": 6, "align": "justify"},
    "headings": {
        "align": "left",
        "space_before": 12,
        "space_after": 6,
        "keep_with_next": True,
        "numbering": False,
        "unnumbered": [],
        "page_break_before_unnumbered": True,
    },
    "tables": {
        "header_fill": None,
        "line_spacing": 1.0,
        "align": "center",
        # Size columns from their content instead of splitting the width
        # evenly. False restores Word's own layout.
        "fit_columns": True,
        "min_column_cm": 1.2,
    },
    "lists": {
        "number_indent_cm": 0.9,
        "number_hanging_cm": 0.6,
        # Added per nesting level, for both bullets and numbers.
        "nest_indent_cm": 0.75,
        # How many leading spaces the source uses for one level.
        "spaces_per_level": 2,
    },
    "quotes": {
        "left_indent_cm": 1.0,
        "right_indent_cm": 0.0,
        "italic": False,
        # None follows the body text.
        "size": None,
        "line_spacing": None,
        "space_after": None,
        "align": "justify",
    },
    "references": {"heading": "Referencias", "hanging_cm": 1.27},
    "images": {
        "fill": "F2F2F2",
        "caption_size": 10,
        "box_lines": 3,
        # None fits a figure to the text column; a number caps it below that.
        "max_width_cm": None,
        # Device pixel ratio used when rasterizing SVG, so the PNG stays sharp
        # in print. 2 matches the text column at roughly 300 dpi.
        "scale_factor": 2,
        # Browser used to rasterize SVG. None searches the usual install paths.
        "chrome": None,
        # Fall back to the SVG's aria-label when the figure has no caption.
        "svg_caption_from_aria": True,
    },
    "toc": {"depth": "1-2", "heading": "Índice", "placeholder": "Clic derecho > Actualizar campo"},
    "features": {
        "cover": False,
        "toc": False,
        "page_numbers": False,
        "image_placeholders": False,
        "hanging_references": False,
    },
    "cover": {"lines": [], "members": [], "members_header": None, "footer_lines": []},
}


PROFILE_SUFFIXES = (".yaml", ".yml")

# Sections whose keys are author-defined rather than fixed, so they are not
# spell-checked against DEFAULTS.
FREEFORM_KEYS = {"heading_sizes", "lines", "members", "members_header", "footer_lines"}


def warn(message: str) -> None:
    """Report a recoverable problem on stderr without failing the render.

    A figure that could not be drawn must be loud, because the document still
    opens fine without it and the gap is easy to miss.
    """
    print(f"warning: {message}", file=sys.stderr)


def deep_merge(base: dict, override: dict) -> dict:
    """Recursively merge override into a copy of base."""
    result = dict(base)
    for key, value in (override or {}).items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def profile_dirs() -> list[Path]:
    """Where a profile name is looked up, nearest scope first.

    A project can shadow a bundled profile by name, which lets one repository
    pin its own house style without editing the shared copy.
    """
    here = Path(__file__).resolve().parent
    return [
        Path.cwd() / ".md2docx",
        Path.cwd(),
        Path.home() / ".claude" / "md2docx" / "profiles",
        here.parent / "assets" / "profiles",  # bundled inside a skill
        here / "profiles",                    # bundled next to the script
    ]


def available_profiles() -> dict[str, Path]:
    """Profile name -> file, with nearer scopes winning."""
    found: dict[str, Path] = {}
    for directory in profile_dirs():
        if not directory.is_dir():
            continue
        for suffix in PROFILE_SUFFIXES:
            for path in sorted(directory.glob(f"*{suffix}")):
                found.setdefault(path.stem, path)
    return found


def resolve_profile(value: str) -> Path:
    """Accept either a path or a bare profile name."""
    direct = Path(value)
    if direct.is_file():
        return direct
    name = direct.stem if direct.suffix in PROFILE_SUFFIXES else direct.name
    match = available_profiles().get(name)
    if match:
        return match
    known = ", ".join(sorted(available_profiles())) or "none found"
    raise FileNotFoundError(f"profile not found: {value}\navailable: {known}")


def validate_keys(node, reference, source: Path, trail: str = "") -> None:
    """Warn on keys that do not exist in DEFAULTS.

    Silently ignoring a typo is the worst outcome here: the document renders,
    looks plausible, and quietly misses a rubric requirement.
    """
    if not isinstance(node, dict) or not isinstance(reference, dict):
        return
    for key, value in node.items():
        if key not in reference:
            warn(f"{source.name}: unknown key '{trail}{key}' ignored")
            continue
        if key not in FREEFORM_KEYS:
            validate_keys(value, reference[key], source, f"{trail}{key}.")


def read_profile(path: Path, seen: set[Path] | None = None) -> dict:
    """Read one profile, resolving its `extends` chain first."""
    seen = set() if seen is None else seen
    resolved = path.resolve()
    if resolved in seen:
        raise ValueError(f"circular extends involving {path.name}")
    seen.add(resolved)

    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    parent = raw.pop("extends", None)
    validate_keys(raw, DEFAULTS, path)
    if parent:
        return deep_merge(read_profile(resolve_profile(parent), seen), raw)
    return raw


def load_profile(value: str | None) -> dict:
    if value is None:
        return DEFAULTS
    profile = deep_merge(DEFAULTS, read_profile(resolve_profile(value)))
    profile["font"]["heading_sizes"] = {
        int(k): v for k, v in profile["font"]["heading_sizes"].items()
    }
    return profile


# ---------------------------------------------------------------- SVG raster

CHROME_CANDIDATES = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "msedge",
)


def find_chrome(configured: str | None = None) -> str | None:
    """Locate a Chromium-family browser to rasterize SVG with.

    Precedence: the profile's `images.chrome`, then $MD2DOCX_CHROME, then the
    usual install locations. Returns None when none of them resolve, which the
    caller reports as a skipped figure rather than a crash.
    """
    for candidate in (configured, os.environ.get("MD2DOCX_CHROME")):
        if candidate:
            found = shutil.which(candidate) or (candidate if Path(candidate).is_file() else None)
            if found:
                return found
            warn(f"browser not found at {candidate}")
    for candidate in CHROME_CANDIDATES:
        found = shutil.which(candidate) or (candidate if Path(candidate).is_file() else None)
        if found:
            return found
    return None


def svg_open_tag(svg: str) -> str:
    """Just the opening `<svg ...>` tag.

    Sizing must be read from this tag alone. Scanning the whole element instead
    picks up the width/height of the first child that happens to carry them -
    a `<rect width="10" height="1000">` silently becomes the figure's aspect
    ratio.
    """
    match = re.search(r"<svg\b[^>]*>", svg, re.IGNORECASE | re.DOTALL)
    return match.group(0) if match else svg[:2000]


def svg_dimensions(svg: str) -> tuple[float, float]:
    """Intrinsic width/height of an SVG, for its aspect ratio.

    Explicit width/height attributes win; otherwise the viewBox supplies them.
    Percentage widths (`width="100%"`) do not match the attribute pattern, so a
    responsive SVG correctly falls through to its viewBox.
    """
    tag = svg_open_tag(svg)
    attrs = {m.group(1).lower(): float(m.group(2)) for m in SVG_ATTR_SIZE.finditer(tag)}
    if attrs.get("width") and attrs.get("height"):
        return attrs["width"], attrs["height"]

    box = SVG_VIEWBOX.search(tag)
    if box:
        parts = [float(n) for n in re.split(r"[\s,]+", box.group(1).strip())]
        if len(parts) == 4 and parts[2] > 0 and parts[3] > 0:
            return parts[2], parts[3]

    warn("SVG has neither usable width/height nor viewBox; assuming 4:3")
    return 960.0, 720.0


def rasterize_svg(svg: str, width_px: int, chrome: str, scale: float = 2) -> bytes | None:
    """Render SVG source to PNG bytes with headless Chrome.

    Word's SVG support varies by version and breaks on many generated diagrams,
    so the source is rendered by a real browser engine instead.

    Two details make the output size exact. The window is opened at the SVG's
    own viewBox size rather than the target column width, because headless
    Chrome screenshots the full page and any overflow of a pixel would stretch
    the capture. And the size is applied with `!important`, because a generated
    SVG usually carries an inline `style="width:100%;height:auto"` that would
    otherwise beat a plain stylesheet rule and resize itself to the viewport.

    `scale` is the device pixel ratio of the final figure, so the PNG comes out
    `width_px * scale` wide regardless of the viewBox: at the default 2 a
    full-column figure lands near 190 dpi in print, and 3 clears 280 dpi.
    """
    natural_w, natural_h = svg_dimensions(svg)
    window_w, window_h = max(1, round(natural_w)), max(1, round(natural_h))
    # Chrome renders the viewBox-sized window; the device ratio is what scales
    # it up to the pixel width the figure actually needs.
    device_scale = min(5.0, max(1.0, width_px * scale / natural_w))

    html = (
        "<!doctype html><meta charset='utf-8'>"
        "<style>html,body{margin:0;padding:0;background:#fff;overflow:hidden}"
        f"svg{{display:block!important;width:{window_w}px!important;"
        f"height:{window_h}px!important;max-width:none!important}}</style>{svg}"
    )

    with tempfile.TemporaryDirectory(prefix="md2docx-svg-") as tmp:
        html_path = Path(tmp) / "figure.html"
        png_path = Path(tmp) / "figure.png"
        html_path.write_text(html, encoding="utf-8")
        command = [
            chrome,
            "--headless=new", "--disable-gpu", "--hide-scrollbars",
            f"--force-device-scale-factor={device_scale:.4f}",
            f"--window-size={window_w},{window_h}",
            f"--screenshot={png_path}",
            html_path.as_uri(),
        ]
        try:
            subprocess.run(command, check=True, capture_output=True, timeout=120)
        except subprocess.TimeoutExpired:
            warn("browser timed out rasterizing an SVG figure")
            return None
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or b"").decode("utf-8", "replace").strip().splitlines()
            warn(f"browser failed to rasterize an SVG figure: {detail[-1] if detail else exc}")
            return None
        if not png_path.is_file():
            warn("browser produced no PNG for an SVG figure")
            return None
        return png_path.read_bytes()


class DocxRenderer:
    """Renders a Markdown line stream into a python-docx Document."""

    def __init__(self, profile: dict):
        self.p = profile
        self.font = profile["font"]["name"]
        self.body_size = Pt(profile["font"]["body_size"])
        self.table_size = Pt(profile["font"]["table_size"])
        self.doc = Document()
        self._setup()

    # ---------- low-level helpers ----------

    def style_run(self, run, bold=False, italic=False, size=None, font=None):
        run.font.name = font or self.font
        # python-docx only writes w:ascii/w:hAnsi; w:eastAsia must be set by hand
        # or Word falls back to a different font for some glyphs.
        run._element.rPr.rFonts.set(qn("w:eastAsia"), font or self.font)
        run.font.size = size or self.body_size
        run.font.color.rgb = BLACK
        run.bold = bold
        run.italic = italic
        return run

    def add_inline(self, paragraph, text, base_bold=False, size=None):
        """Split a line on `code` / **bold** / *italic* markers and add styled runs."""
        for chunk in INLINE.split(text):
            if not chunk:
                continue
            if chunk.startswith("`") and chunk.endswith("`") and len(chunk) > 2:
                self.style_run(paragraph.add_run(chunk[1:-1]), bold=base_bold, size=size, font=CODE_FONT)
            elif chunk.startswith("**") and chunk.endswith("**"):
                self.style_run(paragraph.add_run(chunk[2:-2]), bold=True, size=size)
            elif chunk.startswith("*") and chunk.endswith("*") and len(chunk) > 2:
                self.style_run(paragraph.add_run(chunk[1:-1]), italic=True, size=size)
            else:
                self.style_run(paragraph.add_run(chunk), bold=base_bold, size=size)
        return paragraph

    def fmt(self, paragraph, spacing=None, after=None, before=0, align="justify"):
        paragraph.alignment = ALIGN[align]
        pf = paragraph.paragraph_format
        pf.line_spacing = self.p["body"]["line_spacing"] if spacing is None else spacing
        pf.space_after = Pt(self.p["body"]["space_after"] if after is None else after)
        pf.space_before = Pt(before)
        return paragraph

    def add_field(self, paragraph, instr):
        """Insert a Word field (TOC, PAGE) as raw OOXML - python-docx has no API."""
        run = paragraph.add_run()
        parts = (
            ("w:fldChar", "begin"),
            ("w:instrText", instr),
            ("w:fldChar", "separate"),
            ("w:t", self.p["toc"]["placeholder"]),
            ("w:fldChar", "end"),
        )
        for tag, attr in parts:
            el = OxmlElement(tag)
            if tag == "w:fldChar":
                el.set(qn("w:fldCharType"), attr)
            else:
                el.set(qn("xml:space"), "preserve")
                el.text = attr
            run._r.append(el)
        self.style_run(run)

    def set_table_width(self, table, emu):
        """Pin the table's own width, in twentieths of a point.

        `autofit = False` alone leaves `tblW` at `auto`, and Word then still
        reflows the grid on some documents. Stating both settles it.
        """
        tbl_pr = table._tbl.tblPr
        for existing in tbl_pr.findall(qn("w:tblW")):
            tbl_pr.remove(existing)
        width = OxmlElement("w:tblW")
        width.set(qn("w:type"), "dxa")
        width.set(qn("w:w"), str(int(emu / 635)))  # 1 dxa = 635 EMU
        tbl_pr.append(width)

    def shade(self, cell, hex_fill):
        tc_pr = cell._tc.get_or_add_tcPr()
        shd = OxmlElement("w:shd")
        shd.set(qn("w:val"), "clear")
        shd.set(qn("w:color"), "auto")
        shd.set(qn("w:fill"), hex_fill)
        tc_pr.append(shd)

    def page_break(self):
        self.doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)

    # ---------- document setup ----------

    def _setup(self):
        normal = self.doc.styles["Normal"]
        normal.font.name = self.font
        normal.font.size = self.body_size
        normal.element.rPr.rFonts.set(qn("w:eastAsia"), self.font)
        for level in (1, 2, 3):
            style = self.doc.styles[f"Heading {level}"]
            style.font.name = self.font
            style.font.color.rgb = BLACK
            style.element.rPr.rFonts.set(qn("w:eastAsia"), self.font)

        page = self.p["page"]
        sec = self.doc.sections[0]
        if page["width_cm"]:
            sec.page_width = Cm(page["width_cm"])
        if page["height_cm"]:
            sec.page_height = Cm(page["height_cm"])
        for side in ("top", "bottom", "left", "right"):
            value = (page["margins_cm"] or {}).get(side)
            if value:
                setattr(sec, f"{side}_margin", Cm(value))

        if self.p["features"]["page_numbers"]:
            footer = self.fmt(sec.footer.paragraphs[0], spacing=1.0, after=0, align="right")
            self.add_field(footer, "PAGE")
            # Keeps the page number off the cover page.
            sec.different_first_page_header_footer = True

    # ---------- block builders ----------

    def add_body(self, text, style=None, align=None):
        align = align or self.p["body"]["align"]
        p = self.fmt(self.doc.add_paragraph(style=style), align=align)
        return self.add_inline(p, text)

    def add_reference(self, text):
        p = self.add_body(text, align="left")
        hanging = Cm(self.p["references"]["hanging_cm"])
        p.paragraph_format.left_indent = hanging
        p.paragraph_format.first_line_indent = -hanging
        return p

    def nest_level(self, indent: str) -> int:
        """How deep a list item sits, from its leading whitespace.

        A tab counts as one full level; spaces are divided by
        `lists.spaces_per_level`. Capped at 2 because Word's built-in list
        styles stop at three levels.
        """
        per = max(1, self.p["lists"]["spaces_per_level"])
        width = sum(per if ch == "\t" else 1 for ch in indent)
        return min(2, width // per)

    def add_bullet(self, text, level=0):
        style = "List Bullet" if level == 0 else f"List Bullet {level + 1}"
        p = self.add_body(text, style=style)
        if level:
            p.paragraph_format.left_indent = Cm(
                self.p["lists"]["nest_indent_cm"] * (level + 1))
        return p

    def add_numbered(self, number, text, level=0):
        cfg = self.p["lists"]
        p = self.add_body(f"{number}. {text}")
        p.paragraph_format.left_indent = Cm(
            cfg["number_indent_cm"] + cfg["nest_indent_cm"] * level)
        p.paragraph_format.first_line_indent = -Cm(cfg["number_hanging_cm"])
        return p

    def add_quote(self, text):
        """A block quote: indented, never carrying its `>` into the document."""
        cfg = self.p["quotes"]
        p = self.fmt(self.doc.add_paragraph(), spacing=cfg["line_spacing"],
                     after=cfg["space_after"], align=cfg["align"])
        p.paragraph_format.left_indent = Cm(cfg["left_indent_cm"])
        p.paragraph_format.right_indent = Cm(cfg["right_indent_cm"])
        size = Pt(cfg["size"]) if cfg["size"] else None
        self.add_inline(p, text, size=size)
        if cfg["italic"]:
            for run in p.runs:
                run.italic = True
        return p

    def add_heading(self, text, level):
        cfg = self.p["headings"]
        p = self.fmt(self.doc.add_paragraph(style=f"Heading {level}"),
                     before=cfg["space_before"], after=cfg["space_after"],
                     align=cfg["align"])
        p.paragraph_format.keep_with_next = cfg["keep_with_next"]
        size = self.p["font"]["heading_sizes"].get(level, self.p["font"]["body_size"])
        return self.add_inline(p, text, base_bold=True, size=Pt(size))

    def add_table(self, header, body_rows):
        cfg = self.p["tables"]
        table = self.doc.add_table(rows=1, cols=len(header))
        table.style = "Table Grid"
        table.alignment = ALIGN[cfg["align"]]

        parsed = [split_row(row) for row in body_rows]
        widths = None
        if cfg["fit_columns"]:
            widths = column_widths([header] + parsed, int(self.content_width()),
                                   int(Cm(cfg["min_column_cm"])))
            # Word recomputes a table it is allowed to autofit, and it honours
            # per-cell widths only when every row carries them.
            table.autofit = False
            self.set_table_width(table, sum(widths))

        def fill(cells, values, bold=False, shade=False):
            for index, (cell, text) in enumerate(zip(cells, values)):
                if shade and cfg["header_fill"]:
                    self.shade(cell, cfg["header_fill"])
                if widths:
                    cell.width = Emu(widths[index])
                p = self.fmt(cell.paragraphs[0], spacing=cfg["line_spacing"],
                             after=0, align="left")
                self.add_inline(p, text, base_bold=bold, size=self.table_size)

        fill(table.rows[0].cells, header, bold=True, shade=True)
        for row in parsed:
            fill(table.add_row().cells, row)
        self.fmt(self.doc.add_paragraph(), after=0)

    def add_image_placeholder(self, caption, key):
        cfg = self.p["images"]
        table = self.doc.add_table(rows=1, cols=1)
        table.style = "Table Grid"
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = table.rows[0].cells[0]
        self.shade(cell, cfg["fill"])
        p = self.fmt(cell.paragraphs[0], spacing=1.0, after=0, align="center")
        for _ in range(cfg["box_lines"]):
            p.add_run().add_break()
        self.add_inline(p, f"[PEGAR AQUÍ LA CAPTURA: {key}]", base_bold=True)
        for _ in range(cfg["box_lines"]):
            p.add_run().add_break()
        self.add_caption(caption)

    # ---------- figures ----------

    def content_width(self) -> Emu:
        """The text column: page width less both margins."""
        sec = self.doc.sections[0]
        return Emu(sec.page_width - sec.left_margin - sec.right_margin)

    def figure_width(self) -> Emu:
        """Widest a figure may be: the text column, or `images.max_width_cm`.

        Tables use `content_width` instead - capping figures must not narrow
        the tables along with them.
        """
        content = self.content_width()
        cap = self.p["images"]["max_width_cm"]
        return Emu(min(content, Cm(cap))) if cap else content

    def figure_width_px(self) -> int:
        """The figure width in CSS pixels, for sizing the SVG before raster."""
        return max(1, round(self.figure_width() / 914400 * 96))

    def add_caption(self, caption: str | None):
        if not caption:
            return
        p = self.fmt(self.doc.add_paragraph(), spacing=1.0, after=10, before=4, align="center")
        self.add_inline(p, f"*{caption}*", size=Pt(self.p["images"]["caption_size"]))
        return p

    def add_figure(self, source, caption: str | None = None, fit: bool = False):
        """Place an image, centered, captioned, never wider than the column.

        A picture narrower than the column keeps its natural size, so a small
        screenshot is not blown up into a blurry full-width banner. `fit` forces
        the figure to the full column width instead, which is what a rasterized
        SVG wants: it was rendered at exactly that width, and its pixel
        dimensions carry a device scale factor rather than a real print size.
        """
        shape = self.doc.add_picture(source)
        limit = self.figure_width()
        if fit or shape.width > limit:
            shape.height = Emu(round(shape.height * limit / shape.width))
            shape.width = limit
        self.fmt(self.doc.paragraphs[-1], spacing=1.0, after=0, align="center")
        self.add_caption(caption)
        return shape

    def add_cover(self):
        cfg = self.p["cover"]

        def line(spec):
            p = self.fmt(self.doc.add_paragraph(), spacing=1.15,
                         before=spec.get("before", 0), after=spec.get("after"),
                         align=spec.get("align", "center"))
            self.style_run(p.add_run(spec["text"]), bold=spec.get("bold", False),
                           size=Pt(spec["size"]) if spec.get("size") else None)

        for spec in cfg["lines"]:
            line(spec)

        if cfg["members"]:
            header = cfg["members_header"] or ["Integrante", "% de participación"]
            self.fmt(self.doc.add_paragraph(), before=48)
            table = self.doc.add_table(rows=1, cols=len(header))
            table.style = "Table Grid"
            table.alignment = WD_TABLE_ALIGNMENT.CENTER
            for cell, text in zip(table.rows[0].cells, header):
                if self.p["tables"]["header_fill"]:
                    self.shade(cell, self.p["tables"]["header_fill"])
                p = self.fmt(cell.paragraphs[0], spacing=1.0, after=0, align="center")
                self.add_inline(p, text, base_bold=True)
            for member in cfg["members"]:
                cells = table.add_row().cells
                values = [member.get("name", ""), member.get("participation", "")]
                for cell, text in zip(cells, values):
                    p = self.fmt(cell.paragraphs[0], spacing=1.0, after=0, align="center")
                    self.add_inline(p, text)

        for spec in cfg["footer_lines"]:
            line(spec)
        self.page_break()

    def add_toc(self):
        cfg = self.p["toc"]
        p = self.fmt(self.doc.add_paragraph(), align="center")
        self.style_run(p.add_run(cfg["heading"]), bold=True,
                       size=Pt(self.p["font"]["heading_sizes"].get(1, 12)))
        self.add_field(self.fmt(self.doc.add_paragraph(), align="left"),
                       f'TOC \\o "{cfg["depth"]}" \\h \\z \\u')
        self.page_break()


def split_row(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def column_widths(rows: list[list[str]], total: int, floor: int) -> list[int]:
    """Split `total` EMU across columns according to how much text they hold.

    Splitting evenly is what makes a wide table unreadable: a nine-column
    table gives an 87-character cell the same 1.7 cm as a two-character one,
    and that cell becomes a nine-line-tall paragraph.

    Demand is softened with an exponent because a cell's text wraps - twice
    the characters needs noticeably less than twice the width. Every column
    then gets at least `floor`, paid for by the widest ones, so a narrow
    column stays readable instead of being squeezed to nothing.
    """
    n = max(len(r) for r in rows)
    if n * floor >= total:  # too many columns to honour the floor
        return [total // n] * n

    demand = [max((len(r[c]) for r in rows if c < len(r)), default=1) or 1
              for c in range(n)]
    soft = [d ** 0.6 for d in demand]
    widths = [total * s / sum(soft) for s in soft]

    # Lift short columns to the floor, taking the difference from whichever
    # columns still have slack, in proportion to how much slack they have.
    for _ in range(n):
        deficit = sum(floor - w for w in widths if w < floor)
        if deficit <= 0:
            break
        slack = sum(w - floor for w in widths if w > floor)
        if slack <= 0:
            break
        widths = [w - deficit * (w - floor) / slack if w > floor else w
                  for w in widths]
        widths = [max(w, floor) for w in widths]

    out = [int(round(w)) for w in widths]
    out[out.index(max(out))] += total - sum(out)  # rounding drift
    return out


def strip_frontmatter(lines: list[str]) -> list[str]:
    """Drop a leading `---` YAML block, keeping a horizontal rule intact.

    Only a fence on the very first line opens frontmatter, so a `---` used as a
    section separator further down is left for the normal RULE handling.
    """
    if not lines or not FRONTMATTER_FENCE.match(lines[0]):
        return lines
    for index in range(1, len(lines)):
        if FRONTMATTER_FENCE.match(lines[index]):
            return lines[index + 1:]
    return lines


def convert(src: Path, dst: Path, profile: dict) -> None:
    src = Path(src)
    lines = strip_frontmatter(src.read_text(encoding="utf-8").splitlines())
    r = DocxRenderer(profile)
    features = profile["features"]
    headings = profile["headings"]
    unnumbered = set(headings["unnumbered"])
    images = profile["images"]

    # Resolved lazily: a document with no SVG must not require a browser.
    chrome_path: str | None = None
    chrome_checked = False

    def chrome() -> str | None:
        nonlocal chrome_path, chrome_checked
        if not chrome_checked:
            chrome_path = find_chrome(images["chrome"])
            chrome_checked = True
            if chrome_path is None:
                warn("no Chrome/Edge found - SVG figures will be skipped. "
                     "Set images.chrome in the profile or $MD2DOCX_CHROME.")
        return chrome_path

    def draw_svg(svg: str) -> None:
        caption = None
        if images["svg_caption_from_aria"]:
            label = SVG_ARIA_LABEL.search(svg_open_tag(svg))
            caption = label.group(1).strip() if label else None
        browser = chrome()
        if browser is None:
            return
        png = rasterize_svg(svg, r.figure_width_px(), browser, images["scale_factor"])
        if png is None:
            return
        r.add_figure(io.BytesIO(png), caption, fit=True)

    if features["cover"]:
        r.add_cover()
    if features["toc"]:
        r.add_toc()

    h1 = h2 = 0
    in_refs = False
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()

        if not line or RULE.match(line):
            i += 1
            continue

        if line.startswith("|"):
            block = []
            while i < len(lines) and lines[i].startswith("|"):
                block.append(lines[i])
                i += 1
            r.add_table(split_row(block[0]), block[2:])
            continue

        # An inline <svg> block. Collected verbatim including blank lines, which
        # are legal inside the element and common in generated diagrams.
        if SVG_OPEN.match(line):
            block = []
            while i < len(lines):
                block.append(lines[i])
                closed = SVG_CLOSE.search(lines[i])
                i += 1
                if closed:
                    break
            else:
                warn("unterminated <svg> block at end of file; figure skipped")
                continue
            draw_svg("\n".join(block))
            continue

        image = IMAGE.match(line)
        if image:
            caption, target = image.group(1).strip(), image.group(2).strip()
            source = (src.parent / target).expanduser()
            suffix = source.suffix.lower()
            if suffix == ".svg" and source.is_file():
                draw_svg(source.read_text(encoding="utf-8"))
                i += 1
                continue
            if suffix in RASTER_SUFFIXES and source.is_file():
                r.add_figure(str(source), caption or None)
                i += 1
                continue
            if features["image_placeholders"]:
                if suffix in RASTER_SUFFIXES or suffix == ".svg":
                    warn(f"image not found, placeholder used instead: {source}")
                r.add_image_placeholder(caption, target)
                i += 1
                continue
            warn(f"image not found and placeholders are off, skipped: {source}")
            i += 1
            continue

        if line.startswith("#"):
            level = len(line) - len(line.lstrip("#"))
            text = line.lstrip("#").strip()
            if headings["numbering"] and level == 1:
                in_refs = text == profile["references"]["heading"]
                if text in unnumbered:
                    if headings["page_break_before_unnumbered"]:
                        r.page_break()
                    r.add_heading(text, 1)
                else:
                    h1 += 1
                    h2 = 0
                    r.add_heading(f"{h1}. {text}", 1)
            elif headings["numbering"] and level == 2 and h1 and not text.startswith("Anexo"):
                h2 += 1
                r.add_heading(f"{h1}.{h2}. {text}", 2)
            else:
                r.add_heading(text, min(level, 3))
            i += 1
            continue

        # A block quote, joined across the lines it was soft-wrapped over: in
        # Markdown a quote breaks into paragraphs on a bare `>`, not on every
        # newline, so rendering one paragraph per source line would shred it.
        if QUOTE.match(line):
            chunk: list[str] = []
            while i < len(lines):
                quoted = QUOTE.match(lines[i].rstrip())
                if not quoted:
                    break
                i += 1
                piece = quoted.group(1).strip()
                if piece:
                    chunk.append(piece)
                elif chunk:
                    r.add_quote(" ".join(chunk))
                    chunk = []
            if chunk:
                r.add_quote(" ".join(chunk))
            continue

        bullet = BULLET.match(line)
        if bullet:
            r.add_bullet(bullet.group(2), r.nest_level(bullet.group(1)))
            i += 1
            continue

        numbered = NUMBERED.match(line)
        if numbered:
            r.add_numbered(numbered.group(2), numbered.group(3),
                           r.nest_level(numbered.group(1)))
            i += 1
            continue

        if in_refs and features["hanging_references"]:
            r.add_reference(line)
        else:
            r.add_body(line)
        i += 1

    r.doc.save(dst)
    print(f"OK -> {dst}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Convert a Markdown document to DOCX using a YAML format profile.")
    parser.add_argument("input", type=Path, nargs="?", help="source Markdown file")
    parser.add_argument("-o", "--output", type=Path,
                        help="target .docx (default: input name with .docx)")
    parser.add_argument("-p", "--profile",
                        help="profile name or path (default: plain built-in defaults)")
    parser.add_argument("--list-profiles", action="store_true",
                        help="list the profiles visible from here and exit")
    args = parser.parse_args(argv)

    if args.list_profiles:
        profiles = available_profiles()
        if not profiles:
            print("no profiles found")
        for name, path in sorted(profiles.items()):
            print(f"{name:24} {path}")
        return 0

    if args.input is None:
        parser.error("input is required")
    if not args.input.is_file():
        parser.error(f"input not found: {args.input}")

    try:
        profile = load_profile(args.profile)
    except (FileNotFoundError, ValueError) as exc:
        parser.error(str(exc))

    output = args.output or args.input.with_suffix(".docx")
    convert(args.input, output, profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
