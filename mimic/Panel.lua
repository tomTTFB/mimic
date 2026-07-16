--
-- mimic - Panel
--
-- A titled, bordered box. The signature look of a SCADA dashboard, and the most
-- repeated hand-built idiom in cc-mek-scada (29 occurrences), where it is two
-- elements whose x and width must be kept in sync by hand:
--
--     TextBox{parent=main,text="RPS",fg_bg=cpair(colors.black,colors.cyan),
--             alignment=ALIGN.CENTER,width=33,x=46,y=8}
--     local rps = Rectangle{parent=main,border=border(1,colors.cyan,true),
--                           thin=true,width=33,height=12,x=46,y=9}
--
-- Here that is:
--
--     local rps = mimic.Panel{parent=main,x=46,y=8,width=33,height=13,
--                             title="RPS",accent=colors.cyan}
--
-- Returns the content area, so children parent straight to it.
--

local core     = require("graphics.core")

local elements = require("mimic.elements")
local style    = require("mimic.style")

local cpair  = core.cpair
local border = core.border

---@class panel_args
---@field title? string title text; omit for a bordered box with no title bar
---@field accent? color border and title bar color, defaults to gray
---@field title_fg? color title text color, defaults to black
---@field align? ALIGN title alignment, centered by default
---@field parent graphics_element
---@field ps? psil data source for this subtree
---@field x? integer
---@field y? integer
---@field width? integer
---@field height? integer total height, title bar included
---@field fg_bg? cpair content colors, defaults to the theme root
---@field hidden? boolean

-- Create a titled, bordered panel.
---@nodiscard
---@param args panel_args
---@return graphics_element content, graphics_element|nil title the content area, and the title bar
return function (args)
    local accent = args.accent or colors.gray
    local has_title = args.title ~= nil

    if args.width == nil then error("mimic: Panel{width=} is required", 0) end
    if args.height == nil then error("mimic: Panel{height=} is required", 0) end

    -- the title bar occupies one row of the total height
    local body_h = args.height - (has_title and 1 or 0)
    if body_h < 3 then
        error("mimic: Panel{height=" .. args.height .. "} is too small; " ..
              "needs at least " .. (has_title and 4 or 3) .. " for a border and one row of content", 0)
    end

    local title_elem

    if has_title then
        title_elem = elements.TextBox{
            parent = args.parent,
            text = args.title,
            x = args.x,
            y = args.y,
            width = args.width,
            height = 1,
            alignment = args.align or core.ALIGN.CENTER,
            fg_bg = cpair(args.title_fg or colors.black, accent),
            hidden = args.hidden
        }
    end

    -- the bordered body sits directly below the title, sharing its x and width;
    -- keeping those in sync is the whole point of this element
    local body = elements.Rectangle{
        parent = args.parent,
        ps = args.ps,
        x = args.x,
        y = args.y and (args.y + (has_title and 1 or 0)),
        width = args.width,
        height = body_h,
        border = border(1, accent, true),
        thin = true,
        fg_bg = args.fg_bg or style.root,
        hidden = args.hidden
    }

    -- Return a Div filling the border's interior rather than the Rectangle itself.
    --
    -- A bordered Rectangle's get_width()/get_height() report the OUTER frame, while
    -- children are placed inside a smaller content window. Handing back the Rectangle
    -- means callers ask "how much room do I have?" and get an answer two rows too big,
    -- then silently overflow. A Div inherits the interior, so its dimensions are the
    -- ones you can actually build against.
    local content = elements.Div{parent=body}

    return content, title_elem
end
