--
-- mimic - device front panel (using mimic helpers)
--
-- The same panel as front_panel.lua, rebuilt with bind= and LEDList.
-- Kept side by side deliberately: the pair is the evidence that the helpers
-- earn their place. See stage3-findings.md.
--
-- Run:  front_panel2
--

require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local psil = require("scada-common.psil")
local tcd  = require("scada-common.tcd")

local style = mimic.style

-- the data source, declared once and inherited by every element below
local ps = psil.create()

local root = mimic.init{ps=ps}

-- header
m.TextBox{parent=root,y=1,text="MIMIC DEVICE CONTROLLER - NODE 1",
          alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}

-- left column: system LEDs. no locals, no register() calls, nothing to keep in sync
mimic.LEDList{parent=root,x=2,y=3,width=16,leds={
    { label="STATUS",       bind="status" },
    { label="HEARTBEAT",    bind="heartbeat" },
    { label="AUTO CONTROL", bind="auto_ctl" },
    {},
    { label="POWER",        bind="power" },
    { label="MODEM",        bind="modem" },
    { label="NETWORK",      bind="network" },
    {},
    { label="RT MAIN",      bind="rt_main" },
    { label="RT COMMS",     bind="rt_comms" },
}}

-- middle column
local middle = m.Div{parent=root,x=19,y=3,width=17,height=15}

m.LED{parent=middle,label="DEVICE ONLINE",colors=style.ind_grn,bind="online"}

local fault_box = m.Rectangle{parent=middle,y=3,width=17,height=3,fg_bg=style.theme.highlight_box}
m.LED{parent=fault_box,x=2,y=2,label="FAULT TRIP",colors=style.ind_red,
      flash=true,period=mimic.PERIOD.BLINK_500_MS,bind="fault"}

m.PushButton{parent=middle,x=1,y=7,text="RESET",min_width=8,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
             callback=function () ps.publish("fault", false) end}

m.PushButton{parent=middle,x=10,y=7,text="TRIP",min_width=7,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
             callback=function () ps.publish("fault", true) end}

local fw_box = m.Rectangle{parent=middle,y=9,width=17,height=5,fg_bg=style.theme.highlight_box}
m.TextBox{parent=fw_box,x=2,y=1,text="FW v" .. mimic.version,width=14}
m.TextBox{parent=fw_box,x=2,y=2,text="NT v1.0.0",width=14}
m.TextBox{parent=fw_box,x=2,y=3,text="SN 001-DEV",width=14}

-- right column: fault conditions
local faults = m.Rectangle{parent=root,x=37,y=3,width=14,height=15,fg_bg=style.theme.highlight_box}

mimic.LEDList{parent=faults,x=2,y=1,width=12,color=style.ind_red,leds={
    { label="MANUAL",    bind="manual",    color=style.ind_wht },
    { label="AUTOMATIC", bind="automatic", color=style.ind_wht },
    {},
    { label="TIMEOUT",   bind="timeout" },
    {},
    { label="DEV FAULT", bind="dev_fault" },
    { label="NET FAULT", bind="net_fault" },
    {},
    { label="HI TEMP",   bind="hi_temp" },
    { label="HI LOAD",   bind="hi_load" },
    { label="LO DISK",   bind="lo_disk" },
}}

-- drive it with fake data
for _, k in ipairs({ "status", "power", "modem", "network", "rt_main", "rt_comms",
                     "online", "auto_ctl", "automatic", "hi_load" }) do
    ps.publish(k, true)
end

local beat = false
local function heartbeat_tick()
    beat = not beat
    ps.publish("heartbeat", beat)
    tcd.dispatch_unique(1.0, heartbeat_tick)
end
heartbeat_tick()

mimic.run()
