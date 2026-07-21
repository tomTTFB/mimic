# Charts

mimic ships three data visualizations. `Gauge` shows one value now; `Trend` shows one value
over time; `BarChart` compares several values now. Full argument lists:
[element reference](REFERENCE.md).

## Gauge

A labelled bar with a trailing percentage — the workhorse readout.

```lua
mimic.Gauge{parent=box, x=2, y=3, width=24, label="CPU ", bind="cpu",
            color=mimic.cpair(colors.green, mimic.style.ind_bkg)}
```

- Values are fractions, `0.0` to `1.0`. Pass `max=` to give **real units** instead and have
  them scaled: `max=200` means a published `100` shows as 50%.
- `color` is the bar; `text_color` is the trailing percentage (inherited if omitted).
- `label_width` fixes the label column if you want several gauges to line up.

## Trend

A value plotted over time. Every push shifts the plot left one column. **cc-mek-scada has no
equivalent** — this is one of mimic's additions.

```lua
mimic.Trend{parent=panel, x=2, y=3, width=100, height=8, max=4000,
            color=colors.green, bind="throughput"}          -- filled "area" (default)

mimic.Trend{parent=panel, x=2, y=3, width=64, height=5, min=20, max=90,
            style="line", color=colors.orange, bind="temp"} -- a line, not a fill
```

| arg | meaning |
|---|---|
| `style` | `"area"` (filled, default) or `"line"` |
| `min` / `max` | value range; `max` defaults to `1.0` |
| `bind` / `transform` | each publish pushes a sample |
| `color` / `bg` | plot and empty colors |
| `fill` | initial value for every column |

Also usable directly: `push(v)`, `set_all(v)`, `get_samples()`.

**Resolution is 3× the character height.** CC's characters 128–159 are 2×3 subpixel blocks, so
each cell holds three vertical bands — an 8-row trend has 24 levels.

**Robustness:** a wrong *type* (a string) is a bug and errors loudly. A non-finite *value*
(NaN/inf) from a glitchy sensor is **skipped**, not thrown — one bad reading will not crash a
live dashboard.

Trend draws **only the plot**. Compose axis labels around it:

```lua
local RPS_MAX = 4000
m.TextBox{parent=panel, x=1, y=3, width=5, text=tostring(RPS_MAX), alignment=mimic.ALIGN.RIGHT}
m.TextBox{parent=panel, x=1, y=6, width=5, text=tostring(RPS_MAX/2), alignment=mimic.ALIGN.RIGHT}
m.TextBox{parent=panel, x=1, y=10, width=5, text="0", alignment=mimic.ALIGN.RIGHT}
mimic.Trend{parent=panel, x=7, y=3, width=95, height=8, max=RPS_MAX, bind="rps"}
```

## BarChart

Several values compared right now, as vertical bars with labels underneath. Built from
`VerticalBar`, so it shares the subpixel resolution.

```lua
mimic.BarChart{parent=sum, x=2, y=2, width=34, height=6, max=1.0, gap=2, bars={
    { label="N1", bind="n1_cpu", color=colors.green },
    { label="N2", bind="n2_cpu", color=colors.green },
    { label="N3", bind="n3_cpu", color=colors.green },
    { label="N4", bind="n4_cpu", color=colors.orange },
}}
```

- Each bar takes `label`, `bind`, `transform`, `color`, `value` (initial).
- `max` scales the values; `gap` spaces the bars; `show_labels` (default true) draws the row
  of labels underneath.
- Returns the container and the bars, addressable by label.

Use `BarChart` to compare items *right now* (CPU per node); use `Trend` to watch one value
*over time*.
