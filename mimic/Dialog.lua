--
-- mimic - Dialog
--
-- A modal confirm/alert box, centered over the display. Needed the moment a
-- button does something you cannot undo - start/stop, purge, reset - which the
-- engine has no element for.
--
--     local d = mimic.Dialog{parent=root,title="CONFIRM",accent=colors.red,
--         message="Stop chamber 3?",
--         buttons={
--             { text="STOP",   color=mimic.style.ind_red, callback=function () stop() end },
--             { text="CANCEL" },   -- no callback: just closes
--         }}
--     d.show()   -- reveal it; each button hides it again when clicked
--
-- Build it once up front and show()/hide() it, rather than creating it on demand.
--

local core     = require("graphics.core")

local Rectangle  = require("graphics.elements.Rectangle")
local TextBox    = require("graphics.elements.TextBox")
local PushButton = require("graphics.elements.controls.PushButton")

local elements = require("mimic.elements")
local style_m  = require("mimic.style")

local cpair  = core.cpair
local border = core.border

---@class dialog_button
---@field text string button label
---@field color? cpair active color
---@field callback? function called when clicked; the dialog hides afterwards either way

---@class dialog_args
---@field parent graphics_element the root/display to center over
---@field message string body text
---@field title? string title bar text
---@field accent? color border and title color, defaults to gray
---@field width? integer defaults to 32
---@field buttons dialog_button[] one or more buttons along the bottom

-- Create a hidden modal dialog. Call show() to reveal it.
---@nodiscard
---@param args dialog_args
---@return table dialog with show(), hide(), is_open()
return function (args)
    if args.message == nil then error("mimic: Dialog{message=} is required", 0) end
    if type(args.buttons) ~= "table" or #args.buttons == 0 then
        error("mimic: Dialog{buttons=} needs at least one button", 0)
    end

    local accent = args.accent or colors.gray
    local has_title = args.title ~= nil

    local W = args.width or 32
    local pw, ph = args.parent.get_width(), args.parent.get_height()
    if W > pw - 2 then W = pw - 2 end

    -- wrap the message to know how tall the box must be
    local inner_w = W - 4
    local lines = require("scada-common.util").strwrap(args.message, inner_w)
    local msg_h = #lines

    -- box height: border(2) + title(1?) + message + spacer + buttons(1) + spacer
    local H = 2 + (has_title and 1 or 0) + msg_h + 1 + 1 + 1
    if H > ph then H = ph end

    local x = math.floor((pw - W) / 2) + 1
    local y = math.floor((ph - H) / 2) + 1

    -- hidden until shown; sits on top of whatever is already drawn
    local box = Rectangle{parent=args.parent,x=x,y=y,width=W,height=H,
                          border=border(1, accent, true),thin=true,
                          fg_bg=style_m.theme.highlight_box,hidden=true}

    local row = 1
    if has_title then
        TextBox{parent=box,x=1,y=row,width=W-2,text=args.title,
                alignment=core.ALIGN.CENTER,fg_bg=cpair(colors.black, accent)}
        row = row + 1
    end

    TextBox{parent=box,x=2,y=row,width=inner_w,height=msg_h,text=args.message,
            alignment=core.ALIGN.CENTER}
    row = row + msg_h + 1

    ---@class mimic_dialog
    local dialog = {}

    function dialog.show() box.show() end
    function dialog.hide() box.hide(true) end
    function dialog.is_open() return box.is_visible() end

    -- lay the buttons out evenly across the bottom row
    local n = #args.buttons
    local btn_w = math.floor((W - 2 - (n - 1)) / n)
    if btn_w < 3 then btn_w = 3 end
    local bx = 2
    for i = 1, n do
        local b = args.buttons[i]
        PushButton{parent=box,x=bx,y=row,text=b.text,min_width=btn_w,
                   fg_bg=style_m.wh_gray,active_fg_bg=b.color or style_m.ind_grn,
                   callback=function ()
                       dialog.hide()               -- always close
                       if b.callback then b.callback() end
                   end}
        bx = bx + btn_w + 1
    end

    return dialog
end
