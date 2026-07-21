# Theming

mimic applies a theme's palette for you at `init` — that is the whole "looks right with zero
config" trick. You can pick a built-in, register your own, and persist the choice.

## Pick a built-in

Two ship: `deepslate` (dark, the default) and `smooth_stone` (light).

```lua
mimic.init{theme = "smooth_stone"}
```

## Custom themes

A theme is a **partial table**: name only what you change, and everything else — including the
color palette — is inherited from a base (`deepslate`, or `smooth_stone` if you set
`dark=false`).

```lua
mimic.register_theme("midnight", {
    dark  = true,
    text  = colors.cyan,
    colors = {                            -- palette hexes; omit to keep the base palette
        { c = colors.cyan,  hex = 0x00e5ff },
        { c = colors.green, hex = 0x39ff14 },
        { c = colors.red,   hex = 0xff2d55 },
    },
})

mimic.init{theme = "midnight"}
```

The theme table's structural colors are `text`, `text_inv`, `label`, `bg`, `header`,
`highlight_box`, `field_box`, `accent_light`, `accent_dark`, and friends; `dark` tells the
indicator-background logic which way to lean. `colors` is the display palette — a list of
`{ c = colorIndex, hex = 0xRRGGBB }`. You can also pass a theme table directly to
`init{theme = { ... }}` without registering it by name.

## Persistence

Save the choice and it survives a restart:

```lua
mimic.save_prefs("midnight", mimic.COLOR_MODE.STANDARD)   -- write the choice
-- ...next run:
mimic.init{prefs = true}                                  -- load it (explicit theme= still wins)
```

`mimic.load_prefs()` returns the stored `{ theme, color_mode }` if you want to inspect it. The
file path is `mimic.prefs_path` (default `/.mimic-prefs`).

## Theme is chosen at init, not switched live

An element bakes its colors **when it is built**. Swapping `deepslate` ↔ `smooth_stone` (black
↔ white text) therefore needs the screen rebuilt — a palette swap alone can't do it. The
pattern is to save the preference and re-run the program; `examples/themes.lua` does exactly
this. This matches how cc-mek-scada handles theme changes.

## Colorblind modes

`color_mode` remaps the palette for colorblind users, inherited from the engine at no cost:

```lua
mimic.init{theme = "deepslate", color_mode = mimic.COLOR_MODE.DEUTERANOPIA}
```

Available: `STANDARD`, `DEUTERANOPIA`, `PROTANOPIA`, `TRITANOPIA`, `BLUE_IND` (blue means
"good" instead of green), `STD_ON_BLACK`, `BLUE_ON_BLACK`.

## Using theme colors in your own elements

`mimic.style` carries the active theme and ready-made color pairs:

- Indicators: `ind_grn`, `ind_yel`, `ind_red`, `ind_wht`
- Text/background: `root`, `text_colors`, `lu_colors`, `label`, `wh_gray`
- The theme itself: `mimic.style.theme` (`.header`, `.bg`, `.highlight_box`, ...)

Build your own with `mimic.cpair(fg, bg)`. Remember children **inherit** `fg_bg` from their
parent, so you rarely set it more than once per container.

## A note on the `basalt` theme name

`graphics/themes.lua` includes a front-panel theme named `basalt`. That name comes from the
upstream project (the Minecraft block) and is **unrelated** to the
[Basalt](https://basalt.madefor.cc/) UI framework.
