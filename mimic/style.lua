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

-- Light theme: dark text on a light gray background.
---@class mimic_theme
local smooth_stone = {
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

style.themes = { smooth_stone = smooth_stone, deepslate = deepslate }

-- Select a theme and recompute every derived color pair.
-- Called by mimic.init(); call directly only if changing theme at runtime.
---@param theme UI_THEME main UI theme
---@param color_mode COLOR_MODE assistive color mode
function style.set_theme(theme, color_mode)
    local colorblind = color_mode ~= themes.COLOR_MODE.STANDARD and color_mode ~= themes.COLOR_MODE.STD_ON_BLACK
    local gray_ind_off = color_mode == themes.COLOR_MODE.STANDARD or color_mode == themes.COLOR_MODE.BLUE_IND

    style.ind_bkg = colors.gray
    style.ind_hi_box_bg = util.trinary(gray_ind_off, colors.gray, colors.black)

    if theme == themes.UI_THEME.SMOOTH_STONE then
        style.theme = smooth_stone
        style.ind_bkg = util.trinary(gray_ind_off, colors.gray, colors.black)
    elseif theme == themes.UI_THEME.DEEPSLATE then
        style.theme = deepslate
        style.ind_hi_box_bg = util.trinary(gray_ind_off, colors.lightGray, colors.black)
    else
        error("mimic: unknown theme, expected mimic.THEME.SMOOTH_STONE or mimic.THEME.DEEPSLATE", 0)
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
