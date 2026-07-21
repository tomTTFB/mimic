# Behavior & gotchas

The non-obvious things. Most come from the vendored cc-mek-scada engine and can't be changed
without diverging from upstream — so they are written down here instead. Read this once and
save yourself an in-game debugging session.

## Peripheral I/O freezes the UI if you do it wrong

The big one, on its own page: **[Performance](performance.md)**. Poll peripherals in a
`parallel` coroutine, not inside the event loop, and `pcall` every peripheral call.

## Values and getters

- **`NumberField:get_value()` returns a string**, not a number — it hands back the typed text.
  Convert it: `tonumber(field.get_value())`.
- **A `Checkbox`'s state is `get_value()`** (a boolean), not `get_state()`. It updates on every
  click, so read it directly; you don't need to track it through the callback.
- Getters exist on value-bearing elements as `get_value()`. If you're reaching for a
  differently-named getter and it isn't there, try `get_value()` first.

## There is no z-buffer

Elements draw to the shared screen in **creation order**. There is no depth sorting.

- **Build overlays last.** A `Dialog` (or any pop-up) must be created *after* the things it
  covers, or it will be drawn under them.
- **Nothing beneath an overlay may redraw while it's open.** A periodic refresh that updates
  elements behind a `Dialog` will paint straight through it — breaking both its look and its
  clickability. Gate your refresh:

  ```lua
  if not dialog.is_open() then refresh() end
  ```

- **`PushButton{active_fg_bg=...}` repaints itself ~0.25 s after a press** (the "unpress"
  animation). If that button opened an overlay, the delayed repaint can bleed through it —
  another reason to gate redraws while a dialog is up.

## One screen, one display

`mimic.init()` binds the computer's terminal; `mimic.add_display{monitor="right"}` binds a
monitor. Binding the **same** screen twice **errors** — it used to silently create a second
display that fought over the output and never received touches. If you see
`"... already has a display"`, you called `init`/`add_display` twice for the same screen.

`monitor_resize` fires routinely in Minecraft (chunk load, peripheral attach) usually with no
real size change; mimic ignores the no-ops, so it is never fatal. Pass `on_resize` if your UI
genuinely needs to rebuild for a new size.

## Layout traps

- **`Rectangle{thin=true}` means a thin *border*, not a thin box.** It requires `border=` and
  errors without it. For a plain filled box, pass neither.
- **A bordered `Panel`/`Rectangle` interior is smaller than its frame.** `Panel` hands you a
  content area whose `get_width()`/`get_height()` are already the usable size — build against
  those, not the panel's outer dimensions.
- **Overflowing children are clipped, not errored** — unless the child *starts* past the
  parent's edge, which does error. Budget your vertical space; a title costs 1 row and a border
  costs 2.
- **Out of vertical space** shows up as `frame height not >= 1`. It means an element didn't fit
  below what came before it.

## Failure philosophy

mimic tries to **fail loud on bugs and stay quiet on bad data**:

- A programming mistake — binding a container, a wrong argument type, an impossible size —
  errors at build with a `mimic: ...` message that says what to fix.
- Bad *runtime data* — a NaN sensor reading, a `monitor_resize` no-op — is absorbed, because a
  glitchy feed must not crash a running control room.

If you get a `mimic:` error, it is telling you something you can fix. If something silently does
nothing, check this page and [Data binding](data-binding.md#what-can-be-bound) first.
