# Concepts

The mental model, once, so the rest of the docs make sense.

## The element tree

A mimic UI is a tree of **elements**. Every element has a `parent`; the root comes from
`mimic.init()`. Containers (`Div`, `Rectangle`, `Panel`, ...) hold other elements; leaf
elements (`LED`, `DataIndicator`, a bar, ...) draw a value.

```lua
local root  = mimic.init()
local box   = mimic.Panel{parent=root, x=1, y=1, width=30, height=10, title="UNIT 1"}
local light = m.LED{parent=box, x=2, y=1, label="ONLINE", colors=mimic.style.ind_grn}
```

You place elements with `x` / `y` (1-based, relative to the parent's content area) and size
them with `width` / `height`. Omit `y` inside a `Div` and elements **auto-stack** vertically;
`div.line_break()` inserts a gap.

Colors are **inherited**: set `fg_bg` on a container and everything inside picks it up, so you
rarely repeat it.

## Two ways to get an element

```lua
local m = require("mimic.elements")
m.LED{parent=root, label="X", colors=...}          -- the front door (recommended)

local LED = require("graphics.elements.indicators.LED")
LED{parent=root, label="X", colors=...}            -- the raw constructor
```

`require("mimic.elements")` is the **front door**: it wraps every element so it accepts
`bind=` / `transform=` / `ps=` (see [Data binding](data-binding.md)), and resolves elements
lazily by name so your program only loads what it touches. Prefer it. The raw
`graphics.elements.*` paths still work if you want the unwrapped constructor.

## Helpers vs. elements

- **Elements** are the primitives — 36 of them, vendored from cc-mek-scada (LED, DataIndicator,
  bars, buttons, TextBox, ...). Full list and arguments: [element reference](REFERENCE.md).
- **Helpers** are mimic's higher-level pieces built from those primitives: `Panel`, `LEDList`,
  `Gauge`, `Trend`, `BarChart`, `Row`, `Grid`, `Table`, `Tabs`, `Paginator`, `Dialog`. They are
  what you reach for first. Each is covered in [Layout](layout.md) and [Charts](charts.md).

Layout helpers (`Panel`, `Row`, `Grid`, `Tabs`, `Paginator`) **return the container(s) to build
into**, not the element itself:

```lua
local content = mimic.Panel{parent=root, x=1, y=1, width=30, height=10, title="UNIT"}
-- `content` is the inside of the panel, already sized past the border + title:
m.LED{parent=content, x=1, y=1, label="ONLINE", colors=mimic.style.ind_grn}
```

## Displays

A **display** is one screen mimic draws to. `mimic.init()` creates the first one (the
computer's own terminal, or a monitor). You can drive more than one from a single program —
a front panel on the computer *and* a dashboard on a monitor:

```lua
local panel = mimic.init()                        -- the computer's screen
local board = mimic.add_display{monitor="right"}  -- a monitor array
mimic.run()                                       -- one loop drives both
```

Each screen is bound **once**. Binding the same monitor (or the terminal) twice errors rather
than silently creating a broken second display. Touches on a monitor route to that monitor's
display; keyboard and terminal clicks route to the computer's display. See
[Theming](theming.md) for `init` options and [the reference below](#the-run-loop) for details.

## The run loop

`mimic.run()` is **one cooperative event loop.** It pulls events and dispatches them:

- mouse clicks and monitor touches → the element under the cursor
- keyboard → the focused element on the computer's display
- timers → blinking (`AlarmLight`, flashing `IndicatorLight`) and anything you scheduled

It **blocks** until the program is terminated (Ctrl+T), then restores the palette. Everything
your UI does happens on this one thread.

> **This is the most important thing to understand.** Because it is a single thread, any slow
> work you do inside a callback or timer — above all **peripheral calls**, which pause until
> the game answers — freezes the entire UI while it runs. A dashboard that reads 24 inventories
> every 2 seconds inside the loop will feel broken. The fix is to poll in a **parallel
> coroutine**. This is important enough to have its own page: **[Performance](performance.md).**

## psil: the data bus

`psil` is a tiny publish/subscribe bus (from cc-mek-scada). You `create()` one, elements
`subscribe` to keys (via `bind=`), and you `publish` values:

```lua
local ps = psil.create()
-- elements bind to keys...
ps.publish("temp", 64.5)   -- ...and update when you publish
```

It is the seam between your data (peripherals, calculations) and your UI. Your polling code
only ever calls `ps.publish`; it never touches elements directly. Full details:
[Data binding](data-binding.md).
