--
-- mimic - BarChart
--
-- Vertical bars for comparing categories, with labels underneath.
--
--     mimic.BarChart{parent=box,x=2,y=2,width=40,height=10,max=100,bars={
--         { label="N1", bind="n1_cpu", color=colors.green },
--         { label="N2", bind="n2_cpu", color=colors.green },
--         { label="N3", bind="n3_cpu" },
--     }}
--
-- Where Trend plots one value over time, this compares several values right now.
-- Built from VerticalBar, which already handles fractional subpixel fill, so this
-- has no drawing code of its own.
--
-- Requires the vendored elements directly rather than mimic.elements, to stay out
-- of a require cycle (mimic.elements lists this module in its lazy PATHS table).
--

local core        = require("graphics.core")

local Div         = require("graphics.elements.Div")
local TextBox     = require("graphics.elements.TextBox")
local VerticalBar = require("graphics.elements.indicators.VerticalBar")

local style_m     = require("mimic.style")

local cpair = core.cpair

---@class bar_entry
---@field label string short label shown under the bar
---@field bind? string psil key
---@field transform? function value transform, applied before max= scaling
---@field color? color bar color, defaults to the chart color
---@field value? number initial value

---@class barchart_args
---@field bars bar_entry[] the bars
---@field max? number value at full height, defaults to 1.0
---@field color? color default bar color, defaults to green
---@field bg? color empty color, defaults to the indicator background
---@field gap? integer blank columns between bars, defaults to 1
---@field show_labels? boolean label row underneath, true by default
---@field parent graphics_element
---@field ps? psil data source; inherited from the parent if omitted
---@field x? integer
---@field y? integer
---@field width integer
---@field height integer total height, label row included

-- Create a vertical bar chart.
---@nodiscard
---@param args barchart_args
---@return graphics_element container, table bars the container, and the bars by label
return function (args)
    if type(args.bars) ~= "table" or #args.bars == 0 then
        error("mimic: BarChart{bars=} is required and must be a non-empty table", 0)
    end
    if args.width == nil then error("mimic: BarChart{width=} is required", 0) end
    if args.height == nil then error("mimic: BarChart{height=} is required", 0) end

    local n = #args.bars
    local gap = args.gap or 1
    local show_labels = args.show_labels
    if show_labels == nil then show_labels = true end

    local plot_h = args.height - (show_labels and 1 or 0)
    if plot_h < 1 then
        error("mimic: BarChart{height=" .. args.height .. "} leaves no room to plot" ..
              (show_labels and " once the label row is taken" or ""), 0)
    end

    -- widest bar that fits all n bars plus the gaps between them
    local bar_w = math.floor((args.width - (n - 1) * gap) / n)
    if bar_w < 1 then
        error("mimic: BarChart{width=" .. args.width .. "} cannot fit " .. n ..
              " bars with gap=" .. gap .. "; widen it, reduce gap=, or use fewer bars", 0)
    end

    local max = args.max or 1.0
    if max == 0 then error("mimic: BarChart{max=0} would divide by zero", 0) end

    local container = Div{parent=args.parent,x=args.x,y=args.y,
                          width=args.width,height=args.height}

    -- mimic.elements wraps this constructor and records ps= for us, but the bars are
    -- built here with the vendored constructors, so resolve the data source directly
    local elements = require("mimic.elements")
    local ps = args.ps or elements.get_ps(args.parent)

    local bars = {}
    local default_color = args.color or colors.green
    local bg = args.bg or style_m.ind_bkg

    for i = 1, n do
        local b = args.bars[i]
        if b.label == nil then
            error("mimic: BarChart bar " .. i .. " has no label", 0)
        end

        local x = 1 + (i - 1) * (bar_w + gap)

        local bar = VerticalBar{parent=container,x=x,y=1,width=bar_w,height=plot_h,
                                fg_bg=cpair(b.color or default_color, bg)}

        if show_labels then
            -- centre the label under its bar, clipped to the bar's width
            local text = string.sub(b.label, 1, bar_w)
            TextBox{parent=container,x=x,y=args.height,width=bar_w,text=text,
                    alignment=core.ALIGN.CENTER,fg_bg=style_m.label}
        end

        if b.bind ~= nil then
            if ps == nil then
                error("mimic: BarChart bar \"" .. b.label .. "\" has bind= but no data source. " ..
                      "Pass ps= on the chart or any ancestor, or via mimic.init{ps=...}.", 0)
            end

            local inner = b.transform
            bar.register(ps, b.bind, function (v)
                if inner then v = inner(v) end
                bar.update(v / max)
            end)
        end

        if b.value ~= nil then bar.update(b.value / max) end

        bars[b.label] = bar
        bars[#bars + 1] = bar
    end

    return container, bars
end
