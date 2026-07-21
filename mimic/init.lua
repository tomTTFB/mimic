--
-- mimic - a ComputerCraft GUI library for monitoring dashboards
--
-- Built on the graphics module from cc-mek-scada by Mikayla Fischler (MIT).
-- See THIRD_PARTY_NOTICES.md.
--

local core       = require("graphics.core")
local flasher    = require("graphics.flasher")
local themes     = require("graphics.themes")

local DisplayBox = require("graphics.elements.DisplayBox")

local tcd        = require("scada-common.tcd")
local util       = require("scada-common.util")

local style      = require("mimic.style")
local elements   = require("mimic.elements")

---@class mimic
local mimic = {}

mimic.version = "0.1.0"

-- re-exports, so callers never need to require the vendored modules directly
mimic.style      = style
mimic.elements   = elements
mimic.LEDList    = require("mimic.LEDList")
mimic.Panel      = require("mimic.Panel")
mimic.Tabs       = require("mimic.Tabs")
mimic.Gauge      = require("mimic.Gauge")
mimic.BarChart   = require("mimic.BarChart")
mimic.Row        = require("mimic.Row")
mimic.Grid       = require("mimic.Grid")
mimic.Table      = require("mimic.Table")
mimic.Dialog     = require("mimic.Dialog")
mimic.Paginator  = require("mimic.Paginator")
-- via the elements table, so it picks up bind=/ps= handling like the vendored elements
mimic.Trend      = elements.Trend
mimic.cpair      = core.cpair
mimic.border     = core.border
mimic.gframe     = core.gframe
mimic.pipe       = core.pipe
mimic.ALIGN      = core.ALIGN
mimic.THEME      = themes.UI_THEME
mimic.COLOR_MODE = themes.COLOR_MODE
mimic.PERIOD     = flasher.PERIOD

-- theme configuration
mimic.register_theme = style.register_theme   -- register_theme(name, def)
mimic.make_theme     = style.make_theme       -- make_theme(def) -> full theme table
mimic.themes         = style.themes           -- the name -> theme registry

-- where theme preferences are persisted; change before init if you want another path
mimic.prefs_path = "/.mimic-prefs"

-- Save the chosen theme + color mode so it survives a restart.
---@param theme string theme name
---@param color_mode? COLOR_MODE assistive color mode, defaults to standard
function mimic.save_prefs(theme, color_mode)
    if type(theme) ~= "string" then
        error("mimic: save_prefs expects a theme NAME (string) so it can be reloaded", 0)
    end
    local f = fs.open(mimic.prefs_path, "w")
    if f == nil then error("mimic: cannot write prefs to " .. mimic.prefs_path, 0) end
    f.write(textutils.serialize({ theme = theme, color_mode = color_mode or mimic.COLOR_MODE.STANDARD }))
    f.close()
end

-- Load saved theme prefs, if any.
---@return { theme: string, color_mode: integer }|nil
function mimic.load_prefs()
    if not fs.exists(mimic.prefs_path) then return nil end
    local f = fs.open(mimic.prefs_path, "r")
    if f == nil then return nil end
    local data = f.readAll()
    f.close()
    local ok, prefs = pcall(textutils.unserialize, data)
    if not ok or type(prefs) ~= "table" or type(prefs.theme) ~= "string" then return nil end
    return prefs
end

-- active session state
--
-- A real setup has more than one screen: a front panel on the computer's own
-- terminal and a dashboard on a monitor array, the way cc-mek-scada's coordinator
-- does it. Each entry is one display; run() routes events to the right one.
local self = {
    displays = {},  ---@type { root: graphics_element, target: table, palette: table, monitor: string|nil }[]
    root = nil,     ---@type graphics_element|nil  the first display, for the common single-screen case
    running = false
}

--#region PRIVATE

-- apply a theme's palette to a terminal/monitor, then layer assistive overrides on top
local function apply_palette(target, theme, color_mode)
    for i = 1, #theme.colors do
        target.setPaletteColor(theme.colors[i].c, theme.colors[i].hex)
    end

    local overrides = theme.color_modes[color_mode]
    if overrides then
        for i = 1, #overrides do
            target.setPaletteColor(overrides[i].c, overrides[i].hex)
        end
    end
end

-- the display attached to a given monitor peripheral
local function display_for_monitor(name)
    for i = 1, #self.displays do
        if self.displays[i].monitor == name then return self.displays[i] end
    end
