# Getting started

## Requirements

- **An Advanced Computer.** mimic's entire look is color; a basic (monochrome) computer will
  render it as unreadable grey. Advanced computers have the gold casing.
- **CC:Tweaked** with the HTTP API enabled (on by default) if you install over the network.
- For the dashboard layouts: an **Advanced Monitor at least 8 blocks wide × 4 tall** (that is
  164×52 characters at the default 0.5 text scale). Smaller screens run the front-panel
  examples fine.

## Install

On an Advanced Computer:

```
wget run https://raw.githubusercontent.com/TomTTFB/mimic/main/install.lua
```

That pulls the whole library and prints what to run. To host it yourself, pass a base URL:

```
wget run http://your-host/install.lua http://your-host
```

(CC blocks private/loopback addresses by default; allow them in `computercraft-server.toml`
if you serve from your own machine.)

## Hello world

```lua
require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local root = mimic.init()   -- theme + palette applied, screen cleared

local power = m.LED{parent=root, x=2, y=2, label="POWER", colors=mimic.style.ind_grn}
power.update(true)

mimic.run()                 -- blocks until Ctrl+T, restores the palette on exit
```

Three things are happening:

1. `require("/initenv").init_env()` — bootstraps CC's module system so `require("mimic")`
   resolves. **Always the first line.** The leading slash matters (it resolves the file
   relative to the disk root, not your program's folder).
2. `mimic.init()` sets up the display, applies the theme palette, clears the screen, and
   returns the **root element** you build everything under.
3. `mimic.run()` runs the event loop — clicks, blinking, timers — until you press Ctrl+T,
   then restores the terminal palette.

## Live data in five lines

Most dashboards show changing values. Point elements at a [psil](data-binding.md) key with
`bind=`, and they update themselves when you publish:

```lua
require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")
local psil  = require("scada-common.psil")

local ps    = psil.create()
local root  = mimic.init{ps=ps}     -- ps is inherited by everything below

m.DataIndicator{parent=root, x=2, y=2, label="Temp:", unit="C", format="%6.1f",
                value=0, width=22, fg_bg=mimic.style.text_colors,
                lu_colors=mimic.style.lu_colors, bind="temp"}

ps.publish("temp", 64.5)            -- the readout updates itself

mimic.run()
```

No locals to keep, no wiring — publish to a key and every element bound to it redraws. See
**[Data binding](data-binding.md)** for the full picture.

## The examples

The install ships runnable examples. Type their names on the computer:

| example | what it shows |
|---|---|
| `hello` | a panel, a button, a blinking alarm, a live readout |
| `panel_tabs` | a tabbed front panel; fits a bare 51×19 computer screen |
| `front_panel` / `front_panel2` | the same panel built with bare elements vs. `bind=` + `LEDList` |
| `themes` | switching built-in and custom themes, and persisting the choice |
| `paginated` | paging through more nodes than fit on one screen, with live data |
| `dashboard` | a full dashboard: panels, gauges, trends, a bar chart, alarms (needs a monitor) |
| `facility` | a front panel on the computer **and** a dashboard on a monitor, from one program |

`front_panel.lua` and `front_panel2.lua` are the same screen written both ways on purpose —
168 lines with 18 `register()` calls become 97 lines with zero.

## Next

- **[Concepts](concepts.md)** — how the element tree, displays, and event loop fit together.
- **[Performance](performance.md)** — before you wire it to real peripherals, read this. It is
  the one thing that separates a smooth panel from a frozen one.
