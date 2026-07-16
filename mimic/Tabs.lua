--
-- mimic - Tabs
--
-- A tab bar over a stack of pages, which is how the cc-mek-scada front panels do
-- multi-page displays (see supervisor.png). Upstream that is four separate things
-- kept in sync by hand: a Div per page with all but the first hidden, a table of
-- panes in the same order, a MultiPane over them, and a TabBar whose callback
-- drives the pane:
--
--     local main_page = Div{parent=page_div,y=1}
--     local plc_page  = Div{parent=page_div,y=1,hidden=true}
--     local panes = { main_page, plc_page }
--     local page_pane = MultiPane{parent=page_div,y=1,panes=panes}
--     TabBar{parent=panel,y=2,tabs={{name="SVR",color=c},{name="PLC",color=c}},
--            callback=page_pane.set_value}
--
-- Here that is:
--
--     local pages = mimic.Tabs{parent=panel,y=2,tabs={{name="SVR"},{name="PLC"}}}
--     -- build into pages[1] and pages[2]
--
-- Add a tab and you edit one list instead of four.
--

local core     = require("graphics.core")

local elements = require("mimic.elements")
local style_m  = require("mimic.style")

---@class tab_entry
---@field name string tab label
---@field color? cpair tab colors, defaults to the theme's panel text

---@class tabs_args
---@field tabs tab_entry[] the tabs, in page order
---@field parent graphics_element
---@field ps? psil data source for every page
---@field min_width? integer per-tab width
---@field callback? function called with the page index when the tab changes
---@field x? integer
---@field y? integer bar row; pages start on the next row
---@field width? integer
---@field fg_bg? cpair tab bar colors
---@field page_height? integer page height, defaults to the rest of the parent

-- Create a tab bar with a page per tab.
---@nodiscard
---@param args tabs_args
---@return table pages, graphics_element bar, graphics_element pane
---        pages indexed by tab order and also by tab name
return function (args)
    if type(args.tabs) ~= "table" or #args.tabs == 0 then
        error("mimic: Tabs{tabs=} is required and must be a non-empty table", 0)
    end

    for i = 1, #args.tabs do
        if args.tabs[i].name == nil then
            error("mimic: Tabs tab " .. i .. " has no name", 0)
        end
    end

    local bar_y = args.y or 1

    -- pages live below the bar and fill what is left of the parent
    local page_y = bar_y + 1
    local page_h = args.page_height or (args.parent.get_height() - page_y + 1)

    if page_h < 1 then
        error("mimic: Tabs at y=" .. bar_y .. " leaves no room for pages in a " ..
              args.parent.get_height() .. "-row parent", 0)
    end

    local pages = {}
    local panes = {}

    for i = 1, #args.tabs do
        -- every page but the first starts hidden; MultiPane takes over from there
        local page = elements.Div{parent=args.parent,ps=args.ps,x=args.x,y=page_y,
                                  width=args.width,height=page_h,hidden=(i > 1)}
        pages[i] = page
        pages[args.tabs[i].name] = page
        panes[i] = page
    end

    local pane = elements.MultiPane{parent=args.parent,x=args.x,y=page_y,
                                    width=args.width,height=page_h,panes=panes}

    -- TabBar requires a color per tab; default it rather than making callers repeat it
    local tab_defs = {}
    for i = 1, #args.tabs do
        tab_defs[i] = {
            name = args.tabs[i].name,
            color = args.tabs[i].color or style_m.theme.text_fg
        }
    end

    local bar = elements.TabBar{
        parent = args.parent,
        x = args.x,
        y = bar_y,
        width = args.width,
        tabs = tab_defs,
        min_width = args.min_width,
        fg_bg = args.fg_bg or style_m.theme.highlight_box_bright,
        callback = function (i)
            pane.set_value(i)
            if args.callback then args.callback(i) end
        end
    }

    return pages, bar, pane
end
