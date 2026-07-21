# Layout

Helpers that place things, so you stop hand-computing coordinates. Each returns the
container(s) to build into. Full argument lists are in the [element reference](REFERENCE.md).

## Panel

A titled, bordered box — the signature dashboard look.

```lua
local content = mimic.Panel{parent=root, x=1, y=1, width=30, height=12,
                            title="REACTOR", accent=colors.cyan}
-- build into `content`; it is the interior, already past the border + title:
m.LED{parent=content, x=2, y=1, label="ONLINE", colors=mimic.style.ind_grn}
```

`content.get_width()` / `get_height()` report the **usable** interior (the border and title
are already subtracted), so you can size children against them without guessing. Omit `title`
for a bordered box with no title bar. `accent` colors the border and title.

## Row

Cells left to right, so you stop writing `x = 2 + (i-1)*40`. Either equal columns or explicit
widths.

```lua
-- four equal columns across the width:
local cols = mimic.Row{parent=root, y=3, height=14, count=4, gap=1}
for i = 1, 4 do
    mimic.Panel{parent=cols[i], x=1, y=1, width=cols[i].get_width(), height=14,
                title="NODE " .. i}
end

-- explicit widths; a 0 shares the leftover equally:
local cells = mimic.Row{parent=root, y=3, height=6, widths={12, 0, 12}, gap=2}
```

Returns the cells (as `Div`s) and the container.

## Grid

A grid of equal cells — repeat a widget N times without computing every `x`/`y`.

```lua
local cells = mimic.Grid{parent=root, x=2, y=3, width=160, height=40,
                         cols=4, rows=2, gap_x=1, gap_y=1}
-- cells is row-major, and also callable as cells(col, row):
mimic.Panel{parent=cells(1, 1), x=1, y=1, width=cells(1,1).get_width(), height=cells(1,1).get_height()}
```

## Tabs

A tab bar over a stack of pages — a fixed, named set. Returns the pages, addressable by name
or index; children inherit `ps`.

```lua
local pages = mimic.Tabs{parent=panel, y=2, min_width=7, tabs={
    { name="SVR" }, { name="NODE" }, { name="NET" }, { name="INF" },
}}

m.LED{parent=pages["SVR"], x=2, y=2, label="STATUS", bind="status", colors=mimic.style.ind_grn}
m.TextBox{parent=pages[2], x=2, y=2, width=20, text="..."}   -- by index also works
```

Use `Tabs` when the set of pages is known and named. For paging through *data* (many chambers,
N per page), use `Paginator`.

## Paginator

Pages through a **list of items**, N per page, with prev/next nav. For when there are more
things to show than fit on one screen.

```lua
local chambers = { ... }   -- your data

mimic.Paginator{parent=box, x=1, y=1, width=W, height=H,
    items = chambers, per_page = 6, cols = 3,
    render = function (slot, chamber, index)
        mimic.Panel{parent=slot, x=1, y=1, width=slot.get_width(), height=slot.get_height(),
                    title=chamber.name}
        -- ... build this item's widgets into `slot` ...
    end}
```

- `per_page` slots are laid out in a `cols`-wide grid on each page.
- `render(slot, item, index)` fills one slot; called once per item up front.
- Returns a table with `page(n)`, `next()`, `prev()`, `current()`, `page_count`.

All pages are built up front (hidden) and nav switches between them — no per-flip rebuild.
**Bound elements work on hidden pages**: a value published while page 3 is hidden shows
correctly the moment you flip to it. Meant for bounded item counts (the dashboard case), not
tens of thousands of rows.

`Tabs` vs `Paginator` vs `Table`:

| use | when |
|---|---|
| `Tabs` | a small, fixed, **named** set of pages (SVR / PLC / RTU ...) |
| `Paginator` | many **data items**, laid out per page, paged through |
| `Table` | one long list of rows, **scrolled** vertically (see below) |

## Table

Columns with a header and a scrolling body — one long list of rows.

```lua
local t = mimic.Table{parent=panel, x=2, y=2, width=50, height=12, columns={
    { name="ID",       width=4 },
    { name="STATE",    width=12 },
    { name="ENERGY",   width=8, align=mimic.ALIGN.RIGHT },
}}

local r = t.add_row{ "01", "ONLINE", "84%" }   -- returns the row index
t.set_cell(r, 3, "86%")                         -- update one cell
t.set_row(r, { "01", "OFFLINE", "0%" })         -- or a whole row
t.clear()                                        -- remove every row
```

`add_row` past `max_rows` (default 500) errors clearly rather than crashing. A table that
`clear()`s and refills every tick — the common "refresh the list" pattern — is safe.
