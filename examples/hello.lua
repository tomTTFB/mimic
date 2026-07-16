--
-- mimic - hello world
--
-- Run on a computer:  hello
-- Run on a monitor:   hello monitor_0
--
-- Exercises the whole stack: theming, a bordered panel, a clickable button,
-- a blinking indicator, and a live-updating readout.
--

-- leading slash: the shell's require resolves relative to this file's directory,
-- so initenv must be addressed absolutely. init_env() then re-roots require at "/"
-- for everything below.
require("/initenv").init_env()

local mimic = require("mimic")

local Rectangle      = require("graphics.elements.Rectangle")
local TextBox        = require("graphics.elements.TextBox")
local PushButton     = require("graphics.elements.controls.PushButton")
local IndicatorLight = require("graphics.elements.indicators.IndicatorLight")
local DataIndicator  = require("graphics.elements.indicators.DataIndicator")

local tcd = require("scada-common.tcd")

local monitor = ...  -- optional monitor name from the command line

local style = mimic.style

-- set up the display; palette and background are handled for you
local root = mimic.init{monitor=monitor}

-- a titled, bordered panel
-- (this hand-built title + border is exactly the idiom mimic.Panel will replace)
local box = Rectangle{parent=root,x=2,y=2,width=30,height=11,
                      border=mimic.border(1, colors.gray, true),fg_bg=style.root}

TextBox{parent=box,y=1,text="MIMIC HELLO",alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}

-- a steady light and a blinking one
local power = IndicatorLight{parent=box,x=2,y=3,label="POWER",colors=style.ind_grn}
local alarm = IndicatorLight{parent=box,x=2,y=4,label="ALARM",colors=style.ind_red,
                             flash=true,period=mimic.PERIOD.BLINK_500_MS}

power.update(true)
alarm.update(true)

-- a live readout
local uptime = DataIndicator{parent=box,x=2,y=6,label="Uptime:",unit="s",format="%7.0f",
                             value=0,width=20,fg_bg=style.text_colors,lu_colors=style.lu_colors}

-- a button that toggles the alarm
local armed = true
PushButton{parent=box,x=2,y=8,text="TOGGLE ALARM",min_width=16,
           fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
           callback=function ()
               armed = not armed
               alarm.update(armed)
           end}

-- tick the uptime readout once a second, via the same timer dispatcher
-- that drives the blinking light
local seconds = 0
local function tick()
    seconds = seconds + 1
    uptime.update(seconds)
    tcd.dispatch_unique(1.0, tick)
end
tick()

-- blocks until terminated (Ctrl+T), then restores the palette
mimic.run()
