# Performance

**Read this before wiring mimic to real peripherals.** It is the single thing that separates a
smooth control panel from one that feels frozen.

## The one rule

`mimic.run()` is a **single cooperative event loop**. Clicks, blinking, timers, and redraws all
happen on one thread. Any slow work you do inside a callback or a `tcd` timer blocks that thread
until it finishes — and while it is blocked, the UI does not respond to input.

The slowest thing you can do is a **peripheral call**. In CC:Tweaked, calling a method on a
peripheral (`chest.list()`, `sensor.getEnergy()`, `inventory.pushItems()`) *yields* until the
game answers, and inventory methods are rate-limited across ticks. Do 24 of them every 2 seconds
inside the loop and the interface freezes for the whole scan, every scan. On a busy server the
scan can take longer than the refresh interval, so the UI is frozen most of the time.

This is not a mimic bug — it is how CC's single-threaded computers work. The fix is to keep the
I/O off the UI thread.

## The fix: poll in a parallel coroutine

Run `mimic.run` and your polling loop as two cooperative coroutines with `parallel`. Because
each peripheral call yields, `mimic.run` interleaves and stays responsive the whole time. The
poll loop only ever **publishes** to a psil — it never touches elements directly.

```lua
local ps   = psil.create()
local root = mimic.init{ps=ps}

-- ... build the UI, everything bound to ps keys ...

parallel.waitForAny(
    mimic.run,                       -- owns input, the clock, blinking
    function ()                      -- the slow I/O, off the event loop
        while true do
            for i = 1, #chambers do
                local ok, data = pcall(read_chamber, chambers[i])   -- always pcall!
                if ok then
                    ps.publish("chamber" .. i .. "_state", data.state)
                    ps.publish("chamber" .. i .. "_energy", data.energy)
                end
            end
            os.sleep(REFRESH_SECONDS)
        end
    end)
```

`parallel.waitForAny` returns when `mimic.run` returns (Ctrl+T), which also stops the poll loop.

This is validated behaviour: with the poll loop running slow I/O, button clicks still register
throughout — the UI never freezes.

## Always `pcall` peripheral calls

A monitor that gets unplugged, a chamber that unloads, a full inventory — any of these can make
a peripheral call throw. Wrapped in `pcall`, one bad peripheral is skipped and the panel keeps
running:

```lua
local ok, list = pcall(inventory.list)
if ok and list then ... end
```

Without it, one detached peripheral takes the whole coordinator down.

## Keep the poll cheap

- **Cache what doesn't change.** Energy *capacity* is constant; read it once and store it. Only
  poll the values that move.
- **One scan, many facts.** If you need two things from one inventory, scan its `list()` once
  and pull both out, rather than listing it twice.
- **Poll only as often as you need.** A 2-second refresh on 24 chambers is a lot of I/O; 5
  seconds is often plenty and a quarter of the load.
- **Update selection immediately, data on the next poll.** A "< / >" selector should update its
  label in the button callback, not wait for the poll — otherwise it feels laggy.

## What is *not* slow

mimic's rendering. A full 24-row × 4-column table refresh costs about **7 ms** — it happens
hundreds of times per second. If a panel feels slow, it is the peripheral I/O, not the drawing.
Measure before blaming the UI.
