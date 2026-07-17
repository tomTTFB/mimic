# Changelog

All notable changes to mimic are recorded here. mimic follows [semantic
versioning](https://semver.org/) once it reaches 1.0; before then, minor versions may make
breaking changes.

## [Unreleased]

The library is feature-complete and hardware-tested. Working toward a tagged `v0.1.0`.

### Added
- **Core**: `mimic.init` / `run` / `stop`, zero-config theming (the palette is applied for
  you), and a multi-display event loop — a front panel on the computer and a dashboard on a
  monitor from one program.
- **Data binding**: `bind=` / `transform=` with an inherited `ps=` data source, replacing
  hand-written `register()` calls. `require("mimic.elements")` is the front door to every
  element, resolved lazily.
- **Helpers**: `LEDList`, `Panel`, `Tabs`, `Gauge`, `Row`, `Grid`, `Table`, `Dialog`.
- **Charts**: `Trend` (filled `area` and `line` styles, 3× subpixel vertical resolution) and
  `BarChart` — neither has an equivalent in the underlying engine.
- **Configurable themes**: two built-ins (`deepslate`, `smooth_stone`), `register_theme` /
  `make_theme` for custom themes (partial tables that inherit from a base), and
  `save_prefs` / `load_prefs` with `init{prefs=true}` to persist the choice.
- **Install**: `wget run <raw>/install.lua` pulls the whole library onto a computer.
- **Tests**: a smoke suite that runs the real library inside CraftOS-PC, asserting behaviour
  (bind propagates, errors are clear) rather than construction.

### Fixed
- `bind=` on a `TextBox` silently did nothing (it drove `update()`, which a TextBox leaves as
  a no-op). Binding now uses `set_value`, the canonical setter every value element defines.
- `bind=` on a container (Div, Rectangle, …) silently no-opped; now a clear build-time error.
- `Table` crashed cryptically past its internal scroll height; now `max_rows=` with a clear
  "table is full" message.
- `Trend` accepted `min >= max` (garbage scaling) and non-finite values. `min >= max` now
  errors; NaN/inf are skipped so a glitchy feed cannot crash a live dashboard.
- `monitor_resize` was treated as fatal, crashing the UI on chunk load in real Minecraft. It
  is now ignored unless the size genuinely changed (optional `on_resize` hook).
- `LEDList{leds={}}` gave a cryptic geometry error; now a clear one.

### Notes
- Theme is chosen at `init`, not switched live — elements bake their colors when built, so
  changing theme means rebuilding the screen. This matches cc-mek-scada's model.
- A *configurator* (interactive settings screen) is deliberately not a core feature; it is
  application code built with mimic's elements plus `save_prefs`/`load_prefs`.
