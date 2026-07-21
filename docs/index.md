# mimic documentation

A ComputerCraft (CC:Tweaked) GUI library for monitoring dashboards — indicator lights, state
tags, bar gauges, charts and data readouts that look like an industrial control panel out of
the box. Built on the graphics engine from
[cc-mek-scada](https://github.com/MikaylaFischler/cc-mek-scada).

## Start here

- **[Getting started](getting-started.md)** — install, requirements, your first screen.
- **[Concepts](concepts.md)** — the element tree, displays, and the single event loop. Read
  this once; it explains how everything fits together.

## Guides

- **[Data binding](data-binding.md)** — `bind=`, `ps=` inheritance, and `transform=`. The
  thing that makes live UIs easy.
- **[Layout](layout.md)** — `Panel`, `Row`, `Grid`, `Tabs`, `Paginator`.
- **[Charts](charts.md)** — `Gauge`, `Trend` (area + line), `BarChart`.
- **[Theming](theming.md)** — built-in themes, custom themes, persistence, colorblind modes.
- **[Performance](performance.md)** — **read before a real facility.** How to keep the UI
  responsive while polling peripherals.

## Reference

- **[Behavior & gotchas](behavior.md)** — the non-obvious things that will otherwise cost you
  an in-game debugging session.
- **[Element reference](REFERENCE.md)** — every element and helper, with its full argument
  list. Generated from the source, so it never drifts.

## In one screen

```lua
require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local psil  = require("scada-common.psil")
local ps    = psil.create()

local root = mimic.init{ps=ps}          -- theme + palette applied, screen cleared

mimic.LEDList{parent=root, x=2, y=2, leds={
    { label="STATUS",    bind="status" },
    { label="HEARTBEAT", bind="heartbeat" },
}}

ps.publish("status", true)              -- the LED updates itself
mimic.run()                             -- blocks until Ctrl+T; restores the palette on exit
```

## Why mimic and not [Basalt](https://basalt.madefor.cc/)?

Basalt is a general-purpose UI framework — windows, buttons, any kind of app. mimic does one
narrower job: **dashboards that monitor things.** It ships the control-room look by default,
and its vocabulary is indicator lights, alarm strips, state tags, bar gauges and trends rather
than windows and menus. Different job.
