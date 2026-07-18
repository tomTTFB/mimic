--
-- mimic - Paginator
--
-- Pages through a list of items, N per page, with prev/next nav. For when there
-- are more things to show (chambers, nodes, units) than fit on one screen.
--
--     mimic.Paginator{parent=box, x=1, y=1, width=W, height=H,
--         items = chambers, per_page = 6, cols = 3,
--         render = function (slot, chamber, index)
--             mimic.Panel{parent=slot, x=1, y=1, width=slot.get_width(),
--                         height=slot.get_height(), title=chamber.name}
--             -- ... build the item's widgets into `slot` ...
--         end}
--
-- Different from Tabs (a fixed named set) and from Table/ListBox (vertical scroll
-- of a long list): this lays out a grid of items per page and flips between pages.
--
-- All pages are built up front (hidden) and nav just switches which is visible, so
-- there is no per-flip rebuild. Bounded item counts only - that is the dashboard
-- case; it is not meant for paging tens of thousands of rows.
--

local core        = require("graphics.core")

local MultiPane   = require("graphics.elements.MultiPane")
local PushButton  = require("graphics.elements.controls.PushButton")
local TextBox     = require("graphics.elements.TextBox")

local elements    = require("mimic.elements")
local style_m     = require("mimic.style")
local Grid        = require("mimic.Grid")

---@class paginator_args
---@field items table[] the data items to page through
---@field render function render(slot, item, index) - fill a slot Div for one item
---@field per_page integer slots per page
---@field cols? integer grid columns per page, defaults to 1 (a vertical stack)
---@field gap_x? integer column gap, defaults to 1
---@field gap_y? integer row gap, defaults to 0
---@field nav? boolean draw the prev / indicator / next row, true by default
---@field accent? color nav accent color, defaults to gray
---@field parent graphics_element
---@field ps? psil data source for the pages
---@field x? integer
---@field y? integer
---@field width? integer defaults to the parent's width
---@field height integer total height, nav row included

-- Create a paginated view of items.
---@nodiscard
---@param args paginator_args
---@return table paginator with page(n)/next()/prev()/current()/page_count/element
return function (args)
    if type(args.items) ~= "table" then error("mimic: Paginator{items=} must be a table", 0) end
    if type(args.render) ~= "function" then error("mimic: Paginator{render=} must be a function", 0) end
    if type(args.per_page) ~= "number" or args.per_page < 1 then
        error("mimic: Paginator{per_page=} must be >= 1", 0)
    end
    if args.height == nil then error("mimic: Paginator{height=} is required", 0) end

    local cols = args.cols or 1
    if cols < 1 or cols > args.per_page then
        error("mimic: Paginator{cols=" .. cols .. "} must be between 1 and per_page", 0)
    end

    local nav = args.nav
    if nav == nil then nav = true end
    local accent = args.accent or colors.gray

    local total_w = args.width or (args.parent.get_width() - (args.x and (args.x - 1) or 0))
    local n = #args.items
    local page_count = math.max(1, math.ceil(n / args.per_page))
    local rows_per_page = math.ceil(args.per_page / cols)

    -- reserve the bottom row for nav
    local item_h = args.height - (nav and 1 or 0)
    if item_h < 1 then error("mimic: Paginator{height=} is too small for the nav row", 0) end

    local container = elements.Div{parent=args.parent, ps=args.ps, x=args.x, y=args.y,
                                   width=total_w, height=args.height}

    -- one hidden Div per page; MultiPane shows one at a time.
    -- elements.Div (not the raw one) so the ps data source propagates from the
    -- container into each page, and from there into the slots the caller renders -
    -- otherwise a bound element inside render() would find no data source.
    local pages, panes = {}, {}
    for p = 1, page_count do
        local page = elements.Div{parent=container, x=1, y=1, width=total_w, height=item_h, hidden=(p > 1)}
        pages[p] = page
        panes[p] = page
    end
    local pane = MultiPane{parent=container, x=1, y=1, width=total_w, height=item_h, panes=panes}

    -- lay out per_page slots on each page and render the items into them
    for p = 1, page_count do
        local slots = Grid{parent=pages[p], x=1, y=1, width=total_w, height=item_h,
                           cols=cols, rows=rows_per_page,
                           gap_x=args.gap_x or 1, gap_y=args.gap_y or 0}
        for s = 1, args.per_page do
            local index = (p - 1) * args.per_page + s
            if index <= n then
                args.render(slots[s], args.items[index], index)
            end
        end
    end

    ---@class mimic_paginator
    local pgn = { page_count = page_count, element = container }
    local cur = 1
    local indicator

    local function refresh()
        if indicator then indicator.set_value(cur .. " / " .. page_count) end
    end

    -- Go to a page (clamped to a valid range).
    ---@param p integer
    function pgn.page(p)
        p = math.max(1, math.min(page_count, math.floor(p)))
        cur = p
        pane.set_value(p)
        refresh()
    end

    function pgn.next() pgn.page(cur + 1) end
    function pgn.prev() pgn.page(cur - 1) end
    function pgn.current() return cur end

    -- nav row: [< PREV]  "p / n"  [NEXT >]
    if nav then
        local nav_y = args.height
        PushButton{parent=container, x=1, y=nav_y, text="< PREV", min_width=8,
                   fg_bg=style_m.wh_gray, active_fg_bg=core.cpair(colors.black, accent),
                   callback=pgn.prev}
        PushButton{parent=container, x=total_w - 7, y=nav_y, text="NEXT >", min_width=8,
                   fg_bg=style_m.wh_gray, active_fg_bg=core.cpair(colors.black, accent),
                   callback=pgn.next}
        indicator = TextBox{parent=container, x=10, y=nav_y, width=total_w - 18,
                            text="1 / " .. page_count, alignment=core.ALIGN.CENTER,
                            fg_bg=style_m.label}
    end

    return pgn
end
