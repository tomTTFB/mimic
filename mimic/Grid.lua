--
-- mimic - Grid
--
-- A grid of equal cells, for repeating one widget N times without computing
-- every x/y by hand.
--
--     local cells = mimic.Grid{parent=root,x=2,y=3,width=160,height=40,
--                              cols=4,rows=1,gap_x=1}
--     for i = 1, 4 do mimic.Panel{parent=cells[i],...} end
--
-- Cells are returned in row-major order (left to right, top to bottom), and are
-- also reachable as cells(col,row).
--

local elements = require("mimic.elements")

---@class grid_args
---@field parent graphics_element
---@field ps? psil data source for the cells; inherited from the parent otherwise
---@field cols integer columns
---@field rows integer rows
---@field gap_x? integer blank columns between cells, defaults to 1
---@field gap_y? integer blank rows between cells, defaults to 1
---@field x? integer
---@field y? integer
---@field width? integer total width, defaults to the parent's
---@field height integer total height
---@field fg_bg? cpair

-- Lay out a grid of equal cells.
---@nodiscard
---@param args grid_args
---@return table cells row-major, also callable as cells(col,row); plus the container
return function (args)
    if args.cols == nil or args.rows == nil then
        error("mimic: Grid needs cols= and rows=", 0)
    end
    if args.height == nil then error("mimic: Grid{height=} is required", 0) end
    if args.cols < 1 or args.rows < 1 then error("mimic: Grid cols/rows must be >= 1", 0) end

    local gap_x = args.gap_x or 1
    local gap_y = args.gap_y or 1
    local total_w = args.width or args.parent.get_width() - (args.x and (args.x - 1) or 0)
    local total_h = args.height

    local container = elements.Div{parent=args.parent,ps=args.ps,x=args.x,y=args.y,
                                   width=total_w,height=total_h,fg_bg=args.fg_bg}

    local avail_w = total_w - (args.cols - 1) * gap_x
    local avail_h = total_h - (args.rows - 1) * gap_y
    if avail_w < args.cols then
        error("mimic: Grid cols=" .. args.cols .. " does not fit in width " .. total_w, 0)
    end
    if avail_h < args.rows then
        error("mimic: Grid rows=" .. args.rows .. " does not fit in height " .. total_h, 0)
    end

    -- remainder spread over the leading cells so the grid fills exactly
    local cw, ew = math.floor(avail_w / args.cols), avail_w % args.cols
    local ch, eh = math.floor(avail_h / args.rows), avail_h % args.rows

    -- precompute per-column widths / per-row heights and their offsets
    local col_w, col_x = {}, {}
    local cx = 1
    for c = 1, args.cols do
        col_w[c] = cw + (c <= ew and 1 or 0)
        col_x[c] = cx
        cx = cx + col_w[c] + gap_x
    end
    local row_h, row_y = {}, {}
    local cy = 1
    for r = 1, args.rows do
        row_h[r] = ch + (r <= eh and 1 or 0)
        row_y[r] = cy
        cy = cy + row_h[r] + gap_y
    end

    local cells = {}
    local by_rc = {}
    for r = 1, args.rows do
        by_rc[r] = {}
        for c = 1, args.cols do
            local cell = elements.Div{parent=container,x=col_x[c],y=row_y[r],
                                      width=col_w[c],height=row_h[r]}
            cells[#cells + 1] = cell   -- row-major
            by_rc[r][c] = cell
        end
    end

    -- also let callers say cells(col, row) instead of doing the index math
    return setmetatable(cells, {
        __call = function (_, col, row)
            local rr = by_rc[row]
            return rr and rr[col]
        end
    }), container
end