end

-- the display on the computer's own screen (not a monitor, not an offscreen window)
local function terminal_display()
    for i = 1, #self.displays do
        if self.displays[i].is_terminal then return self.displays[i] end
    end
end

-- put a terminal/monitor's palette back to CC defaults
-- the native palette is read from term rather than the target: the defaults are identical
-- for terminals and monitors, and term.nativePaletteColor is always available
local function restore_palette(target, theme)
    for i = 1, #theme.colors do
        local r, g, b = term.nativePaletteColor(theme.colors[i].c)
        target.setPaletteColor(theme.colors[i].c, r, g, b)
    end
end

--#endregion

--#region PUBLIC

---@class mimic_init_opts
---@field monitor? string monitor peripheral name; the computer terminal if omitted
---@field theme? any theme name ("deepslate"/"smooth_stone"/registered), a theme table,
---       or a mimic.THEME.* enum. Defaults to deepslate.
---@field color_mode? COLOR_MODE assistive color mode, defaults to standard
---@field prefs? boolean load the saved theme/color_mode (see mimic.load_prefs) if present;
---       an explicit theme=/color_mode= still overrides
---@field scale? number monitor text scale, defaults to 0.5 (ignored for the terminal)
---@field ps? psil default data source, inherited by every element built under the root
---@field window? table render into this window instead of the terminal or a monitor
---@field on_resize? function called as on_resize(root, w, h) when this display's size
---       actually changes. Minecraft fires monitor_resize routinely without a real size
---       change, so mimic ignores those; only genuine changes reach you here.

-- Set up a display and return the root element to build on.
--
-- Applies the theme palette and clears the screen, so a fresh call already looks
-- correct with no styling of your own.
--
--     local mimic = require("mimic")
--     local root = mimic.init()
--
---@nodiscard
---@param opts? mimic_init_opts
---@return graphics_element root root element to parent your UI to
function mimic.init(opts)
    opts = opts or {}

    -- saved prefs fill in whatever the caller did not pass explicitly
    local saved = opts.prefs and mimic.load_prefs() or nil

    local theme_id = opts.theme or (saved and saved.theme) or mimic.THEME.DEEPSLATE
    local color_mode = opts.color_mode or (saved and saved.color_mode) or mimic.COLOR_MODE.STANDARD

    -- one screen, one display. Binding a monitor (or the terminal) twice otherwise
    -- silently creates a second display that fights over the same output and never
    -- receives touches - a silent-wrong-display trap. Fail loudly instead.
    if opts.monitor then
        if display_for_monitor(opts.monitor) then
            error(util.c("mimic: monitor '", opts.monitor, "' already has a display. ",
                  "Each monitor is bound once; use add_display for a different monitor."), 0)
        end
    elseif opts.window == nil then
        if terminal_display() then
            error("mimic: the terminal already has a display. mimic.init() binds the " ..
                  "computer's own screen once; use add_display{monitor=...} for a monitor.", 0)
        end
    end

    -- resolve the draw target
    local target
    if opts.window then
        target = opts.window
    elseif opts.monitor then
        target = peripheral.wrap(opts.monitor)
        if target == nil then
            error(util.c("mimic: no peripheral named '", opts.monitor, "'"), 0)
        elseif peripheral.getType(opts.monitor) ~= "monitor" then
            error(util.c("mimic: peripheral '", opts.monitor, "' is a ",
                         peripheral.getType(opts.monitor), ", not a monitor"), 0)
        end

        target.setTextScale(opts.scale or 0.5)
    else
        target = term.current()
    end

    style.set_theme(theme_id, color_mode)

    apply_palette(target, style.theme, color_mode)

    target.setBackgroundColor(style.theme.bg)
    target.clear()

    local root = DisplayBox{window=target,fg_bg=style.root}

    -- make the data source inheritable by everything built under this root
    if opts.ps ~= nil then elements.set_ps(root, opts.ps) end

    local dw, dh = target.getSize()

    self.displays[#self.displays + 1] = {
        root = root,
        target = target,
        palette = style.theme,
        monitor = opts.monitor,
        -- the real computer terminal (not a monitor, not an offscreen window);
        -- keyboard/terminal-mouse events route here
        is_terminal = (opts.monitor == nil and opts.window == nil),
        -- remembered so a monitor_resize can be checked rather than assumed
        width = dw,
        height = dh,
        on_resize = opts.on_resize
    }

    -- the first display is the default one for single-screen programs
    if self.root == nil then self.root = root end

    -- drives blinking for AlarmLight/IndicatorLight; self-perpetuates via the TCD,
    -- so the event loop only needs to forward timer events
    flasher.run()

    return root
