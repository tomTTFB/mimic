# mimic — notes for Claude

Read this before touching the repo. It captures decisions and traps that are
expensive to rediscover.

## What this is

A ComputerCraft (CC:Tweaked) GUI library for monitoring dashboards. It runs on
in-game computers and monitors. It is **built on the graphics engine from
[cc-mek-scada](https://github.com/MikaylaFischler/cc-mek-scada)** (MIT, Mikayla
Fischler), which was already a good domain-neutral toolkit — the value mimic adds
is packaging, zero-config theming, an ease layer, and charts the engine lacks.

## The one rule: vendored vs. ours

```
graphics/        VENDORED, DO NOT EDIT   the cc-mek-scada engine, unmodified
scada-common/    VENDORED, DO NOT EDIT   util, tcd, log, psil (its deps)
mimic/           OURS                    the library
examples/        OURS
test/            OURS
```

`graphics/` and `scada-common/` are copied verbatim at their original paths so
upstream fixes stay a `git merge`, not a manual re-port of ~6,800 lines we did not
write. **Never edit them.** If the engine does something awkward, wrap it in
`mimic/`, do not patch it. The only changes ever made to vendored code are recorded
in `THIRD_PARTY_NOTICES.md` (two reactor-domain files deleted, one turbine function
removed) — do not add to that list without a very good reason.

## Architecture

- `mimic/init.lua` — `init` / `add_display` / `run` / `stop`, palette handling, the
  multi-display event loop. `mimic.X` re-exports every helper.
- `mimic/style.lua` — themes and derived color pairs. `mimic.init` applies the
  palette for you; that is the whole "looks right with zero config" trick.
- `mimic/elements.lua` — the front door. Wraps every vendored element so it takes
  `bind=` / `transform=` / `ps=`, and resolves them lazily by name. `require("mimic.elements")`.
- Helpers, each its own file: `LEDList`, `Panel`, `Tabs`, `Gauge`, `Trend`,
  `BarChart`, `Row`, `Grid`, `Table`, `Dialog`.

### Data binding

Elements bind to a `psil` (pub/sub) key with `bind="key"`. The `ps` is inherited:
set it once on `mimic.init{ps=...}` or any container, and everything under it can
just say `bind=`. `ps.publish("key", v)` updates every bound element. This replaced
~511 hand-written `register()` calls in the upstream app.

## How to test — do this after any change

```
./test/run.sh
```

It runs `test/smoke.lua` (52 checks) inside **CraftOS-PC headless** against the real
library — no mocks. Needs CraftOS-PC installed (https://www.craftos-pc.cc/). It exits
non-zero on failure. Add a check for anything you build.

**Add a `check(...)` for every new element**, asserting behaviour (bind propagates,
errors are clear), not just "it constructed". Build new elements into the offscreen
`sandbox` display in the test, which is 164x46 — the terminal is only 51x19.

### The test loop has a blind spot

CraftOS-PC does not perfectly emulate hardware. Its emulated monitor **never fires
`monitor_resize`**, which hid a crash that only appeared in real Minecraft (mimic used
to treat that event as fatal). Lesson: green tests are necessary, not sufficient.
Anything peripheral- or timing-related must be checked in-game too.

## Gotchas paid for in real bugs

- **`get_height()` / `get_width()` on a bordered `Rectangle` report the OUTER frame**,
  not the usable interior — children get a smaller content window. `Panel` returns a
  content `Div` specifically so callers get true dimensions. Do the same in any new
  container.
- **`Rectangle{thin=true}` means a thin *border*, not a thin box.** It requires
  `border=` and asserts without it. For a plain filled box, pass neither.
- **`HorizontalBar` colors are easy to invert.** `bar_fg_bg` is the bar; `fg_bg` is
  the element (and the trailing percent). Getting it backwards gives a gray bar with a
  colored number. `Gauge` gets this right — copy it.
- **Children inherit `fg_bg` from their parent.** Do not repeat it on every child.
- **Overflowing children are silently clipped** (`math.min`), not errored, unless the
  child *starts* past the parent edge. Budget vertical space carefully.
- **`monitor_resize` is routine in Minecraft** (chunk load, attach) and usually not a
  real size change. Never treat it as fatal. mimic checks the size and ignores no-ops.

## Conventions

- Errors that a user caused should be `error("mimic: <what and how to fix>", 0)` —
  the `0` drops the traceback so the message reads clean in the CC shell. Name the
  element and say what to do. See any helper for the style.
- Helpers that lay out (Panel, Row, Grid, Tabs) **return the container(s) to build
  into**, not the raw element.
- Keep the simple path simple: `elem.update(v)` must always work; `bind=` is opt-in.

## Publishing

Public repo. In-game install is `wget run <raw-url>/install.lua`, which needs the repo
**public** (raw.githubusercontent 404s on private) and pulls the manifest in
`install.lua`. **If you add or remove a `.lua` file that ships, update the `FILES`
list in `install.lua`** or the installer will miss it / 404. There is no generator;
the list is hand-maintained and checked against disk.
