--
-- mimic - Row
--
-- Lays out cells left to right, so you stop hand-computing column x positions.
-- The engine auto-flows vertically (a Div stacks its children) but not
-- horizontally, which is why every dashboard is full of x=2+(i-1)*40 arithmetic.
--
-- Equal columns:
--
--     local cols = mimic.Row{parent=root,y=3,height=14,count=4,gap=1}
--     for i = 1, 4 do mimic.Panel{parent=cols[i],...} end
--
-- Explicit widths (a 0 width means "share what's left equally"):
--
--     local cols = mimic.Row{parent=root,y=3,height=14,widths={40,40,0,0}}
--
-- Returns the cells as positioned Divs, plus the container.
--

local elements = require("mimic.elements")

---@class row_args
---@field parent graphics_element
---@field ps? psil data source for the cells; inherited from the parent otherwise
---@field count? integer number of equal-width cells (use this or widths=)
---@field widths? integer[] explicit cell widths; a 0 shares the leftover equally
---@field gap? integer blank columns between cells, defaults to 1
---@field x? integer
---@field y? integer
---@field width? integer total width, defaults to the parent's
---@field height integer cell height
---@field fg_bg? cpair

-- Lay out cells in a row.
---@nodiscard
---@param args row_args
---@return table cells, graphics_element container
return function (args)
    if args.height == nil then error("mimic: Row{height=} is required", 0) end
    if args.count == nil and args.widths == nil then
        error("mimic: Row needs count= (equal columns) or widths= (explicit)", 0)
    end
    if args.count ~= nil and args.widths ~= nil then
        error("mimic: Row takes count= or widths=, not both", 0)
    end

    local gap = args.gap or 1
    local total_w = args.width or args.parent.get_width() - (args.x and (args.x - 1) or 0)

    local container = elements.Div{parent=args.parent,ps=args.ps,x=args.x,y=args.y,
                                   width=total_w,height=args.height,fg_bg=args.fg_bg}

    -- resolve each cell's width
    local widths = {}
    if args.count then
        local n = args.count
        if n < 1 then error("mimic: Row{count=" .. n .. "} must be >= 1", 0) end
        -- distribute the leftover after gaps as evenly as possible, giving the
        -- remainder to the leftmost cells so the row fills exactly
        local avail = total_w - (n - 1) * gap
        if avail < n then
            error("mimic: Row{count=" .. n .. "} does not fit in width " .. total_w ..
                  " with gap=" .. gap, 0)
        end
        local base, extra = math.floor(avail / n), avail % n
        for i = 1, n do widths[i] = base + (i <= extra and 1 or 0) end
    else
        local n = #args.widths
        -- first pass: fixed widths and count the flexible (0) cells
        local fixed, flex = 0, 0
        for i = 1, n do
            if args.widths[i] == 0 then flex = flex + 1 else fixed = fixed + args.widths[i] end
        end
        local leftover = total_w - fixed - (n - 1) * gap
        if leftover < flex then
            error("mimic: Row widths= plus gaps exceed the width " .. total_w, 0)
        end
        local base, extra = 0, 0
        if flex > 0 then base, extra = math.floor(leftover / flex), leftover % flex end
        local fi = 0
        for i = 1, n do
            if args.widths[i] == 0 then
                fi = fi + 1
                widths[i] = base + (fi <= extra and 1 or 0)
            else
                widths[i] = args.widths[i]
            end
        end
    end

    -- place the cells
    local cells = {}
    local cx = 1
    for i = 1, #widths do
        cells[i] = elements.Div{parent=container,x=cx,y=1,width=widths[i],height=args.height}
        cx = cx + widths[i] + gap
    end

    return cells, container
end
