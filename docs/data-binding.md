# Data binding

Binding is how a live value reaches the screen without wiring. You point an element at a key,
publish to that key, and the element redraws itself.

## The basics

```lua
local psil = require("scada-common.psil")
local ps   = psil.create()

local root = mimic.init{ps=ps}   -- give the whole tree a data source

m.LED{parent=root, x=2, y=2, label="STATUS", colors=mimic.style.ind_grn, bind="status"}

ps.publish("status", true)       -- the LED turns on
ps.publish("status", false)      -- and off
```

`bind="status"` subscribes the element to the `status` key. Every `ps.publish("status", v)`
pushes `v` into every element bound to it. No locals, nothing to keep in sync.

## `ps` is inherited

You set the data source once and everything below inherits it. Pass `ps=` to `mimic.init` (or
to any container), and children just say `bind=`:

```lua
local root = mimic.init{ps=ps}
local box  = mimic.Panel{parent=root, x=1, y=1, width=30, height=8, title="UNIT"}

-- no ps= needed here; inherited from root through the panel:
m.LED{parent=box, x=2, y=1, label="ONLINE", bind="online", colors=mimic.style.ind_grn}
```

If you need a different data source for one subtree, pass `ps=` on that container and it
overrides for everything under it.

## `transform=`: massage the value first

Data rarely arrives in display form. `transform=` runs the published value through a function
before the element sees it:

```lua
-- publish raw kelvin, show celsius:
m.DataIndicator{parent=root, label="Temp:", unit="C", format="%6.1f", value=0, width=22,
                fg_bg=mimic.style.text_colors, lu_colors=mimic.style.lu_colors,
                bind="temp_k", transform=function (k) return k - 273.15 end}

-- publish an entity name, show a label:
m.TextBox{parent=root, x=2, y=4, width=24, text="Target: ---", bind="target",
          transform=function (name) return "Target: " .. (name or "---") end}
```

## What can be bound

Any element that **displays a value**: `LED`, `IndicatorLight`, `StateIndicator`,
`DataIndicator`, `PowerIndicator`, the bars, `TextBox`, `Trend`, and the helpers built on them
(`LEDList`, `Gauge`, `BarChart`, ...).

**Containers cannot be bound** — a `Div`, `Rectangle`, `Panel`, etc. hold no value. Trying to
`bind=` one is an error at build time (rather than silently doing nothing).

## Binding is optional

Every element also has a direct setter. If you have a handful of elements and no data bus,
just call it:

```lua
local led = m.LED{parent=root, x=2, y=2, label="X", colors=mimic.style.ind_grn}
led.update(true)          -- direct, no psil
```

Binding shines when you have many elements and a polling loop; direct calls are simpler for a
few. Mix them freely.

## How it cleans up

`bind=` registers through the element, so when an element is deleted it automatically
unsubscribes — no dangling callbacks. This is what makes rebuilding parts of a UI (e.g. a
`Table` that clears and refills) safe.

## Where the values come from

Your job is to `ps.publish(...)`. **In a real facility that means reading peripherals, and that
must not happen on the UI thread** — see [Performance](performance.md) for the pattern. The
short version:

```lua
parallel.waitForAny(
    mimic.run,                       -- the UI
    function ()                      -- the data, off the UI thread
        while true do
            local ok, temp = pcall(sensor.getTemp)
            if ok then ps.publish("temp", temp) end
            os.sleep(2)
        end
    end)
```
