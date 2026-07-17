--
-- mimic - themes
--
-- Shows configurable theming: the two built-in themes, a custom theme, and
-- persisting the choice so it survives a restart.
--
--   themes                -- cycle deepslate / smooth_stone / midnight with the buttons
--   themes midnight       -- start on a named theme
--
-- Theme is chosen at init: an element bakes its colors when built, so switching
-- theme rebuilds the screen (this example re-runs itself). That is the same model
-- cc-mek-scada uses.
--

require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

-- a custom theme: deepslate's layout with a neon palette. A partial definition -
-- everything not named here is inherited from the base (deepslate, since dark).
mimic.register_theme("midnight", {
    dark = true,
    text = colors.cyan,
    colors = {
        { c = colors.cyan,  hex = 0x00e5ff },
        { c = colors.green, hex = 0x39ff14 },
        { c = colors.red,   hex = 0xff2d55 },
        { c = colors.black, hex = 0x02010a },
        { c = colors.gray,  hex = 0x1b2733 },
    }
})

local ORDER = { "deepslate", "smooth_stone", "midnight" }

-- which theme to show: the command-line arg, else the saved pref, else deepslate
local requested = ...
local saved = mimic.load_prefs()
local current = requested or (saved and saved.theme) or "deepslate"

local style = mimic.style
local root = mimic.init{ theme = current }

local W = root.get_width()

m.TextBox{parent=root, y=1, text="MIMIC THEMES", alignment=mimic.ALIGN.CENTER,
          fg_bg=style.theme.header}

local box = mimic.Panel{parent=root, x=2, y=3, width=math.min(W-2, 40), height=root.get_height()-3,
                        title="THEME: " .. current, accent=colors.cyan}

m.TextBox{parent=box, x=2, y=1, width=box.get_width()-2,
          text="Same screen, different palette. Pick one:"}

-- a strip of the indicator colors so the palette change is visible
mimic.LEDList{parent=box, x=2, y=3, width=box.get_width()-2, leds={
    { label="GREEN  (good)", value=true },
    { label="YELLOW (warn)", value=true, color=style.ind_yel },
    { label="RED    (fault)", value=true, color=style.ind_red },
}}

m.DataIndicator{parent=box, x=2, y=7, label="Sample:", unit="rpm", format="%7.0f",
                value=3600, width=box.get_width()-2,
                fg_bg=style.text_colors, lu_colors=style.lu_colors}

-- one button per theme; clicking saves the choice and re-runs on the new theme
local bx = 2
for _, name in ipairs(ORDER) do
    m.PushButton{parent=box, x=bx, y=box.get_height()-1, text=name, min_width=#name+2,
                 fg_bg=style.wh_gray, active_fg_bg=style.ind_grn,
                 callback=function ()
                     mimic.save_prefs(name)   -- persist, then rebuild on the new theme
                     mimic.stop()
                     shell.run("themes", name)
                     -- when that returns (the child quit), stop this instance too
                     mimic.stop()
                     os.queueEvent("terminate")
                 end}
    bx = bx + #name + 3
end

mimic.run()
