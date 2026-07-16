--
-- mimic - multi-page front panel
--
-- Modelled directly on cc-mek-scada's supervisor front panel: a header, a tab bar,
-- a page per tab, and a firmware/serial box. Fits a real 51x19 computer screen.
--
--   panel_tabs
--

require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local psil = require("scada-common.psil")
local tcd  = require("scada-common.tcd")

local style = mimic.style

local ps = psil.create()
local panel = mimic.init{ps=ps}

local W, H = panel.get_width(), panel.get_height()

-- header
m.TextBox{parent=panel,y=1,text="MIMIC SUPERVISOR",
          alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}

-- tab bar + one page per tab, in a single call
local pages = mimic.Tabs{parent=panel,y=2,min_width=7,tabs={
    { name="SVR" }, { name="NODE" }, { name="NET" }, { name="INF" },
}}

--
-- SVR: system status
--

local svr = pages["SVR"]

mimic.LEDList{parent=svr,x=2,y=2,width=20,leds={
    { label="STATUS",    bind="status" },
    { label="HEARTBEAT", bind="heartbeat" },
    {},
    { label="MODEM",     bind="modem" },
    { label="NETWORK",   bind="network" },
    {},
    { label="DATA FEED", bind="feed" },
}}

-- the firmware/network/serial box every cc-mek-scada front panel carries
local hw = m.Rectangle{parent=svr,x=2,y=11,width=18,height=5,fg_bg=style.theme.highlight_box}
m.TextBox{parent=hw,x=2,y=1,width=15,text="FW v" .. mimic.version}
m.TextBox{parent=hw,x=2,y=2,width=15,text="NT v1.0.0"}
m.TextBox{parent=hw,x=2,y=3,width=15,text="SN 001-SVR"}

m.DataIndicator{parent=svr,x=24,y=2,label="Uptime:",unit="s",format="%7.0f",value=0,
                width=25,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="uptime"}
m.DataIndicator{parent=svr,x=24,y=3,label="Nodes:",unit="of 4",format="%4.0f",value=0,
                width=25,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="online"}

m.TextBox{parent=svr,x=24,y=5,width=25,text="throughput",fg_bg=style.label}
m.Trend{parent=svr,x=24,y=6,width=25,height=4,max=4000,color=colors.green,bind="rps"}

m.PushButton{parent=svr,x=24,y=11,text="RESTART",min_width=12,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_yel,
             callback=function () ps.publish("feed", false) end}
m.PushButton{parent=svr,x=38,y=11,text="RESUME",min_width=11,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
             callback=function () ps.publish("feed", true) end}

--
-- NODE: per-node link + state, the way the RTU panel lists its units
--

local node = pages["NODE"]

for i = 1, 4 do
    local y = 1 + i * 2

    m.TextBox{parent=node,x=2,y=y,width=3,text=string.format("%02d", i),fg_bg=style.label}

    m.LED{parent=node,x=6,y=y,label="LINK",colors=style.ind_grn,bind="n" .. i .. "_link"}
    m.LED{parent=node,x=17,y=y,label="LOAD",colors=style.ind_wht,bind="n" .. i .. "_busy"}

    m.StateIndicator{parent=node,x=28,y=y,min_width=10,value=1,states={
        { color=mimic.cpair(colors.black, colors.green),  text="ONLINE" },
        { color=mimic.cpair(colors.black, colors.yellow), text="DEGRADED" },
        { color=mimic.cpair(colors.white, colors.red),    text="OFFLINE" },
        { color=mimic.cpair(colors.white, colors.gray),   text="STANDBY" },
    },bind="n" .. i .. "_state"}

    m.DataIndicator{parent=node,x=40,y=y,label="",unit="%",format="%3.0f",value=0,
                    width=9,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                    bind="n" .. i .. "_cpu",transform=function (v) return v * 100 end}
end

--
-- NET: link quality
--

local net = pages["NET"]

mimic.LEDList{parent=net,x=2,y=2,width=22,leds={
    { label="WIRED MODEM",   bind="modem" },
    { label="WIRELESS MODEM", bind="modem" },
    {},
    { label="LINK UP",       bind="network" },
    { label="CONGESTION",    bind="congested", color=style.ind_yel },
}}

m.TextBox{parent=net,x=26,y=2,width=23,text="signal",fg_bg=style.label}
-- fg_bg's foreground is the "high quality" color; colors_low_med covers the rest
local sig = m.SignalBar{parent=net,x=26,y=3,
                        fg_bg=mimic.cpair(colors.green, style.ind_bkg),
                        colors_low_med=mimic.cpair(colors.red, colors.yellow)}
sig.update(4)

m.DataIndicator{parent=net,x=26,y=5,label="RTT:",unit="ms",format="%5.0f",value=0,
                width=23,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="rtt"}

--
-- INF: help text, like the supervisor's INF tab
--

local inf = pages["INF"]

m.TextBox{parent=inf,x=2,y=2,width=W-3,height=12,fg_bg=style.label,
          text="SVR \x1a Supervisor status, firmware, throughput\n" ..
               "NODE \x1a Per-node link state and load\n" ..
               "NET \x1a Modem and link quality\n\n" ..
               "This panel fits a standard " .. W .. "x" .. H .. " computer screen. " ..
               "The dashboard belongs on a monitor - run 'facility' for both at once.\n\n" ..
               "Built with mimic v" .. mimic.version .. "."}

--
-- data
--

local t, uptime, beat = 0, 0, false

local function tick()
    t = t + 1
    uptime = uptime + 1
    beat = not beat

    local total, online = 0, 0
    for i = 1, 4 do
        local st = (i == 4) and 4 or 1
        local cpu = (st == 1) and math.min(1, math.max(0.05, 0.5 + math.sin(t / 10 + i) * 0.35)) or 0.02
        ps.publish("n" .. i .. "_state", st)
        ps.publish("n" .. i .. "_cpu", cpu)
        ps.publish("n" .. i .. "_link", true)
        ps.publish("n" .. i .. "_busy", cpu > 0.6)
        if st == 1 then online = online + 1; total = total + cpu * 1000 end
    end

    ps.publish("rps", total)
    ps.publish("online", online)
    ps.publish("uptime", uptime)
    ps.publish("status", true)
    ps.publish("heartbeat", beat)
    ps.publish("modem", true)
    ps.publish("network", true)
    ps.publish("congested", total > 2600)
    ps.publish("rtt", 8 + math.sin(t / 5) * 4)

    tcd.dispatch_unique(1.0, tick)
end

ps.publish("feed", true)
tick()

mimic.run()
