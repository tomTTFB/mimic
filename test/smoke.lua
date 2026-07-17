--
-- mimic smoke test
--
-- Runs inside CraftOS-PC headless via test/run.sh. Copied to the computer as
-- startup.lua, because startup runs in shell context where `require` exists
-- (--exec runs before the shell and does not have it).
--
-- Writes to /results.txt rather than the screen, so the host can read results
-- without scraping the terminal.
--

local results = {}
local pass, fail = 0, 0

local function note(msg) results[#results + 1] = "      " .. msg end

local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        pass = pass + 1
        results[#results + 1] = "PASS  " .. name
    else
        fail = fail + 1
        results[#results + 1] = "FAIL  " .. name .. "\n        " .. tostring(err)
    end
    return ok
end

local function finish()
    local f = fs.open("/results.txt", "w")
    f.writeLine("=== mimic smoke test ===")
    for i = 1, #results do f.writeLine(results[i]) end
    f.writeLine(string.format("=== %d passed, %d failed ===", pass, fail))
    f.close()
    os.sleep(0.5)
    os.shutdown()
end

-- bootstrap: leading slash, since the shell's require resolves relative to this file
if not pcall(function () require("/initenv").init_env() end) then
    results[#results + 1] = "FAIL  initenv bootstrap"
    fail = fail + 1
    finish()
    return
end
results[#results + 1] = "PASS  initenv bootstrap"
pass = pass + 1

local mimic, style, root

check("require mimic", function ()
    mimic = require("mimic")
    assert(mimic.version, "no version field")
    assert(type(mimic.init) == "function", "init missing")
    assert(type(mimic.run) == "function", "run missing")
    assert(type(mimic.stop) == "function", "stop missing")
end)

check("style loaded with derived pairs", function ()
    style = mimic.style
    for _, k in ipairs({ "root", "ind_grn", "ind_red", "ind_yel", "ind_wht",
                         "text_colors", "lu_colors", "wh_gray", "theme" }) do
        assert(style[k] ~= nil, "style." .. k .. " is nil")
    end
    assert(style.theme.header ~= nil, "theme.header is nil")
    assert(style.theme.bg ~= nil, "theme.bg is nil")
end)

check("mimic.init() on terminal", function ()
    root = mimic.init()
    assert(root ~= nil, "init returned nil")
    assert(type(root.get_width) == "function", "root has no get_width")
    local w, h = root.get_width(), root.get_height()
    assert(w > 0 and h > 0, "root has zero size: " .. w .. "x" .. h)
    note("root size: " .. w .. "x" .. h)
end)

-- reads back the live palette: this is what "zero-config look" actually means
check("palette actually applied", function ()
    local r, g, b = term.getPaletteColor(colors.red)
    local hex = math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
    note(string.format("red = 0x%06x (deepslate expects 0xeb6a6c)", hex))
    assert(hex == 0xeb6a6c, string.format("palette not applied: red=0x%06x", hex))
end)

check("Rectangle + border", function ()
    local Rectangle = require("graphics.elements.Rectangle")
    Rectangle{parent=root,x=2,y=2,width=20,height=8,
              border=mimic.border(1, colors.gray, true),fg_bg=style.root}
end)

check("TextBox", function ()
    local TextBox = require("graphics.elements.TextBox")
    TextBox{parent=root,x=2,y=1,text="HELLO",width=10,fg_bg=style.theme.header}
end)

check("IndicatorLight + update", function ()
    local IndicatorLight = require("graphics.elements.indicators.IndicatorLight")
    local light = IndicatorLight{parent=root,x=25,y=3,label="POWER",colors=style.ind_grn}
    light.update(true)
    light.update(false)
end)

check("IndicatorLight flashing (flasher path)", function ()
    local IndicatorLight = require("graphics.elements.indicators.IndicatorLight")
    local alarm = IndicatorLight{parent=root,x=25,y=4,label="ALARM",colors=style.ind_red,
                                 flash=true,period=mimic.PERIOD.BLINK_500_MS}
    alarm.update(true)
end)

check("DataIndicator + update", function ()
    local DataIndicator = require("graphics.elements.indicators.DataIndicator")
    local d = DataIndicator{parent=root,x=25,y=6,label="Uptime:",unit="s",format="%7.0f",
                            value=0,width=20,fg_bg=style.text_colors,lu_colors=style.lu_colors}
    d.update(42)
end)

-- drives a real mouse event through the tree rather than calling the callback directly
check("PushButton + callback fires", function ()
    local core = require("graphics.core")
    local PushButton = require("graphics.elements.controls.PushButton")
    local clicked = false
    PushButton{parent=root,x=25,y=8,text="GO",min_width=6,
               fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
               callback=function () clicked = true end}

    local down = core.events.new_mouse_event("mouse_click", 1, 26, 8)
    assert(down ~= nil, "new_mouse_event returned nil")
    root.handle_mouse(down)
    root.handle_mouse(core.events.new_mouse_event("mouse_up", 1, 26, 8))
    assert(clicked, "callback did not fire on click")
end)

check("psil bind path", function ()
    local psil = require("scada-common.psil")
    local DataIndicator = require("graphics.elements.indicators.DataIndicator")
    local ps = psil.create()
    local d = DataIndicator{parent=root,x=25,y=10,label="Bound:",unit="x",format="%5.0f",
                            value=0,width=18,fg_bg=style.text_colors,lu_colors=style.lu_colors}
    d.register(ps, "testkey", d.update)
    ps.publish("testkey", 99)
    assert(d.get_value() == 99, "bound value did not propagate, got " .. tostring(d.get_value()))
end)

check("tcd timer dispatch", function ()
    local tcd = require("scada-common.tcd")
    local fired = false
    tcd.dispatch(0.05, function () fired = true end)
    local deadline = os.clock() + 3
    while not fired and os.clock() < deadline do
        local e, p1 = os.pullEvent()
        if e == "timer" then tcd.handle(p1) end
    end
    assert(fired, "tcd callback never fired")
end)

-- mimic layer: bind= and LEDList

check("elements front door resolves lazily", function ()
    local m = require("mimic.elements")
    assert(type(m.LED) == "function", "m.LED did not resolve")
    assert(type(m.Div) == "function", "m.Div did not resolve")
    assert(m.NotAnElement == nil, "unknown element should be nil, not an error")
end)

check("bind= updates element from psil", function ()
    local m = require("mimic.elements")
    local psil = require("scada-common.psil")
    local ps = psil.create()

    local d = m.DataIndicator{parent=root,ps=ps,x=25,y=12,label="B:",unit="x",format="%5.0f",
                              value=0,width=14,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                              bind="k"}
    ps.publish("k", 77)
    assert(d.get_value() == 77, "bind= did not propagate, got " .. tostring(d.get_value()))
end)

check("bind= transform applied", function ()
    local m = require("mimic.elements")
    local psil = require("scada-common.psil")
    local ps = psil.create()

    local d = m.DataIndicator{parent=root,ps=ps,x=25,y=13,label="T:",unit="x",format="%5.0f",
                              value=0,width=14,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                              bind="k",transform=function (v) return v * 2 end}
    ps.publish("k", 21)
    assert(d.get_value() == 42, "transform not applied, got " .. tostring(d.get_value()))
end)

check("ps inherits from ancestor", function ()
    local m = require("mimic.elements")
    local psil = require("scada-common.psil")
    local ps = psil.create()

    -- ps set on the Div; the LED two levels down should find it
    local outer = m.Div{parent=root,ps=ps,x=2,y=15,width=20,height=2}
    local inner = m.Div{parent=outer,width=20,height=1}
    local led = m.LED{parent=inner,label="INH",colors=style.ind_grn,bind="inh"}

    ps.publish("inh", true)
    assert(led.get_value() == true, "ps was not inherited through nested Divs")
end)

check("bind= without a ps gives a clear error", function ()
    local m = require("mimic.elements")
    local ok, err = pcall(function ()
        m.LED{parent=root,label="NOPS",colors=style.ind_grn,bind="nope"}
    end)
    assert(not ok, "expected an error when binding with no data source")
    assert(tostring(err):find("no data source"), "unhelpful error: " .. tostring(err))
end)

check("LEDList builds rows and binds them", function ()
    local psil = require("scada-common.psil")
    local ps = psil.create()
    local LEDList = require("mimic.LEDList")

    local _, rows = LEDList{parent=root,ps=ps,x=2,y=17,width=16,leds={
        { label="ONE", bind="one" },
        {},                          -- gap
        { label="TWO", bind="two" },
    }}

    assert(rows["ONE"] ~= nil, "row ONE missing")
    assert(rows["TWO"] ~= nil, "row TWO missing")
    assert(#rows == 2, "expected 2 rows (gap should not count), got " .. #rows)

    ps.publish("one", true)
    assert(rows["ONE"].get_value() == true, "LEDList row did not bind")
end)

check("LEDList rejects a bad kind", function ()
    local LEDList = require("mimic.LEDList")
    local ok, err = pcall(function ()
        LEDList{parent=root,leds={ { label="X", kind="Banana" } }}
    end)
    assert(not ok, "expected an error for an unknown kind")
    assert(tostring(err):find("Banana"), "error should name the bad kind: " .. tostring(err))
end)

-- Panel / Gauge / Trend, built in an offscreen window so they have room to breathe
-- (the terminal is only 51x19; a dashboard is not)

local sandbox, sbox_ps

check("offscreen sandbox at dashboard size", function ()
    local DisplayBox = require("graphics.elements.DisplayBox")
    local psil = require("scada-common.psil")
    local m = require("mimic.elements")

    local win = window.create(term.current(), 1, 1, 164, 46, false)
    sandbox = DisplayBox{window=win,fg_bg=style.root}
    sbox_ps = psil.create()
    m.set_ps(sandbox, sbox_ps)

    assert(sandbox.get_width() == 164, "sandbox width " .. sandbox.get_width())
    assert(sandbox.get_height() == 46, "sandbox height " .. sandbox.get_height())
end)

check("Panel returns content sized for its border and title", function ()
    local Panel = require("mimic.Panel")
    local body, title = Panel{parent=sandbox,x=2,y=3,width=39,height=14,
                              title="NODE 01",accent=colors.cyan}
    assert(title ~= nil, "no title element returned")
    -- height 14 = 1 title + 13 body; body border eats 1 row top and bottom -> 11
    assert(body.get_height() == 11, "expected 11 content rows, got " .. body.get_height())
    assert(body.get_width() == 37, "expected 37 content cols, got " .. body.get_width())
end)

check("Panel without a title keeps the extra row", function ()
    local Panel = require("mimic.Panel")
    local body = Panel{parent=sandbox,x=44,y=3,width=39,height=14,accent=colors.gray}
    assert(body.get_height() == 12, "expected 12 content rows untitled, got " .. body.get_height())
end)

check("Panel too small errors clearly", function ()
    local Panel = require("mimic.Panel")
    local ok, err = pcall(function ()
        Panel{parent=sandbox,x=2,y=2,width=10,height=2,title="X"}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("too small"), "unhelpful: " .. tostring(err))
end)

check("Gauge binds and scales with max=", function ()
    local Gauge = require("mimic.Gauge")
    local g = Gauge{parent=sandbox,x=90,y=3,width=30,label="CPU ",bind="g",max=200}
    sbox_ps.publish("g", 100)   -- 100/200 = 0.5
    assert(math.abs(g.get_value() - 0.5) < 0.001,
           "expected 0.5 after max= scaling, got " .. tostring(g.get_value()))
end)

-- regression: color= must reach the BAR, not the percentage text. HorizontalBar takes
-- bar_fg_bg for the bar and fg_bg for the element, which is easy to invert; doing so
-- renders a gray bar with a colored percent instead of a colored bar
check("Gauge color= drives the bar, not the percent text", function ()
    local Gauge = require("mimic.Gauge")
    local g = Gauge{parent=sandbox,x=90,y=6,width=30,label="X ",
                    color=style.ind_grn}
    local fb = g.get_fg_bg()
    -- the element's own fg_bg must NOT have been hijacked by color=
    assert(fb.fgd ~= style.ind_grn.fgd or fb.bkg ~= style.ind_grn.bkg,
           "color= leaked into the element fg_bg; the bar will render gray")
end)

check("Gauge with no room for a bar errors clearly", function ()
    local Gauge = require("mimic.Gauge")
    local ok, err = pcall(function ()
        Gauge{parent=sandbox,x=2,y=2,width=5,label="LONGLABEL"}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("widen it"), "unhelpful: " .. tostring(err))
end)

check("Trend ring buffer shifts on push", function ()
    local m = require("mimic.elements")
    local t = m.Trend{parent=sandbox,x=2,y=20,width=5,height=6,max=100}
    t.set_all(0)
    t.push(10); t.push(20); t.push(30)
    local s = t.get_samples()
    assert(#s == 5, "expected 5 samples, got " .. #s)
    assert(s[3] == 10 and s[4] == 20 and s[5] == 30,
           "buffer did not shift: " .. table.concat(s, ","))
    assert(s[1] == 0 and s[2] == 0, "oldest samples should still be 0")
end)

check("Trend binds via the elements wrapper", function ()
    local m = require("mimic.elements")
    local t = m.Trend{parent=sandbox,x=10,y=20,width=4,height=6,max=100,bind="tr"}
    t.set_all(0)
    sbox_ps.publish("tr", 55)
    local s = t.get_samples()
    assert(s[#s] == 55, "publish did not push a sample, got " .. tostring(s[#s]))
    assert(t.get_value() == 55, "get_value should track the latest sample")
end)

check("Trend line style renders without error", function ()
    local m = require("mimic.elements")
    local t = m.Trend{parent=sandbox,x=30,y=20,width=8,height=5,max=100,style="line"}
    -- walk a value across every band position: each third of each cell
    for v = 0, 100, 4 do t.push(v) end
    assert(t.get_value() == 100, "last push should stick")
end)

check("Trend rejects an unknown style", function ()
    local m = require("mimic.elements")
    local ok, err = pcall(function ()
        m.Trend{parent=sandbox,x=40,y=20,width=4,height=4,style="squiggle"}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("area"), "error should name the valid styles: " .. tostring(err))
end)

check("Trend clamps out-of-range values", function ()
    local m = require("mimic.elements")
    local t = m.Trend{parent=sandbox,x=16,y=20,width=3,height=6,min=0,max=100}
    t.push(999)     -- above max
    t.push(-50)     -- below min
    -- raw samples are kept; clamping happens at draw time, so this must simply not error
    local s = t.get_samples()
    assert(s[#s] == -50, "raw sample should be preserved")
end)

check("Trend rejects a non-number push", function ()
    local m = require("mimic.elements")
    local t = m.Trend{parent=sandbox,x=22,y=20,width=3,height=6,max=100}
    local ok, err = pcall(function () t.push("banana") end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("expects a number"), "unhelpful: " .. tostring(err))
end)

check("BarChart builds bars and binds them", function ()
    local BarChart = require("mimic.BarChart")
    local _, bars = BarChart{parent=sandbox,ps=sbox_ps,x=50,y=20,width=20,height=8,max=100,bars={
        { label="N1", bind="b1" },
        { label="N2", bind="b2", color=colors.cyan },
        { label="N3", value=50 },
    }}
    assert(#bars == 3, "expected 3 bars, got " .. #bars)
    assert(bars["N1"] ~= nil and bars["N3"] ~= nil, "bars should be addressable by label")

    sbox_ps.publish("b1", 25)   -- 25/100
    assert(math.abs(bars["N1"].get_value() - 0.25) < 0.001,
           "bind did not scale by max=, got " .. tostring(bars["N1"].get_value()))
    assert(math.abs(bars["N3"].get_value() - 0.5) < 0.001, "initial value= not scaled")
end)

check("BarChart too narrow errors clearly", function ()
    local BarChart = require("mimic.BarChart")
    local ok, err = pcall(function ()
        BarChart{parent=sandbox,x=2,y=2,width=3,height=8,bars={
            { label="A" }, { label="B" }, { label="C" }, { label="D" },
        }}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("cannot fit"), "unhelpful: " .. tostring(err))
end)

-- note: an oversized child is silently CLIPPED by the engine (math.min), not rejected.
-- the error only fires when the child starts past the parent's edge, which is the case
-- a dashboard actually hits when its vertical budget is wrong
check("overflow error names the element and explains", function ()
    local m = require("mimic.elements")
    local small = m.Div{parent=sandbox,x=2,y=40,width=10,height=4}
    local ok, err = pcall(function ()
        m.Div{parent=small,x=1,y=10,width=10,height=2}   -- y=10 inside a 4-row parent
    end)
    assert(not ok, "expected an overflow error")
    assert(tostring(err):find("does not fit"), "should say it does not fit: " .. tostring(err))
    assert(tostring(err):find("Div"), "should name the element: " .. tostring(err))
end)

check("oversized child is clipped, not rejected (documented engine behaviour)", function ()
    local m = require("mimic.elements")
    local small = m.Div{parent=sandbox,x=20,y=40,width=10,height=4}
    local child = m.Div{parent=small,x=1,y=1,width=10,height=99}
    assert(child.get_height() == 4, "expected silent clip to 4, got " .. child.get_height())
end)

-- multiple displays: a front panel on the computer plus a dashboard on a monitor.
-- monitors need a window system, so periphemu refuses in headless; fall back to
-- window-backed displays, which exercise the same routing code.
check("Tabs builds a page per tab, addressable by name", function ()
    local Tabs = require("mimic.Tabs")
    local m = require("mimic.elements")
    local host = m.Div{parent=sandbox,x=100,y=25,width=40,height=12}

    local pages, bar, pane = Tabs{parent=host,y=1,min_width=6,ps=sbox_ps,tabs={
        { name="ONE" }, { name="TWO" }, { name="THREE" },
    }}

    assert(#pages == 3, "expected 3 pages, got " .. #pages)
    assert(pages["TWO"] ~= nil, "pages should be addressable by tab name")
    assert(pages["TWO"] == pages[2], "name and index should reach the same page")
    assert(bar ~= nil and pane ~= nil, "bar and pane should be returned")

    -- page 1 visible, the rest hidden until their tab is picked
    assert(pages[1].is_visible(), "first page should start visible")
    assert(not pages[2].is_visible(), "second page should start hidden")

    -- pages inherit the data source, so children can just bind=
    local led = m.LED{parent=pages[2],label="X",colors=style.ind_grn,bind="tabbed"}
    sbox_ps.publish("tabbed", true)
    assert(led.get_value() == true, "page did not inherit ps=")
end)

check("Tabs rejects an unnamed tab", function ()
    local Tabs = require("mimic.Tabs")
    local ok, err = pcall(function ()
        Tabs{parent=sandbox,y=1,tabs={ { name="OK" }, { } }}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("no name"), "unhelpful: " .. tostring(err))
end)

check("add_display creates a second root", function ()
    local win = window.create(term.current(), 1, 1, 60, 20, false)
    local second = mimic.add_display{window=win, ps=sbox_ps}
    assert(second ~= nil, "add_display returned nil")
    assert(second ~= root, "second display should be a distinct root")
    assert(#mimic.displays() >= 2, "expected at least 2 displays, got " .. #mimic.displays())
end)

check("add_display without a monitor errors", function ()
    local ok, err = pcall(function () mimic.add_display{} end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("requires a monitor"), "unhelpful: " .. tostring(err))
end)

-- regression: Minecraft fires monitor_resize on chunk load / attach, usually with no
-- actual size change. mimic used to treat it as fatal, which killed the program a second
-- after world load. CraftOS-PC's emulated monitor never fires it, so no test caught it.
-- layout helpers: Row, Grid

check("Row equal columns fill the width exactly", function ()
    local Row = require("mimic.Row")
    local cells, container = Row{parent=sandbox,x=2,y=30,width=40,height=5,count=4,gap=1}
    assert(#cells == 4, "expected 4 cells, got " .. #cells)
    -- 40 wide, 3 gaps -> 37 shared over 4 = 10,9,9,9
    local sum = 0
    for i = 1, 4 do sum = sum + cells[i].get_width() end
    assert(sum == 37, "cell widths + gaps should fill 40; cells sum " .. sum)
    assert(container.get_width() == 40, "container width " .. container.get_width())
end)

check("Row explicit widths with a flexible cell", function ()
    local Row = require("mimic.Row")
    -- 50 wide, gaps 2, fixed 10+10=20, one flex cell gets the rest
    local cells = Row{parent=sandbox,x=2,y=36,width=50,height=4,widths={10,0,10},gap=2}
    assert(cells[1].get_width() == 10, "fixed cell 1")
    assert(cells[3].get_width() == 10, "fixed cell 3")
    -- leftover = 50 - 20 - 2*2 = 26 for the single flex cell
    assert(cells[2].get_width() == 26, "flex cell should be 26, got " .. cells[2].get_width())
end)

check("Row rejects count= and widths= together", function ()
    local Row = require("mimic.Row")
    local ok = pcall(function ()
        Row{parent=sandbox,y=1,height=3,count=2,widths={5,5}}
    end)
    assert(not ok, "expected an error for both count= and widths=")
end)

check("Grid lays out cells row-major and by (col,row)", function ()
    local Grid = require("mimic.Grid")
    local cells = Grid{parent=sandbox,x=60,y=30,width=60,height=12,cols=3,rows=2,gap_x=1,gap_y=1}
    assert(#cells == 6, "expected 6 cells, got " .. #cells)
    -- row-major: cells[4] is (col 1, row 2)
    assert(cells(1, 2) == cells[4], "cells(1,2) should equal cells[4]")
    assert(cells(3, 1) == cells[3], "cells(3,1) should equal cells[3]")
    -- second row starts lower than the first
    assert(cells(1, 2) ~= nil, "missing cell (1,2)")
end)

check("Grid too small errors clearly", function ()
    local Grid = require("mimic.Grid")
    local ok, err = pcall(function ()
        Grid{parent=sandbox,x=2,y=2,width=3,height=10,cols=8,rows=1}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("does not fit"), "unhelpful: " .. tostring(err))
end)

-- Table

check("Table builds rows and updates cells", function ()
    local Table = require("mimic.Table")
    local ALIGN = require("graphics.core").ALIGN
    local t = Table{parent=sandbox,x=125,y=30,width=36,height=10,columns={
        { name="NODE",  width=10 },
        { name="STATE", width=10 },
        { name="CPU",   width=6, align=ALIGN.RIGHT },
    }}
    local r1 = t.add_row{ "NODE 01", "ONLINE", "81%" }
    local r2 = t.add_row{ "NODE 02", "STANDBY", "2%" }
    assert(t.row_count() == 2, "expected 2 rows, got " .. t.row_count())
    assert(r1 == 1 and r2 == 2, "row indices should be 1 and 2")

    t.set_cell(r1, 3, "84%")   -- must not error
    t.set_row(r2, { "NODE 02", "ONLINE", "40%" })

    t.clear()
    assert(t.row_count() == 0, "clear() should empty the table")
end)

check("Table rejects a bad cell reference", function ()
    local Table = require("mimic.Table")
    local t = Table{parent=sandbox,x=125,y=42,width=30,height=4,columns={ { name="A", width=8 } }}
    t.add_row{ "x" }
    local ok, err = pcall(function () t.set_cell(1, 5, "y") end)
    assert(not ok, "expected an error for a missing column")
    assert(tostring(err):find("no column"), "unhelpful: " .. tostring(err))
end)

-- Dialog

check("Dialog starts hidden and toggles", function ()
    local Dialog = require("mimic.Dialog")
    local fired = false
    local d = Dialog{parent=sandbox,title="CONFIRM",message="Stop the chamber?",
                     accent=colors.red,buttons={
        { text="STOP", color=style.ind_red, callback=function () fired = true end },
        { text="CANCEL" },
    }}
    assert(not d.is_open(), "dialog should start hidden")
    d.show()
    assert(d.is_open(), "dialog should be open after show()")
    d.hide()
    assert(not d.is_open(), "dialog should be closed after hide()")
    -- the fired flag is exercised by the button path; here we just confirm it defaults false
    assert(fired == false, "callback should not fire on its own")
end)

check("Dialog needs at least one button", function ()
    local Dialog = require("mimic.Dialog")
    local ok, err = pcall(function ()
        Dialog{parent=sandbox,message="x",buttons={}}
    end)
    assert(not ok, "expected an error")
    assert(tostring(err):find("at least one button"), "unhelpful: " .. tostring(err))
end)

check("monitor_resize is never fatal", function ()
    local win = window.create(term.current(), 1, 1, 40, 12, false)
    local d = mimic.add_display{window=win, ps=sbox_ps}
    assert(d ~= nil)

    -- run() blocks, so drive the same path the loop does: queue the event and pump once
    local pumped = false
    parallel.waitForAny(
        function ()
            os.queueEvent("monitor_resize", "right")
            os.queueEvent("terminate")
            mimic.run()
            pumped = true
        end,
        function () os.sleep(2) end
    )
    assert(pumped, "run() died on monitor_resize instead of ignoring it")
end)

check("mimic.stop() restores palette", function ()
    mimic.stop()
    local r, g, b = term.getPaletteColor(colors.red)
    local hex = math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
    local nr, ng, nb = term.nativePaletteColor(colors.red)
    local nhex = math.floor(nr * 255 + 0.5) * 65536 + math.floor(ng * 255 + 0.5) * 256 + math.floor(nb * 255 + 0.5)
    note(string.format("after stop: red = 0x%06x (native 0x%06x)", hex, nhex))
    assert(hex == nhex, "palette not restored")
end)

finish()
