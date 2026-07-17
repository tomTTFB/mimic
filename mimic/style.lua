--
-- mimic - Theme definitions and derived colors
--
-- Adapted from cc-mek-scada's coordinator/ui/style.lua (MIT, Mikayla Fischler),
-- generalized: domain-specific entries removed. See THIRD_PARTY_NOTICES.md.
--

local core   = require("graphics.core")
local themes = require("graphics.themes")

local util   = require("scada-common.util")

local cpair = core.cpair

---@class mimic_style
local style = {}

-- THEME DEFINITIONS --

-- A theme is a plain table of colors. `dark` tells the indicator-background logic
-- which way to lean (light text on dark bg, or the reverse); `colors` is the palette
-- (a list of { c = colorIndex, hex = 0xRRGGBB }) applied to the display, and
-- `color_modes` are the assistive remaps. Custom themes may omit `colors`/`color_modes`
-- to reuse the default palette. See style.make_theme for the full field list.

-- Light theme: dark text on a light gray background.
---@class mimic_theme
local smooth_stone = {
    dark = false,
    text = colors.black,
    text_inv = colors.white,
    label = colors.gray,
    label_dark = colors.gray,
    disabled = colors.lightGray,
    bg = colors.lightGray,
    checkbox_bg = colors.black,
    accent_light = colors.white,
    accent_dark = colors.gray,

    header = cpair(colors.white, colors.gray),

    text_fg = cpair(colors.black, colors._INHERIT),
    label_fg = cpair(colors.gray, colors._INHERIT),
    disabled_fg = cpair(colors.lightGray, colors._INHERIT),

    highlight_box = cpair(colors.black, colors.white),
    highlight_box_bright = cpair(colors.black, colors.white),
    field_box = cpair(colors.black, colors.white),

    colors = themes.smooth_stone.colors,
    color_modes = themes.smooth_stone.color_modes
}

-- Dark theme: light text on a black background. mimic's default.
---@type mimic_theme
local deepslate = {
    dark = true,
    text = colors.white,
    text_inv = colors.black,
    label = colors.lightGray,
    label_dark = colors.gray,
    disabled = colors.gray,
    bg = colors.black,
    checkbox_bg = colors.gray,
    accent_light = colors.gray,
    accent_dark = colors.lightGray,

    header = cpair(colors.white, colors.gray),

    text_fg = cpair(colors.white, colors._INHERIT),
    label_fg = cpair(colors.lightGray, colors._INHERIT),
    disabled_fg = cpair(colors.gray, colors._INHERIT),

    highlight_box = cpair(colors.white, colors.gray),
    highlight_box_bright = cpair(colors.black, colors.lightGray),
    field_box = cpair(colors.white, colors.gray),

    colors = themes.deepslate.colors,
    color_modes = themes.deepslate.color_modes
}

-- registry of named themes; register_theme adds to it, init/set_theme resolve from it
style.themes = { smooth_stone = smooth_stone, deepslate = deepslate }

-- Build a complete theme from a partial definition.
--
-- A custom theme only has to name what it changes: every field it omits is
-- inherited from a base theme (deepslate, or smooth_stone if `dark=false`),
-- including the color palette. So `make_theme{ accent_light = colors.cyan }`
-- is deepslate with a cyan accent, and `make_theme{ colors = {...} }` is
-- deepslate's layout with your own palette hexes.
---@param def table partial theme definition
---@return mimic_theme
function style.make_theme(def)
    if type(def) ~= "table" then error("mimic: a theme must be a table", 0) end

    local base = def.dark == false and smooth_stone or deepslate
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(def) do t[k] = v end

    -- the only thing that can genuinely be wrong: a palette that isn't a palette
    if type(t.colors) ~= "table" then
        error("mimic: theme colors= must be a list of { c = color, hex = 0xRRGGBB }", 0)
    end

    return t
end

-- Register a named theme so it can be selected with init{theme="name"}.
---@param name string
---@param def table theme definition (may be partial; see make_theme)
function style.register_theme(name, def)
    if type(name) ~= "string" then error("mimic: theme name must be a string", 0) end
    style.themes[name] = style.make_theme(def)
end

-- Resolve init's theme argument: a name, a theme table, or the legacy THEME enum.
---@param theme any
---@return mimic_theme
local function resolve(theme)
    if type(theme) == "table" then
        return theme.colors and theme or style.make_theme(theme)
    elseif type(theme) == "string" then
        local t = style.themes[theme]
        if t == nil then
            local names = {}
            for k in pairs(style.themes) do names[#names + 1] = k end
            error("mimic: no theme named '" .. theme .. "'. Known: " .. table.concat(names, ", "), 0)
        end
        return t
    elseif theme == themes.UI_THEME.SMOOTH_STONE then
        return smooth_stone
    elseif theme == themes.UI_THEME.DEEPSLATE then
        return deepslate
    end
    error("mimic: theme must be a name, a theme table, or mimic.THEME.*", 0)
end

-- Select a theme and recompute every derived color pair.
-- Called by mimic.init(); call directly only if changing theme at runtime.
---@param theme any theme name, theme table, or mimic.THEME.* enum
---@param color_mode COLOR_MODE assistive color mode
function style.set_theme(theme, color_mode)
    local colorblind = color_mode ~= themes.COLOR_MODE.STANDARD and color_mode ~= themes.COLOR_MODE.STD_ON_BLACK
    local gray_ind_off = color_mode == themes.COLOR_MODE.STANDARD or color_mode == themes.COLOR_MODE.BLUE_IND

    style.theme = resolve(theme)

    -- indicator backgrounds lean on whether the theme is dark or light, rather than
    -- on which specific theme it is, so custom themes get the right behavior
    if style.theme.dark then
        style.ind_bkg = colors.gray
        style.ind_hi_box_bg = util.trinary(gray_ind_off, colors.lightGray, colors.black)
    else
        style.ind_bkg = util.trinary(gray_ind_off, colors.gray, colors.black)
        style.ind_hi_box_bg = util.trinary(gray_ind_off, colors.gray, colors.black)
    end

    style.colorblind = colorblind

    -- root/background pairs
    style.root = cpair(style.theme.text, style.theme.bg)
    style.label = cpair(style.theme.label, style.theme.bg)

    -- high contrast text (also used for tags)
    style.hc_text = cpair(style.theme.text, style.theme.text_inv)
    -- text on default background
    style.text_colors = cpair(style.theme.text, style.theme.bg)
    -- label & unit colors
    style.lu_colors = cpair(style.theme.label, style.theme.label)
    -- label & unit colors, darker
    style.lu_colors_dark = cpair(style.theme.label_dark, style.theme.label_dark)

    -- indicator pairs; green becomes blue under assistive color modes
    style.ind_grn = cpair(util.trinary(colorblind, colors.blue, colors.green), style.ind_bkg)
    style.ind_yel = cpair(colors.yellow, style.ind_bkg)
    style.ind_red = cpair(colors.red, style.ind_bkg)
    style.ind_wht = cpair(colors.white, style.ind_bkg)
end

-- COMMON COLOR PAIRS --

style.wh_gray = cpair(colors.white, colors.gray)
style.bw_fg_bg = cpair(colors.black, colors.white)
style.dis_colors = cpair(colors.white, colors.lightGray)
style.lg_gray = cpair(colors.lightGray, colors.gray)
style.lg_white = cpair(colors.lightGray, colors.white)
style.gray_white = cpair(colors.gray, colors.white)

-- default to the dark theme so that requiring style alone still yields usable colors
style.set_theme(themes.UI_THEME.DEEPSLATE, themes.COLOR_MODE.STANDARD)

return style
