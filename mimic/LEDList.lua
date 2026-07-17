--
-- mimic - LEDList
--
-- A column of labelled indicator lights from a table, which is the dominant
-- idiom on status panels.
--
--     m.LEDList{parent=root,x=2,y=3,leds={
--         { label="STATUS",    bind="status" },
--         { label="HEARTBEAT", bind="heartbeat" },
--         {},                                      -- blank entry = gap
--         { label="FAULT", bind="fault", color=style.ind_red, flash=true },
--     }}
--
-- Builds on Div's vertical auto-flow and line_break() rather than replacing them.
--

local elements = require("mimic.elements")
local style    = require("mimic.style")

---@class led_entry
---@field label? string LED label; omit the whole entry for a blank spacer line
---@field bind? string psil key to bind to
---@field transform? function value transform applied before update
---@field color? cpair on/off colors, defaults to green
---@field flash? boolean flash instead of holding on
---@field period? PERIOD flash period
---@field value? boolean initial state
---@field kind? string "LED" (default) or "IndicatorLight"

---@class ledlist_args
---@field leds led_entry[] the rows
---@field parent graphics_element
---@field ps? psil data source for bound rows; inherited from parent if omitted
---@field kind? string default element for rows: "LED" or "IndicatorLight"
---@field color? cpair default on/off colors for rows
---@field x? integer
---@field y? integer
---@field width? integer defaults to the parent's width
---@field fg_bg? cpair

-- Create a column of labelled LEDs.
---@nodiscard
---@param args ledlist_args
---@return graphics_element container, table rows the container, and the created LEDs by label
return function (args)
    if type(args.leds) ~= "table" then
        error("mimic: LEDList{leds=} is required and must be a table", 0)
    end
    if #args.leds == 0 then
        error("mimic: LEDList{leds={}} is empty; give it at least one row", 0)
    end

    local default_kind = args.kind or "LED"
    local default_color = args.color or style.ind_grn

    -- validate every row before building anything, so a bad row reports itself
    -- rather than failing later as a confusing geometry error
    for i = 1, #args.leds do
        local e = args.leds[i]
        if e ~= nil and e.label ~= nil then
            local kind = e.kind or default_kind
            if kind ~= "LED" and kind ~= "IndicatorLight" then
                error("mimic: LEDList row " .. i .. " (\"" .. tostring(e.label) ..
                      "\") has kind=\"" .. tostring(kind) ..
                      "\", expected \"LED\" or \"IndicatorLight\"", 0)
            end
            if e.transform ~= nil and type(e.transform) ~= "function" then
                error("mimic: LEDList row " .. i .. " (\"" .. tostring(e.label) ..
                      "\") has a non-function transform", 0)
            end
        end
    end

    -- height: one line per entry, so the container never clips its rows
    local height = args.height or #args.leds

    local container = elements.Div{parent=args.parent,ps=args.ps,x=args.x,y=args.y,
                                   width=args.width,height=height,fg_bg=args.fg_bg}

    local rows = {}

    for i = 1, #args.leds do
        local e = args.leds[i]

        if e == nil or e.label == nil then
            -- blank entry: a gap, using the same line_break the Div already offers
            container.line_break()
        else
            local kind = e.kind or default_kind

            local led = elements[kind]{
                parent = container,
                label = e.label,
                colors = e.color or default_color,
                flash = e.flash,
                period = e.period,
                bind = e.bind,
                transform = e.transform
            }

            if e.value ~= nil then led.update(e.value) end

            rows[e.label] = led
            rows[#rows + 1] = led
        end
    end

    return container, rows
end
