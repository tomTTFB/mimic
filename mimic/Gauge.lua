--
-- mimic - Gauge
--
-- A labelled bar: label, fill, and percentage on one line. Assembled by hand
-- constantly upstream (label TextBox + HorizontalBar, x offsets counted out).
--
--     mimic.Gauge{parent=box,x=2,y=3,width=24,label="CPU",bind="cpu"}
--
-- Values are fractions, 0.0 to 1.0, matching HorizontalBar. Pass max= to give
-- values in real units instead and have them scaled.
--

local core     = require("graphics.core")

local elements = require("mimic.elements")
local style    = require("mimic.style")

local cpair = core.cpair

---@class gauge_args
---@field label string text to the left of the bar
---@field label_width? integer label column width, defaults to the label's length + 1
---@field bind? string psil key
---@field transform? function value transform, applied before max= scaling
---@field max? number scale values by this instead of expecting a 0-1 fraction
---@field value? number initial value
---@field color? cpair bar fill/empty colors, defaults to green on the indicator background
---@field text_color? cpair colors for the trailing percentage, inherited from the parent if omitted
---@field show_percent? boolean draw the percentage after the bar, true by default
---@field parent graphics_element
---@field ps? psil
---@field x? integer
---@field y? integer
---@field width integer total width, label included

-- Create a labelled bar gauge.
---@nodiscard
---@param args gauge_args
---@return graphics_element bar the bar element
return function (args)
    if args.label == nil then error("mimic: Gauge{label=} is required", 0) end
    if args.width == nil then error("mimic: Gauge{width=} is required", 0) end

    local label_w = args.label_width or (string.len(args.label) + 1)
    local bar_w = args.width - label_w

    if bar_w < 3 then
        error("mimic: Gauge{width=" .. args.width .. "} leaves only " .. bar_w ..
              " for the bar after a " .. label_w .. "-wide label; widen it or set label_width=", 0)
    end

    local row = elements.Div{parent=args.parent,ps=args.ps,x=args.x,y=args.y,
                             width=args.width,height=1}

    elements.TextBox{parent=row,x=1,y=1,text=args.label,width=label_w,
                     fg_bg=style.label}

    -- scale real units into the 0-1 fraction HorizontalBar expects
    local transform = args.transform
    if args.max ~= nil then
        if args.max == 0 then error("mimic: Gauge{max=0} would divide by zero", 0) end
        local inner = transform
        transform = function (v)
            if inner then v = inner(v) end
            return v / args.max
        end
    end

    local show_pct = args.show_percent
    if show_pct == nil then show_pct = true end

    -- HorizontalBar's colors are easy to get backwards: bar_fg_bg is the BAR
    -- (filled/empty), while fg_bg is the element's colors and is what the trailing
    -- percentage is drawn in. Pass color= to the bar and let the percent inherit the
    -- surrounding text colors, which is how the upstream screens do it.
    local bar = elements.HorizontalBar{
        parent = row,
        x = label_w + 1,
        y = 1,
        width = bar_w,
        height = 1,
        fg_bg = args.text_color,
        show_percent = show_pct,
        bar_fg_bg = args.color or cpair(colors.green, style.ind_bkg),
        bind = args.bind,
        transform = transform
    }

    if args.value ~= nil then
        bar.update(args.max and (args.value / args.max) or args.value)
    end

    return bar
end
