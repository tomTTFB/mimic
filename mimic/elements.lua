--
-- mimic - element front door
--
-- Wraps every vendored element with two conveniences:
--
--   1. bind=   binds the element to a psil key at the point of declaration,
--              instead of a separate .register() call further down the file
--   2. ps=     sets the data source for an element and everything under it
--
-- and gives them all one require path:
--
--     local m = require("mimic.elements")
--     m.LED{parent=root,label="STATUS",bind="status"}
--
-- The vendored elements are not modified; this only wraps their constructors.
--

local elements = {}

-- module path for every vendored element, so callers never type
-- "graphics.elements.indicators.IndicatorLight"
local PATHS = {
    -- containers
    AppMultiPane      = "graphics.elements.AppMultiPane",
    ColorMap          = "graphics.elements.ColorMap",
    DisplayBox        = "graphics.elements.DisplayBox",
    Div               = "graphics.elements.Div",
    ListBox           = "graphics.elements.ListBox",
    MultiPane         = "graphics.elements.MultiPane",
    PipeNetwork       = "graphics.elements.PipeNetwork",
    Rectangle         = "graphics.elements.Rectangle",
    TextBox           = "graphics.elements.TextBox",
    Tiling            = "graphics.elements.Tiling",
    -- animations
    Waiting           = "graphics.elements.animations.Waiting",
    -- controls
    App               = "graphics.elements.controls.App",
    Checkbox          = "graphics.elements.controls.Checkbox",
    HazardButton      = "graphics.elements.controls.HazardButton",
    MultiButton       = "graphics.elements.controls.MultiButton",
    NumericSpinbox    = "graphics.elements.controls.NumericSpinbox",
    PushButton        = "graphics.elements.controls.PushButton",
    Radio2D           = "graphics.elements.controls.Radio2D",
    RadioButton       = "graphics.elements.controls.RadioButton",
    Sidebar           = "graphics.elements.controls.Sidebar",
    SwitchButton      = "graphics.elements.controls.SwitchButton",
    TabBar            = "graphics.elements.controls.TabBar",
    -- form
    NumberField       = "graphics.elements.form.NumberField",
    TextField         = "graphics.elements.form.TextField",
    -- indicators
    AlarmLight        = "graphics.elements.indicators.AlarmLight",
    DataIndicator     = "graphics.elements.indicators.DataIndicator",
    HorizontalBar     = "graphics.elements.indicators.HorizontalBar",
    IconIndicator     = "graphics.elements.indicators.IconIndicator",
    IndicatorLight    = "graphics.elements.indicators.IndicatorLight",
    LED               = "graphics.elements.indicators.LED",
    LEDPair           = "graphics.elements.indicators.LEDPair",
    PowerIndicator    = "graphics.elements.indicators.PowerIndicator",
    RGBLED            = "graphics.elements.indicators.RGBLED",
    SignalBar         = "graphics.elements.indicators.SignalBar",
    StateIndicator    = "graphics.elements.indicators.StateIndicator",
    TriIndicatorLight = "graphics.elements.indicators.TriIndicatorLight",
    VerticalBar       = "graphics.elements.indicators.VerticalBar",
    -- mimic's own elements; listed here so they get bind=/ps= like any other.
    -- Trend requires graphics.element directly, not this module, so the lazy
    -- resolve below cannot loop back on itself.
    Trend             = "mimic.Trend"
}

-- which psil each element draws from; weak keys so this never pins elements alive
local ps_of = setmetatable({}, { __mode = "k" })

-- Set the data source for an element and, by inheritance, everything created under it.
---@param elem graphics_element element to attach a psil to
---@param ps psil the data source
function elements.set_ps(elem, ps)
    ps_of[elem] = ps
end

-- Get the psil an element draws from, if any.
---@param elem graphics_element
---@return psil|nil
function elements.get_ps(elem)
    return ps_of[elem]
end

-- wrap a vendored constructor with bind=/ps= handling
local function wrap(ctor, name)
    return function (args)
        args = args or {}

        -- pull out mimic's own arguments; the vendored constructor never sees them
        local bind, transform, ps = args.bind, args.transform, args.ps
        args.bind, args.transform, args.ps = nil, nil, nil

        -- the vendored engine reports overflow as "frame height not >= 1", which says
        -- nothing about which element or why; we know both, so say so
        local ok, elem, id = pcall(ctor, args)
        if not ok then
            local msg = tostring(elem)
            if msg:find("frame height not >= 1") or msg:find("frame width not >= 1") then
                local axis = msg:find("height") and "vertically" or "horizontally"
                error("mimic: " .. name .. "{x=" .. tostring(args.x or "auto") ..
                      ",y=" .. tostring(args.y or "auto") ..
                      ",width=" .. tostring(args.width or "auto") ..
                      ",height=" .. tostring(args.height or "auto") ..
                      "} does not fit " .. axis .. " inside its parent. " ..
                      "Remember a bordered Rectangle loses 2 rows and 2 columns to its border, " ..
                      "and a Panel loses 1 more row to its title.", 0)
            end
            error(elem, 0)
        end

        -- this element's data source: its own if given, otherwise its parent's
        local src = ps or (args.parent ~= nil and ps_of[args.parent]) or nil
        if src ~= nil then ps_of[elem] = src end

        if bind ~= nil then
            if src == nil then
                error("mimic: " .. name .. "{bind=\"" .. tostring(bind) .. "\"} has no data source. " ..
                      "Pass ps= on this element or any ancestor, or via mimic.init{ps=...}.", 0)
            end

            if type(elem.update) ~= "function" then
                error("mimic: " .. name .. " cannot be bound (it has no update function)", 0)
            end

            local fn
            if transform ~= nil then
                if type(transform) ~= "function" then
                    error("mimic: " .. name .. "{transform=} must be a function", 0)
                end
                fn = function (v) elem.update(transform(v)) end
            else
                fn = elem.update
            end

            -- register() rather than ps.subscribe(), so the element unsubscribes when deleted
            elem.register(src, bind, fn)
        end

        return elem, id
    end
end

-- resolve and wrap elements on first use, so a program only loads what it touches
setmetatable(elements, {
    __index = function (t, k)
        local path = PATHS[k]
        if path == nil then return nil end
        local w = wrap(require(path), k)
        rawset(t, k, w)
        return w
    end
})

return elements
