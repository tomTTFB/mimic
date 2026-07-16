--
-- mimic - facility dashboard
--
-- A full-size monitoring dashboard: node panels, gauges, trends, alarms.
-- Sized for a 164x46 display (an 8x6 monitor array at 0.5 text scale).
--
--   dashboard              -- on this terminal
--   dashboard monitor_0    -- on a monitor
--

require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local psil = require("scada-common.psil")
local tcd  = require("scada-common.tcd")
local util = require("scada-common.util")

local monitor = ...

local style = mimic.style
local cpair = mimic.cpair

local ps = psil.create()
local root = mimic.init{monitor=monitor,ps=ps}

local W, H = root.get_width(), root.get_height()

if W < 100 or H < 40 then
    -- fail loudly rather than drawing a mangled screen
    m.TextBox{parent=root,x=1,y=1,width=W,height=8,
              text="dashboard needs at least 100x40.\n" ..
                   "This display is " .. W .. "x" .. H .. ".\n\n" ..
                   "Use a monitor at least 8 blocks wide (0.5 text scale),\n" ..
                   "or try 'front_panel', which fits a computer screen.",
              fg_bg=cpair(colors.red, style.theme.bg)}
    mimic.run()
    return
end

-- Real monitors come in block sizes, so the height is whatever it is (8x4 blocks at
-- 0.5 scale is 164x52, not 46). Derive the row budget instead of hardcoding it.
local NODE_Y = 3
local NODE_H = 14                       -- -> 11 content rows
local MID_Y  = NODE_Y + NODE_H + 1
local MID_H  = 14
local BOT_Y  = MID_Y + MID_H + 1
local BOT_H  = H - BOT_Y                -- fill to the bottom, leaving one row of margin

--
-- header
--

m.TextBox{parent=root,y=1,text="MIMIC FACILITY OVERVIEW",
          alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}
m.TextBox{parent=root,x=W-24,y=1,width=23,text="",alignment=mimic.ALIGN.RIGHT,
          fg_bg=style.theme.header,bind="clock"}

--
-- node panels across the top
--

local NODES = { "NODE 01", "NODE 02", "NODE 03", "NODE 04" }
local NODE_W = 40

local node_accents = { colors.cyan, colors.cyan, colors.cyan, colors.orange }

for i, name in ipairs(NODES) do
    local x = 2 + (i - 1) * NODE_W
    local p = mimic.Panel{parent=root,x=x,y=NODE_Y,width=NODE_W - 1,height=NODE_H,
                          title=name,accent=node_accents[i]}

    -- state tag
    m.StateIndicator{parent=p,x=2,y=1,min_width=16,value=1,states={
        { color = cpair(colors.black, colors.green),     text = "ONLINE" },
        { color = cpair(colors.black, colors.yellow),    text = "DEGRADED" },
        { color = cpair(colors.white, colors.red),       text = "OFFLINE" },
        { color = cpair(colors.white, colors.gray),      text = "STANDBY" },
    },bind="n" .. i .. "_state"}

    m.DataIndicator{parent=p,x=20,y=1,label="",unit="req/s",format="%6.0f",value=0,
                    width=17,fg_bg=style.theme.highlight_box,lu_colors=style.lu_colors,
                    bind="n" .. i .. "_rps"}

    -- gauges
    mimic.Gauge{parent=p,x=2,y=3,width=35,label="CPU ",bind="n" .. i .. "_cpu",
                color=cpair(colors.green, style.ind_bkg)}
    mimic.Gauge{parent=p,x=2,y=4,width=35,label="MEM ",bind="n" .. i .. "_mem",
                color=cpair(colors.lightBlue, style.ind_bkg)}
    mimic.Gauge{parent=p,x=2,y=5,width=35,label="DISK",bind="n" .. i .. "_disk",
                color=cpair(colors.purple, style.ind_bkg)}

    -- readouts
    m.DataIndicator{parent=p,x=2,y=7,label="Temp:",unit="C",format="%7.1f",value=0,
                    width=35,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                    bind="n" .. i .. "_temp"}
    m.DataIndicator{parent=p,x=2,y=8,label="Power:",unit="W",format="%6.0f",value=0,
                    width=35,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                    bind="n" .. i .. "_pwr"}

    -- per-node status lights
    mimic.LEDList{parent=p,x=2,y=10,width=35,leds={
        { label="LINK",   bind="n" .. i .. "_link" },
        { label="THERMAL", bind="n" .. i .. "_thermal", color=style.ind_red },
    }}
end

--
-- throughput trend
--

local trend_panel = mimic.Panel{parent=root,x=2,y=MID_Y,width=104,height=MID_H,
                                title="AGGREGATE THROUGHPUT",accent=colors.gray}

m.TextBox{parent=trend_panel,x=2,y=1,width=40,text="requests/sec, last 95 samples",
          fg_bg=style.label}
