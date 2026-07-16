--
-- mimic - device front panel
--
-- A status panel in the style of an industrial controller front panel:
-- LED rows, a fault box, control buttons, and a firmware block.
--
-- Run:  front_panel
--
-- NOTE: written deliberately with bare elements and no mimic helpers, to
-- establish what the helpers actually need to fix. See PLAN-v2.md stage 3.
--

require("/initenv").init_env()

local mimic = require("mimic")

local Div        = require("graphics.elements.Div")
local Rectangle  = require("graphics.elements.Rectangle")
local TextBox    = require("graphics.elements.TextBox")
local PushButton = require("graphics.elements.controls.PushButton")
local LED        = require("graphics.elements.indicators.LED")

local psil = require("scada-common.psil")
local tcd  = require("scada-common.tcd")

local style = mimic.style

local root = mimic.init()

-- a fake data bus, standing in for whatever you're actually monitoring
local ps = psil.create()

local ind_grn = style.ind_grn
local ind_red = style.ind_red
local ind_wht = style.ind_wht

-- header
TextBox{parent=root,y=1,text="MIMIC DEVICE CONTROLLER - NODE 1",
        alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}

--
-- left column: system LEDs
--

local system = Div{parent=root,x=2,y=3,width=16,height=15}

local status    = LED{parent=system,label="STATUS",colors=ind_grn}
local heartbeat = LED{parent=system,label="HEARTBEAT",colors=ind_grn}
local auto_ctl  = LED{parent=system,label="AUTO CONTROL",colors=ind_grn}

status.register(ps, "status", status.update)
heartbeat.register(ps, "heartbeat", heartbeat.update)
auto_ctl.register(ps, "auto_ctl", auto_ctl.update)

system.line_break()

local power   = LED{parent=system,label="POWER",colors=ind_grn}
local modem   = LED{parent=system,label="MODEM",colors=ind_grn}
local network = LED{parent=system,label="NETWORK",colors=ind_grn}

power.register(ps, "power", power.update)
modem.register(ps, "modem", modem.update)
network.register(ps, "network", network.update)

system.line_break()

local rt_main  = LED{parent=system,label="RT MAIN",colors=ind_grn}
local rt_comms = LED{parent=system,label="RT COMMS",colors=ind_grn}

rt_main.register(ps, "rt_main", rt_main.update)
rt_comms.register(ps, "rt_comms", rt_comms.update)

--
-- middle column: state, fault, controls, firmware
--

local middle = Div{parent=root,x=19,y=3,width=17,height=15}

local online = LED{parent=middle,label="DEVICE ONLINE",colors=ind_grn}
online.register(ps, "online", online.update)

middle.line_break()

-- fault callout, on a highlight background
local fault_box = Rectangle{parent=middle,y=3,width=17,height=3,
                            fg_bg=style.theme.highlight_box}
local fault = LED{parent=fault_box,x=2,y=2,label="FAULT TRIP",colors=ind_red,
                  flash=true,period=mimic.PERIOD.BLINK_500_MS}
fault.register(ps, "fault", fault.update)

-- controls
local faulted = false
PushButton{parent=middle,x=1,y=7,text="RESET",min_width=8,
           fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
           callback=function ()
               faulted = false
               ps.publish("fault", false)
           end}

PushButton{parent=middle,x=10,y=7,text="TRIP",min_width=7,
           fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
           callback=function ()
               faulted = true
               ps.publish("fault", true)
           end}

-- firmware block
local fw_box = Rectangle{parent=middle,y=9,width=17,height=5,
                         fg_bg=style.theme.highlight_box}
-- no fg_bg needed: children inherit the parent's colors automatically
TextBox{parent=fw_box,x=2,y=1,text="FW v" .. mimic.version,width=14}
TextBox{parent=fw_box,x=2,y=2,text="NT v1.0.0",width=14}
TextBox{parent=fw_box,x=2,y=3,text="SN 001-DEV",width=14}

--
-- right column: fault conditions
--

local faults = Rectangle{parent=root,x=37,y=3,width=14,height=15,
                         fg_bg=style.theme.highlight_box}

local manual = LED{parent=faults,x=2,y=1,label="MANUAL",colors=ind_wht}
local autom  = LED{parent=faults,x=2,y=2,label="AUTOMATIC",colors=ind_wht}

manual.register(ps, "manual", manual.update)
autom.register(ps, "automatic", autom.update)

local timeout = LED{parent=faults,x=2,y=4,label="TIMEOUT",colors=ind_red}
timeout.register(ps, "timeout", timeout.update)

local dev_fault = LED{parent=faults,x=2,y=6,label="DEV FAULT",colors=ind_red}
local net_fault = LED{parent=faults,x=2,y=7,label="NET FAULT",colors=ind_red}

dev_fault.register(ps, "dev_fault", dev_fault.update)
net_fault.register(ps, "net_fault", net_fault.update)

local hi_temp = LED{parent=faults,x=2,y=9,label="HI TEMP",colors=ind_red}
local hi_load = LED{parent=faults,x=2,y=10,label="HI LOAD",colors=ind_red}
local lo_disk = LED{parent=faults,x=2,y=11,label="LO DISK",colors=ind_red}

hi_temp.register(ps, "hi_temp", hi_temp.update)
hi_load.register(ps, "hi_load", hi_load.update)
lo_disk.register(ps, "lo_disk", lo_disk.update)

--
-- drive it with fake data
--

ps.publish("status", true)
ps.publish("power", true)
ps.publish("modem", true)
ps.publish("network", true)
ps.publish("rt_main", true)
ps.publish("rt_comms", true)
ps.publish("online", true)
ps.publish("auto_ctl", true)
ps.publish("automatic", true)
ps.publish("hi_load", true)

local beat = false
local function heartbeat_tick()
    beat = not beat
    ps.publish("heartbeat", beat)
    tcd.dispatch_unique(1.0, heartbeat_tick)
end
heartbeat_tick()

mimic.run()
