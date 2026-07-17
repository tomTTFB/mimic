--
-- mimic - Trend
--
-- A value plotted over time. Every real monitoring UI has one; cc-mek-scada has
-- none, so this is the element that makes mimic worth using over the engine it
-- is built on.
--
--     mimic.Trend{parent=box,x=2,y=2,width=60,height=8,max=100,bind="rps"}
--     mimic.Trend{parent=box,x=2,y=2,width=60,height=8,max=100,style="line"}
--
-- Each push shifts the chart left by one column.
--
-- Vertical resolution is 3x the character height. CC's characters 128-159 are
-- 2x3 subpixel blocks, so one cell holds three bands:
--
--     0x83  top 1/3 in FG          0x8c  middle 1/3 in FG
--     0x8f  top 2/3 in FG          ... and drawn with the colors swapped,
--                                  0x8f becomes a bottom 1/3 fill
--
-- "area" fills from the baseline up (the same trick VerticalBar uses).
-- "line" draws only the band at the value, using 0x8c for the middle band —
-- which nothing in the upstream engine does.
--

local element = require("graphics.element")

local util    = require("scada-common.util")

local style_m = require("mimic.style")

-- subpixel band characters
local BAND_TOP    = "\x83"   -- top 1/3 in fg
local BAND_MID    = "\x8c"   -- middle 1/3 in fg
local BAND_BOTTOM = "\x8f"   -- top 2/3 in fg; swap colors for a bottom 1/3 fill

---@class trend_args
---@field width integer samples shown; one column per sample
---@field height integer chart height in characters (3x vertical resolution)
---@field style? string "area" (default) or "line"
---@field max? number value at full height, defaults to 1.0
---@field min? number value at the baseline, defaults to 0
---@field bind? string psil key; each publish pushes a sample
---@field transform? function value transform applied before scaling
---@field color? color plot color, defaults to green
---@field bg? color empty color, defaults to the indicator background
---@field fill? number initial value for every column, defaults to min
---@field parent graphics_element
---@field x? integer
---@field y? integer

-- Create a trend chart.
---@nodiscard
---@param args trend_args
---@return graphics_element element, element_id id
return function (args)
    element.assert(util.is_int(args.width) and args.width >= 1, "width must be an integer >= 1")
    element.assert(util.is_int(args.height) and args.height >= 1, "height must be an integer >= 1")

    local chart_style = args.style or "area"
    element.assert(chart_style == "area" or chart_style == "line",
                   "style must be \"area\" or \"line\"")

    local min = args.min or 0
    local max = args.max or 1.0
    element.assert(max > min, "max must be greater than min")

    local e = element.new(args --[[@as graphics_args]])

    local w, h = e.frame.w, e.frame.h

    local fg = args.color or colors.green
    local bg = args.bg or style_m.ind_bkg
    local blit_fg = colors.toBlit(fg)
    local blit_bg = colors.toBlit(bg)

    -- ring buffer of raw values, oldest first
    local samples = {}
    local drawn = {}    -- last subpixel height drawn per column, to skip no-op redraws
    local initial = args.fill or min
    for i = 1, w do samples[i] = initial; drawn[i] = -1 end

    e.value = initial

    -- value -> subpixel height, 0 to h*3
    local function to_sub(v)
        local frac = (v - min) / (max - min)
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        return util.round(frac * (h * 3))
    end

    local function draw_col(col, force)
        local sub = to_sub(samples[col])
        if not force and drawn[col] == sub then return end
        drawn[col] = sub

        if chart_style == "line" then
            for row = 1, h do
                e.w_set_cur(col, row)
                e.w_blit(" ", blit_bg, blit_bg)
            end

            if sub >= 1 then
                local cell = math.ceil(sub / 3)       -- cells up from the baseline
                local within = (sub - 1) % 3          -- 0 bottom band, 1 middle, 2 top
                e.w_set_cur(col, h - cell + 1)

                if within == 0 then
                    e.w_blit(BAND_BOTTOM, blit_bg, blit_fg)   -- swapped: bottom band
                elseif within == 1 then
                    e.w_blit(BAND_MID, blit_fg, blit_bg)
                else
                    e.w_blit(BAND_TOP, blit_fg, blit_bg)
                end
            end
        else
            local full = math.floor(sub / 3)
            local rem = sub % 3
            local row = h

            for _ = 1, full do
                e.w_set_cur(col, row)
                e.w_blit(" ", blit_bg, blit_fg)
                row = row - 1
            end

            if rem == 1 then
                e.w_set_cur(col, row)
                e.w_blit(BAND_BOTTOM, blit_bg, blit_fg)
                row = row - 1
            elseif rem == 2 then
                e.w_set_cur(col, row)
                e.w_blit(BAND_TOP, blit_bg, blit_fg)
                row = row - 1
            end

            while row >= 1 do
                e.w_set_cur(col, row)
                e.w_blit(" ", blit_bg, blit_bg)
                row = row - 1
            end
        end
    end

    function e.redraw()
        for col = 1, w do draw_col(col, true) end
    end

    -- push a sample; the chart shifts left
    ---@param v number
    function e.on_update(v)
        -- a wrong TYPE is a programming bug -> fail loudly
        element.assert(type(v) == "number", "Trend expects a number, got " .. type(v))
        -- a non-finite VALUE (NaN/inf) is bad data, not a bug: a glitchy sensor
        -- reading must not crash a live dashboard. Skip it and keep the chart as-is,
        -- rather than shifting a poison value into the buffer.
        if v ~= v or v == math.huge or v == -math.huge then return end

        table.remove(samples, 1)
        samples[#samples + 1] = v
        e.value = v

        -- the whole plot shifts, so every column is re-evaluated; draw_col skips
        -- any column whose height did not actually change
        for col = 1, w do draw_col(col) end
    end

    function e.set_value(v) e.on_update(v) end

    ---@class Trend:graphics_element
    local Trend, id = e.complete(true)

    -- Set every column to the same value.
    ---@param v number
    function Trend.set_all(v)
        for i = 1, w do samples[i] = v end
        e.value = v
        for col = 1, w do draw_col(col) end
    end

    -- The current samples, oldest first.
    ---@return number[]
    function Trend.get_samples()
        local copy = {}
        for i = 1, #samples do copy[i] = samples[i] end
        return copy
    end

    -- alias, reads better than update() when pushing time series data
    Trend.push = Trend.update

    return Trend, id
end
