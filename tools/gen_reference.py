#!/usr/bin/env python3
"""
Generate docs/REFERENCE.md from the LuaLS annotations in the source.

Every element and helper carries a `---@class <name>_args` block with typed
`---@field` lines, so the reference is generated rather than hand-written and
never drifts from the code. Run after changing any element's args:

    python tools/gen_reference.py
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# fields that appear on nearly every element; documented once, filtered per-element
COMMON = {"parent", "id", "x", "y", "gframe", "hidden"}

FIELD_RE = re.compile(r"^---@field\s+(\w+)(\??)\s+(\S+)\s*(.*)$")
CLASS_RE = re.compile(r"^---@class\s+(\w+)")


def parse_args_block(path):
    """Return the constructor's arg fields, or None.

    Detects the args block by content, not name: it's the @class whose @field
    list includes `parent` (every element constructor takes one). This is robust
    to the naming inconsistency where a few classes are not suffixed `_args`
    (e.g. AlarmLight's is `alarm_indicator_light`), and skips non-arg helper
    classes like StateIndicator's `state_text_color`.
    """
    lines = io.open(path, encoding="utf-8").readlines()
    blocks = []          # list of field-lists, one per @class
    current = None
    for line in lines:
        line = line.rstrip("\n")
        if CLASS_RE.match(line):
            current = []
            blocks.append(current)
            continue
        if current is not None:
            fm = FIELD_RE.match(line)
            if fm:
                name, opt, typ, desc = fm.groups()
                current.append((name, opt != "?", typ, desc.strip()))
            elif not line.startswith("---"):
                current = None   # a code line ends this annotation block

    for fields in blocks:
        if any(name == "parent" for name, *_ in fields):
            return fields
    return None


def description(path, is_helper):
    """One-line description from the file's top comment."""
    lines = io.open(path, encoding="utf-8").readlines()
    if is_helper:
        # mimic helpers: "-- mimic - Name" then a blank, then the description sentence
        for i, line in enumerate(lines[:12]):
            t = line.strip().lstrip("-").strip()
            if t and not t.startswith("mimic -") and "mimic -" not in t and t != "":
                # first meaningful sentence
                return t.split(". ")[0].rstrip(".") + "."
        return ""
    else:
        # vendored: "-- X Graphics Element"
        for line in lines[:3]:
            t = line.strip().lstrip("-").strip()
            if t:
                return t
        return ""


def table(fields):
    if not fields:
        return "_No element-specific arguments._\n"
    rows = ["| field | type | required | description |", "|---|---|---|---|"]
    # element-specific first (non-common), keep source order
    for name, req, typ, desc in fields:
        if name in COMMON:
            continue
        rows.append("| `%s` | `%s` | %s | %s |" % (name, typ, "yes" if req else "", desc))
    if len(rows) == 2:
        return "_Only common fields (see top)._\n"
    return "\n".join(rows) + "\n"


def collect(dirpath, is_helper=False):
    out = {}
    for dp, _, files in os.walk(dirpath):
        for f in sorted(files):
            if not f.endswith(".lua"):
                continue
            if f in ("init.lua", "style.lua", "elements.lua"):
                continue
            path = os.path.join(dp, f)
            fields = parse_args_block(path)
            if fields is None:
                continue
            name = f[:-4]
            group = os.path.basename(dp)
            out.setdefault(group, []).append((name, description(path, is_helper), fields))
    return out


def main():
    parts = []
    parts.append("# mimic element reference\n")
    parts.append("_Generated from the source annotations by `tools/gen_reference.py` — "
                 "do not edit by hand._\n")
    parts.append("Every element is a constructor called with a single table of arguments, "
                 "e.g. `m.LED{parent=root, label=\"STATUS\", ...}`. Fields marked **required** "
                 "must be present.\n")
    parts.append("## Common fields\n")
    parts.append("Almost every element accepts these; they are omitted from the per-element "
                 "tables below.\n")
    parts.append("| field | type | description |\n|---|---|---|\n"
                 "| `parent` | `graphics_element` | the container to build into (required for children) |\n"
                 "| `x` / `y` | `integer` | position; auto-placed if omitted |\n"
                 "| `gframe` | `graphics_frame` | x/y/width/height as one frame, instead of separately |\n"
                 "| `fg_bg` | `cpair` | foreground/background colors; inherited from the parent if omitted |\n"
                 "| `hidden` | `boolean` | true to start hidden |\n"
                 "| `id` | `string` | optional element id |\n")

    # mimic helpers
    helpers = collect(os.path.join(ROOT, "mimic"), is_helper=True)
    parts.append("\n## mimic helpers\n")
    parts.append("Higher-level pieces unique to mimic. Prefer these over raw elements.\n")
    for group in sorted(helpers):
        for name, desc, fields in sorted(helpers[group]):
            parts.append("### %s\n" % name)
            if desc:
                parts.append(desc + "\n")
            parts.append(table(fields))

    # vendored elements, grouped by folder
    GROUP_TITLES = {
        "indicators": "Indicators", "controls": "Controls", "form": "Forms",
        "animations": "Animations", "elements": "Containers",
    }
    vend = collect(os.path.join(ROOT, "graphics", "elements"))
    parts.append("\n## Elements (vendored from cc-mek-scada)\n")
    for group in ("elements", "indicators", "controls", "form", "animations"):
        if group not in vend:
            continue
        parts.append("### %s\n" % GROUP_TITLES.get(group, group))
        for name, desc, fields in sorted(vend[group]):
            parts.append("#### %s\n" % name)
            if desc:
                parts.append("_%s_\n" % desc)
            parts.append(table(fields))

    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    outpath = os.path.join(ROOT, "docs", "REFERENCE.md")
    io.open(outpath, "w", encoding="utf-8").write("\n".join(parts))
    n_help = sum(len(v) for v in helpers.values())
    n_vend = sum(len(v) for v in vend.values())
    print("wrote docs/REFERENCE.md: %d helpers, %d elements" % (n_help, n_vend))


if __name__ == "__main__":
    main()
