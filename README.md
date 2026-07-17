# mimic

A ComputerCraft GUI library for **monitoring dashboards** — indicator lights, state tags,
bar gauges and data readouts that look like an industrial control panel out of the box.

Built on the graphics engine from [cc-mek-scada](https://github.com/MikaylaFischler/cc-mek-scada)
by Mikayla Fischler, used under the MIT license. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

> **Status: pre-alpha (v0.1.0).** The vendored engine is battle-tested. The `mimic/` layer on
> top is new, but it runs: `test/run.sh` runs a smoke test inside CraftOS-PC and
> passes, and every example runs on real in-game hardware. The API may still change.

## Why not [Basalt](https://basalt.madefor.cc/)?

Basalt is a general-purpose UI framework for CC:Tweaked — windows, buttons, text fields, any
kind of app. Use it for general UI; it's good.

mimic does one narrower job: **dashboards that monitor things.** It ships the control-room look
by default, and its vocabulary is indicator lights, alarm strips, state tags, bar gauges and
trends rather than windows and menus. Different job.

## Hello world

```lua
require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local root = mimic.init()   -- theme + palette applied, screen cleared

local power = m.LED{parent=root,x=2,y=2,label="POWER",colors=mimic.style.ind_grn}
power.update(true)

mimic.run()                 -- blocks until Ctrl+T, restores the palette on exit
```

### Live data

Point elements at a [psil](#data-binding) with `bind=`, and they update themselves:

```lua
local psil = require("scada-common.psil")
local ps = psil.create()

local root = mimic.init{ps=ps}   -- ps is inherited by everything below

mimic.LEDList{parent=root,x=2,y=2,leds={
    { label="STATUS",    bind="status" },
    { label="HEARTBEAT", bind="heartbeat" },
    {},                                       -- blank entry = gap
    { label="FAULT", bind="fault", color=mimic.style.ind_red, flash=true },
}}

ps.publish("status", true)       -- the LED updates itself
```

No locals, no wiring, nothing to keep in sync.

### Examples

```
hello              -- panel, button, blinking alarm, live readout
front_panel        -- a device front panel, written with bare elements
front_panel2       -- the same panel using bind= and LEDList
panel_tabs         -- a tabbed front panel; fits a bare 51x19 computer screen
dashboard          -- full dashboard: panels, gauges, trends, bar chart, alarms
facility           -- front panel on the computer + dashboard on a monitor, one program
themes             -- switch built-in + custom themes, and persist the choice
```

`dashboard` and `facility` need a monitor at least 100 wide (an 8×4 advanced monitor at 0.5
text scale). `panel_tabs`, `front_panel`, and `hello` fit a bare computer screen.

`front_panel.lua` and `front_panel2.lua` are the same screen written both ways, kept side by
side on purpose: **168 lines and 18 `register()` calls become 97 lines and zero.**

## API

### `mimic.init(opts)` → `root`

Sets up a display and returns the root element to parent your UI to. Applies the theme palette
and clears the screen, so the result already looks right with no styling of your own.

| option | default | meaning |
|---|---|---|
| `monitor` | *(terminal)* | monitor peripheral name, e.g. `"monitor_0"` |
| `theme` | `"deepslate"` | theme name, a custom theme table, or a `mimic.THEME.*` enum — see [Theming](#theming) |
| `color_mode` | `mimic.COLOR_MODE.STANDARD` | assistive color modes — see below |
| `prefs` | `false` | load the saved theme/color_mode if present (an explicit `theme=` still wins) |
| `scale` | `0.5` | monitor text scale (ignored for the terminal) |
| `ps` | *(none)* | default psil data source, inherited by every element below |
| `on_resize` | *(none)* | `on_resize(root, w, h)` when this display's size really changes |

### `mimic.run(on_event?)`

Runs the event loop until terminated, dispatching mouse, monitor touch, keyboard, paste and
timer events into the element tree. Blocks. Restores the palette on exit. Pass an optional
`on_event(event, p1..p5)` hook to handle your own events (e.g. `modem_message`).

### `mimic.stop()`

Tears down: stops blinking, restores the palette, clears the screen. Called automatically
by `run()`.

### Data binding

`require("mimic.elements")` gives every element under one name, with two extra arguments:

| arg | meaning |
|---|---|
| `bind="key"` | subscribe to a psil key; the element updates itself when you `publish` |
| `transform=fn` | run the value through `fn` before updating |
| `ps=` | set the data source for this element **and everything under it** |

`ps` is inherited, so set it once — on `mimic.init{ps=...}` or on any container — and every
element below can just say `bind=`. Binding uses `register()` under the hood, so elements
unsubscribe automatically when deleted.

Binding is entirely optional. `elem.update(value)` still works, and for a handful of elements
it's the simpler choice.

### `mimic.LEDList{...}`

A column of labelled lights from a table. Rows take `label`, `bind`, `transform`, `color`,
`flash`, `period`, `value`, `kind`. An empty entry `{}` inserts a gap. Returns the container
and the rows, addressable by label.

### `mimic.Panel{...}`

A titled, bordered box — the signature dashboard look. Takes `title`, `accent`, `title_fg`,
`align`, plus the usual geometry. Returns the **content area**, so children parent straight
to it and its `get_width()`/`get_height()` report the room you can actually use (the border
and title are already subtracted).

### `mimic.Gauge{...}`

A labelled bar: label, fill, trailing percentage. Takes `label`, `label_width`, `color`
(the bar), `text_color` (the percentage), `max` (to pass real units instead of a 0–1
fraction), plus `bind`/`transform`.

### Charts

**`mimic.Trend{...}`** — one value over time. Each push shifts the plot left one column.

| arg | meaning |
|---|---|
| `style` | `"area"` (default, filled) or `"line"` |
| `min` / `max` | value range; `max` defaults to 1.0 |
| `bind` / `transform` | each publish pushes a sample |
| `color` / `bg` | plot and empty colors |
| `fill` | initial value for every column |

Also `push(v)`, `set_all(v)`, `get_samples()`. Vertical resolution is **3× the character
height** — CC's characters 128–159 are 2×3 subpixel blocks, so each cell holds three bands.

**`mimic.BarChart{...}`** — several values compared right now, as vertical bars with labels
underneath. Takes `bars` (each with `label`, `bind`, `transform`, `color`, `value`), plus
`max`, `gap`, `show_labels`. Returns the container and the bars, addressable by label.

Trend draws only the plot. Compose axis labels around it — see `examples/dashboard.lua`.

### Layout

**`mimic.Row{...}`** — cells left to right, so you stop hand-computing column x. Either
`count=N` (equal columns) or `widths={...}` (explicit; a `0` shares the leftover equally),
plus `gap`. Returns the cells as `Div`s and the container.

```lua
local cols = mimic.Row{parent=root,y=3,height=14,count=4,gap=1}
for i = 1, 4 do mimic.Panel{parent=cols[i],x=1,y=1,width=cols[i].get_width(),height=14,...} end
```

**`mimic.Grid{...}`** — a grid of equal cells. `cols`, `rows`, `gap_x`, `gap_y`. Returns cells
row-major, also callable as `cells(col, row)`.

### `mimic.Table{...}`

Columns with a header and a scrolling body. `columns` (each `name`, `width`, optional `align`).
Returns a table with `add_row{...}` → row index, `set_cell(row, col, text)`, `set_row`, `clear`,
`row_count`.

### `mimic.Dialog{...}`

A modal confirm/alert centered over the display. `message`, `title`, `accent`, `width`, and
`buttons` (each `text`, optional `color` and `callback`). Build it once; `show()` / `hide()` it.
Each button closes the dialog and then runs its callback.

```lua
local d = mimic.Dialog{parent=root,title="CONFIRM",accent=colors.red,message="Stop chamber 3?",
    buttons={ {text="STOP",color=mimic.style.ind_red,callback=stop}, {text="CANCEL"} }}
d.show()
```

### Colors

`mimic.style` carries the active theme and ready-made pairs — `ind_grn`, `ind_yel`, `ind_red`,
`ind_wht`, `root`, `text_colors`, `lu_colors`, `wh_gray`, and `theme.header`. Use
`mimic.cpair(fg, bg)` to build your own.

**Children inherit their parent's colors automatically** — set `fg_bg` on a container and
everything inside picks it up, so you rarely repeat it. `colors._INHERIT` inherits one channel
while setting the other.

### Gotchas

- `Rectangle{thin=true}` means a *thin border*, not a thin box — it requires `border=` and
  errors without it. For a plain filled box, pass neither.
- Elements auto-stack vertically inside a `Div` when you omit `y`; `line_break()` adds a gap.
  Run off the bottom and you get `frame height not >= 1`, which means "out of vertical space".
- Minecraft fires `monitor_resize` routinely — on chunk load, on attach — usually with no
  real size change. mimic checks the size and ignores the no-ops, so it is never fatal.
  Pass `on_resize` if your UI needs to rebuild for a genuinely new size.

### Theming

mimic ships two themes — `deepslate` (dark, the default) and `smooth_stone` (light) — and you
can register your own. Pick one at init by name:

```lua
mimic.init{theme = "smooth_stone"}
```

A **custom theme** is a partial table: name only what you change, and everything else —
including the color palette — is inherited from a base (deepslate, or smooth_stone if you set
`dark = false`).

```lua
mimic.register_theme("midnight", {
    dark = true,
    text = colors.cyan,
    colors = {                          -- palette hexes; omit to keep the base palette
        { c = colors.cyan,  hex = 0x00e5ff },
        { c = colors.green, hex = 0x39ff14 },
    },
})

mimic.init{theme = "midnight"}
```

**Persistence:** `mimic.save_prefs(name, color_mode)` writes the choice, and
`mimic.init{prefs = true}` loads it (an explicit `theme=` still wins). So a user can pick a
theme once and have it stick across restarts.

**Theme is chosen at init, not switched live.** An element bakes its colors when it is built,
so changing theme means rebuilding the screen — re-run the program (see `examples/themes.lua`).
This is the same model cc-mek-scada uses. A *configurator* (an interactive settings screen) is
something you build with mimic, not a built-in — see the note in the roadmap.

### Accessibility

`color_mode` remaps the palette for colorblind users, and is inherited from the upstream
engine at no cost:

`STANDARD` · `DEUTERANOPIA` · `PROTANOPIA` · `TRITANOPIA` · `BLUE_IND` (blue means "good"
instead of green) · `STD_ON_BLACK` · `BLUE_ON_BLACK`

## Elements

37 elements ship with mimic, vendored from cc-mek-scada.

**Dashboard:** `IndicatorLight` · `TriIndicatorLight` · `AlarmLight` · `LED` · `LEDPair` ·
`RGBLED` · `StateIndicator` · `DataIndicator` · `PowerIndicator` · `HorizontalBar` ·
`VerticalBar` · `SignalBar` · `IconIndicator`

**Controls:** `PushButton` · `SwitchButton` · `MultiButton` · `HazardButton` · `Checkbox` ·
`RadioButton` · `Radio2D` · `NumericSpinbox` · `TabBar` · `Sidebar` · `App`

**Forms:** `TextField` · `NumberField`

**Containers:** `DisplayBox` · `Div` · `Rectangle` · `TextBox` · `ListBox` · `MultiPane` ·
`AppMultiPane`

**Other:** `PipeNetwork` · `ColorMap` · `Tiling` · `Waiting`

All of them are available from `require("mimic.elements")`, which resolves them lazily — a
program only loads what it touches. The underlying `graphics.elements.*` paths still work if
you want the unwrapped constructors.

### A note on the `basalt` theme

`graphics/themes.lua` includes a front-panel theme named `basalt`. That name comes from the
upstream project (it refers to the Minecraft block) and is **unrelated** to the Basalt UI
framework.

## Testing

mimic has an automated test loop that runs the real library inside a real ComputerCraft
environment — no mocks. Install [CraftOS-PC](https://www.craftos-pc.cc/), then:

```
./test/run.sh
```

It stages the library into a throwaway computer, runs `test/smoke.lua` under
`CraftOS-PC --headless`, and prints results. Exits non-zero on failure, so it drops
straight into CI.

The test asserts against live state rather than trusting the code: it reads the terminal
palette back with `term.getPaletteColor` to prove theming applied, drives a synthetic
`mouse_click` through the element tree to prove the button callback fires, and publishes
through a `psil` to prove data binding propagates.

## Roadmap

Priorities come from actually building screens, not from guessing.

- **Done:** `bind=` / `ps=` inheritance, the `mimic.elements` front door, `LEDList`, `Panel`,
  `Tabs`, `Gauge`, `Trend` (area + line), `BarChart`, `Row`, `Grid`, `Table`, `Dialog`,
  multi-display support
- **A configurator** (interactive settings screen) is intentionally *not* a core feature —
  it is app-specific and built with mimic's own elements (TextField, RadioButton, Tabs,
  buttons) plus `save_prefs`/`load_prefs`. cc-mek-scada's `configure.lua` is exactly this:
  a consumer of the toolkit, not part of it.
- **Maybe:** `StatList`, `AlarmStrip`, a `Chart` wrapper composing axes + labels around a Trend,
  `Slider`, `Dropdown`, `Toast` — build them when a real screen needs them, not before

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

mimic's own code is MIT. Vendored cc-mek-scada code is MIT, Copyright 2022–2026 Mikayla
Fischler — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