m.DataIndicator{parent=trend_panel,x=70,y=1,label="Now:",unit="req/s",format="%7.0f",
                value=0,width=30,fg_bg=style.theme.highlight_box,
                lu_colors=style.lu_colors,bind="total_rps"}

-- y axis gutter: the Trend element draws only the plot, so the scale is composed
-- around it rather than baked in
local RPS_MAX = 4000
m.TextBox{parent=trend_panel,x=1,y=3,width=5,text=tostring(RPS_MAX),
          alignment=mimic.ALIGN.RIGHT,fg_bg=style.label}
m.TextBox{parent=trend_panel,x=1,y=6,width=5,text=tostring(RPS_MAX / 2),
          alignment=mimic.ALIGN.RIGHT,fg_bg=style.label}
m.TextBox{parent=trend_panel,x=1,y=10,width=5,text="0",
          alignment=mimic.ALIGN.RIGHT,fg_bg=style.label}

mimic.Trend{parent=trend_panel,x=7,y=3,width=95,height=8,
            max=RPS_MAX,color=colors.green,bind="total_rps"}

--
-- alarms
--

local alarm_panel = mimic.Panel{parent=root,x=107,y=MID_Y,width=56,height=MID_H,
                                title="FACILITY ALARMS",accent=colors.red}

mimic.LEDList{parent=alarm_panel,x=2,y=1,width=25,color=style.ind_red,leds={
    { label="NODE OFFLINE",    bind="a_offline", flash=true, period=mimic.PERIOD.BLINK_500_MS },
    { label="THERMAL LIMIT",   bind="a_thermal" },
    { label="POWER FAULT",     bind="a_power" },
    { label="LINK DEGRADED",   bind="a_link", color=style.ind_yel },
    {},
    { label="DISK PRESSURE",   bind="a_disk", color=style.ind_yel },
    { label="MEM PRESSURE",    bind="a_mem", color=style.ind_yel },
}}

mimic.LEDList{parent=alarm_panel,x=29,y=1,width=25,leds={
    { label="COOLING OK",   bind="a_cooling" },
    { label="POWER OK",     bind="a_pwr_ok" },
    { label="NETWORK OK",   bind="a_net_ok" },
    { label="STORAGE OK",   bind="a_stor_ok" },
    {},
    { label="BACKUP ACTIVE", bind="a_backup", color=style.ind_wht },
    { label="MAINT MODE",    bind="a_maint", color=style.ind_wht },
}}

--
-- facility summary + controls
--

local sum = mimic.Panel{parent=root,x=2,y=BOT_Y,width=104,height=BOT_H,
                        title="FACILITY SUMMARY",accent=colors.gray}

mimic.Gauge{parent=sum,x=2,y=1,width=48,label="TOTAL CPU  ",bind="f_cpu",
            color=cpair(colors.green, style.ind_bkg)}
mimic.Gauge{parent=sum,x=2,y=2,width=48,label="TOTAL MEM  ",bind="f_mem",
            color=cpair(colors.lightBlue, style.ind_bkg)}
mimic.Gauge{parent=sum,x=2,y=3,width=48,label="TOTAL DISK ",bind="f_disk",
            color=cpair(colors.purple, style.ind_bkg)}
mimic.Gauge{parent=sum,x=2,y=4,width=48,label="COOLING    ",bind="f_cool",
            color=cpair(colors.cyan, style.ind_bkg)}

m.DataIndicator{parent=sum,x=54,y=1,label="Nodes online:",unit="of 4",format="%3.0f",
                value=0,width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                bind="f_online"}
m.DataIndicator{parent=sum,x=54,y=2,label="Total power:",unit="W",format="%8.0f",
                value=0,width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                bind="f_power"}
m.DataIndicator{parent=sum,x=54,y=3,label="Avg temp:",unit="C",format="%8.1f",
                value=0,width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                bind="f_temp"}
m.DataIndicator{parent=sum,x=54,y=4,label="Uptime:",unit="s",format="%8.0f",
                value=0,width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                bind="f_uptime"}

-- line-style trend: draws only the band at the value, not a filled area
m.TextBox{parent=sum,x=2,y=6,width=40,text="avg temperature (line)",fg_bg=style.label}
local SUM_CHART_H = sum.get_height() - 6   -- rows 7..bottom of the panel
mimic.Trend{parent=sum,x=2,y=7,width=64,height=SUM_CHART_H,min=20,max=90,style="line",
            color=colors.orange,bind="f_temp",fill=20}

-- categorical bars: comparing the nodes right now, rather than one value over time
m.TextBox{parent=sum,x=68,y=6,width=34,text="cpu by node",fg_bg=style.label}
mimic.BarChart{parent=sum,x=68,y=7,width=34,height=SUM_CHART_H,max=1.0,gap=2,bars={
    { label="N1", bind="n1_cpu", color=colors.green },
    { label="N2", bind="n2_cpu", color=colors.green },
    { label="N3", bind="n3_cpu", color=colors.green },
    { label="N4", bind="n4_cpu", color=colors.orange },
}}

