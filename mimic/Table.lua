--
-- mimic - Table
--
-- Columns with a header and a scrolling body. Dashboards show tabular data
-- constantly (a row per node, chamber, unit) and the engine has no table element.
-- Built on ListBox, which already scrolls.
--
--     local t = mimic.Table{parent=panel,x=2,y=2,width=50,height=12,columns={
--         { name="NODE",  width=10 },
--         { name="STATE", width=12 },
--         { name="CPU",   width=8, align=mimic.ALIGN.RIGHT },
--     }}
--
--     local r = t.add_row{ "NODE 01", "ONLINE", "81%" }
--     t.set_cell(r, 3, "84%")     -- update one cell later
--
-- Returns the table element with add_row / set_cell / set_row / clear / row_count.
--

local core     = require("graphics.core")

local ListBox  = require("graphics.elements.ListBox")
local Div      = require("graphics.elements.Div")
local TextBox  = require("graphics.elements.TextBox")

local style_m  = require("mimic.style")

---@class table_column
---@field name string header text
---@field width integer column width in characters
---@field align? ALIGN cell alignment, left by default

---@class table_args
---@field columns table_column[] the columns
---@field parent graphics_element
---@field ps? psil
---@field gap? integer blank columns between columns, defaults to 1
---@field header_fg_bg? cpair header colors, defaults to the theme header
---@field row_fg_bg? cpair row colors, inherited from the parent otherwise
---@field max_rows? integer hard row ceiling, defaults to 500
---@field x? integer
---@field y? integer
---@field width? integer defaults to the parent's width
---@field height integer total height, header included

-- Create a table.
---@nodiscard
---@param args table_args
---@return table tbl the table, with add_row/set_cell/set_row/clear/row_count
return function (args)
    if type(args.columns) ~= "table" or #args.columns == 0 then
        error("mimic: Table{columns=} is required and must be non-empty", 0)
    end
    if args.height == nil then error("mimic: Table{height=} is required", 0) end

    local gap = args.gap or 1

    for i = 1, #args.columns do
        local c = args.columns[i]
        if c.name == nil or c.width == nil then
            error("mimic: Table column " .. i .. " needs name= and width=", 0)
        end
    end

    -- x offset of each column, so header and cells line up
    local col_x = {}
    local cx = 1
    for i = 1, #args.columns do
        col_x[i] = cx
        cx = cx + args.columns[i].width + gap
    end
    local total_w = args.width or args.parent.get_width() - (args.x and (args.x - 1) or 0)

    local host = Div{parent=args.parent,x=args.x,y=args.y,width=total_w,height=args.height,
                     fg_bg=args.row_fg_bg}

    -- header row
    local header = Div{parent=host,x=1,y=1,width=total_w,height=1,
                       fg_bg=args.header_fg_bg or style_m.theme.header}
    for i = 1, #args.columns do
        local c = args.columns[i]
        TextBox{parent=header,x=col_x[i],y=1,width=c.width,text=c.name,
                alignment=c.align or core.ALIGN.LEFT}
    end

    -- scrolling body. ListBox has a fixed internal scroll height set at creation, so
    -- there is a hard row ceiling: adding past it used to crash with a cryptic
    -- "frame height not >= 1". max_rows sets that ceiling (each row is one line) and
    -- add_row reports clearly when it is reached.
    local body_h = args.height - 1
    if body_h < 1 then error("mimic: Table{height=} needs at least 2 (header + a row)", 0) end

    local max_rows = args.max_rows or 500

    local body = ListBox{parent=host,x=1,y=2,width=total_w,height=body_h,scroll_height=max_rows,
                         fg_bg=args.row_fg_bg,nav_fg_bg=style_m.lg_gray}

    ---@class mimic_table
    local tbl = {}
    local rows = {}   ---@type { div: graphics_element, cells: graphics_element[] }[]

    -- Append a row. values is a list of strings, one per column (missing = blank).
    ---@param values string[]
    ---@return integer row index
    function tbl.add_row(values)
        if #rows >= max_rows then
            error("mimic: Table is full at " .. max_rows .. " rows. " ..
                  "Pass max_rows= to raise the ceiling, or clear() old rows.", 0)
        end
        values = values or {}
        -- Give the row an explicit y (its 1-based index) rather than letting the
        -- engine auto-place it. The auto-y counter only ever grows - it is not reset
        -- when rows are deleted - so a table that clear()s and refills every tick
        -- would eventually place a row past the scroll frame and crash. The index is
        -- bounded by max_rows and resets to 1 after clear(). ListBox re-flows anyway.
        local line = Div{parent=body,y=#rows + 1,width=total_w,height=1}
        local cells = {}
        for i = 1, #args.columns do
            local c = args.columns[i]
            cells[i] = TextBox{parent=line,x=col_x[i],y=1,width=c.width,
                               text=tostring(values[i] or ""),
                               alignment=c.align or core.ALIGN.LEFT}
        end
        rows[#rows + 1] = { div = line, cells = cells }
        return #rows
    end

    -- Update one cell.
    ---@param row integer
    ---@param col integer
    ---@param text any
    function tbl.set_cell(row, col, text)
        local r = rows[row]
        if r == nil then error("mimic: Table has no row " .. tostring(row), 0) end
        if r.cells[col] == nil then error("mimic: Table has no column " .. tostring(col), 0) end
        r.cells[col].set_value(tostring(text))
    end

    -- Replace a whole row's values.
    ---@param row integer
    ---@param values string[]
    function tbl.set_row(row, values)
        for i = 1, #args.columns do tbl.set_cell(row, i, values[i] or "") end
    end

    -- Remove every row.
    function tbl.clear()
        for i = #rows, 1, -1 do rows[i].div.delete() end
        rows = {}
    end

    ---@return integer
    function tbl.row_count() return #rows end

    tbl.element = host
    return tbl
end