end

-- Add another display, so one program can drive a front panel on the computer and a
-- dashboard on a monitor at the same time.
--
--     local panel = mimic.init()                        -- the computer's own screen
--     local board = mimic.add_display{monitor="right"}  -- the monitor array
--
-- run() routes monitor touches to the monitor that was touched, and keyboard and
-- terminal mouse events to the computer's display.
---@nodiscard
---@param opts mimic_init_opts must name a monitor
---@return graphics_element root
function mimic.add_display(opts)
    if opts == nil or (opts.monitor == nil and opts.window == nil) then
        error("mimic: add_display{monitor=\"...\"} requires a monitor name", 0)
    end
    return mimic.init(opts)
end

-- Every display created so far, first one first.
---@return graphics_element[]
function mimic.displays()
    local list = {}
    for i = 1, #self.displays do list[i] = self.displays[i].root end
    return list
end

-- Run the event loop until the program is terminated.
--
-- Dispatches mouse, keyboard, paste and timer events to the element tree, then
-- restores the palette on exit. Blocks; call after your UI is built.
---@param on_event? function optional hook: on_event(event, p1, p2, p3, p4, p5), called for every event
function mimic.run(on_event)
    if self.root == nil then
        error("mimic: run() called before init()", 0)
    end

    self.running = true

    while self.running do
        local event, p1, p2, p3, p4, p5 = util.pull_event()

        if event == "timer" then
            -- drives both tcd.dispatch callbacks and the flasher
            tcd.handle(p1)
        elseif event == "monitor_touch" then
            -- p1 is the monitor that was touched; send it only to that display,
            -- otherwise a touch on one screen would fire buttons on another
            local m_e = core.events.new_mouse_event(event, p1, p2, p3)
            if m_e then
                local d = display_for_monitor(p1)
                if d then d.root.handle_mouse(m_e) end
            end
        elseif event == "mouse_click" or event == "mouse_up" or event == "mouse_drag" or
               event == "mouse_scroll" or event == "double_click" then
            -- terminal mouse events belong to the computer's own screen
            local m_e = core.events.new_mouse_event(event, p1, p2, p3)
            local d = terminal_display()
            if m_e and d then d.root.handle_mouse(m_e) end
        elseif event == "char" or event == "key" or event == "key_up" then
            -- monitors have no keyboard, so keys go to the computer's screen
            local k_e = core.events.new_key_event(event, p1, p2)
            local d = terminal_display()
            if k_e and d then d.root.handle_key(k_e) end
        elseif event == "paste" then
            local d = terminal_display()
            if d then d.root.handle_paste(p1) end
        elseif event == "monitor_resize" then
            -- Minecraft fires this routinely: on chunk load, on attach, on redstone
            -- updates near the monitor. Usually the size has not actually changed, so
            -- never treat it as fatal - crashing here kills the program on world load.
            local d = display_for_monitor(p1)
            if d then
                local w, h = d.target.getSize()
                if w ~= d.width or h ~= d.height then
                    d.width, d.height = w, h
                    -- the element tree was built for the old size and cannot stretch
                    -- itself; hand it to the caller if they said how to rebuild
                    if d.on_resize then d.on_resize(d.root, w, h) end
                end
            end
        elseif event == "terminate" then
            self.running = false
        end

        if on_event then on_event(event, p1, p2, p3, p4, p5) end
    end

    mimic.stop()
end

-- Tear down: stop blinking, restore the palette, and clear the screen.
-- Called automatically when run() exits.
function mimic.stop()
    self.running = false

    flasher.clear()

    -- every display got a palette applied, so every one needs it put back
    for i = 1, #self.displays do
        local d = self.displays[i]
        restore_palette(d.target, d.palette)
        d.target.setBackgroundColor(colors.black)
        d.target.setTextColor(colors.white)
        d.target.clear()
        d.target.setCursorPos(1, 1)
    end

    self.displays = {}
    self.root = nil
end

--#endregion

return mimic