--
-- controls
--

local ctl = mimic.Panel{parent=root,x=107,y=BOT_Y,width=56,height=BOT_H,
                        title="CONTROLS",accent=colors.gray}

local paused = false
local node_state, ONLINE, OFFLINE, STANDBY   -- defined with the data feed below

m.PushButton{parent=ctl,x=2,y=1,text="PAUSE FEED",min_width=16,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_yel,
             callback=function () paused = not paused end}

m.PushButton{parent=ctl,x=2,y=3,text="ALL NORMAL",min_width=16,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
             callback=function ()
                 for i = 1, 4 do node_state[i] = ONLINE end
                 for _, k in ipairs({ "a_offline", "a_thermal", "a_power", "a_link" }) do
                     ps.publish(k, false)
                 end
             end}

m.PushButton{parent=ctl,x=2,y=5,text="FAULT NODE 4",min_width=16,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
             callback=function ()
                 node_state[4] = OFFLINE
                 ps.publish("a_offline", true)
             end}

m.TextBox{parent=ctl,x=21,y=1,width=33,height=6,fg_bg=style.label,
          text="A demo dashboard driven by synthetic data.\n\n" ..
               "Click the buttons; the panels are live."}

local show_alarms = true
m.SwitchButton{parent=ctl,x=2,y=8,text="ALARM SOUND",min_width=16,default=true,
               fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
               callback=function (state) show_alarms = state end}

m.TextBox{parent=ctl,x=21,y=8,width=33,text="mimic v" .. mimic.version,fg_bg=style.label}

--
-- synthetic data feed
--

local t = 0
local uptime = 0

-- 1 = online, 2 = degraded, 3 = offline, 4 = standby (matches the StateIndicator order)
ONLINE, OFFLINE, STANDBY = 1, 3, 4
node_state = { ONLINE, ONLINE, ONLINE, STANDBY }

local function rnd(base, spread) return base + (math.random() - 0.5) * spread end

local function tick()
    uptime = uptime + 1

    if not paused then
        t = t + 1

        local total_rps, total_pwr, total_temp = 0, 0, 0
        local online = 0

        for i = 1, 4 do
            local st = node_state[i]
            local working = st == ONLINE

            local phase = t / 10 + i
            local cpu, mem, temp, pwr, rps

            if working then
                cpu = math.min(1, math.max(0.05, 0.5 + math.sin(phase) * 0.3 + rnd(0, 0.1)))
                mem = math.min(1, math.max(0.05, 0.45 + math.cos(phase * 0.7) * 0.25))
                temp = 40 + cpu * 35 + rnd(0, 3)
                pwr = 400 + cpu * 900
                rps = cpu * 1000
                online = online + 1
            elseif st == STANDBY then
                -- idling: powered, cool, doing no work
                cpu, mem, temp, pwr, rps = 0.02, 0.15, 31 + rnd(0, 1), 90, 0
            else
                -- offline: dark
                cpu, mem, temp, pwr, rps = 0, 0, 20, 0, 0
            end

            ps.publish("n" .. i .. "_state", st)
            ps.publish("n" .. i .. "_cpu", cpu)
            ps.publish("n" .. i .. "_mem", mem)
            ps.publish("n" .. i .. "_disk", math.min(1, 0.3 + (i * 0.12)))
            ps.publish("n" .. i .. "_temp", temp)
            ps.publish("n" .. i .. "_pwr", pwr)
            ps.publish("n" .. i .. "_rps", rps)
            ps.publish("n" .. i .. "_link", st ~= OFFLINE)
            ps.publish("n" .. i .. "_thermal", temp > 70)

            total_rps = total_rps + rps
            total_pwr = total_pwr + pwr
            total_temp = total_temp + temp
        end

        ps.publish("total_rps", total_rps)
        ps.publish("f_power", total_pwr)
        ps.publish("f_temp", total_temp / 4)
        ps.publish("f_online", online)
        ps.publish("f_uptime", uptime)
        ps.publish("f_cpu", (total_rps / 4000))
        ps.publish("f_mem", 0.5 + math.sin(t / 14) * 0.2)
        ps.publish("f_disk", 0.62)
        ps.publish("f_cool", 0.4 + math.cos(t / 9) * 0.2)

        ps.publish("a_cooling", true)
        ps.publish("a_pwr_ok", true)
        ps.publish("a_net_ok", true)
        ps.publish("a_stor_ok", true)
        ps.publish("a_mem", (0.5 + math.sin(t / 14) * 0.2) > 0.65)
    end

    ps.publish("clock", os.date("%H:%M:%S"))
    tcd.dispatch_unique(1.0, tick)
end

tick()

mimic.run()
