--
-- mimic - two-display facility demo
--
-- The realistic shape of a mimic program, and the one cc-mek-scada uses:
--
--   * the computer's own 51x19 screen shows a FRONT PANEL (status lights, buttons)
--   * a monitor array shows the DASHBOARD (panels, gauges, trends, alarms)
--
-- Both run from one program and one event loop. Touches on the monitor go to the
-- monitor's UI; clicks and keys on the computer go to the front panel.
--
--   facility            -- finds the first monitor, or runs panel-only
--   facility right      -- use the monitor on a specific side
--

require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local psil = require("scada-common.psil")
local tcd  = require("scada-common.tcd")

local style = mimic.style
local cpair = mimic.cpair

local arg_side = ...

local ps = psil.create()

--
-- find a monitor
--

local function find_monitor()
    if arg_side then return arg_side end
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then return name end
    end
end

-- CraftOS-PC convenience: conjure a monitor if none is attached, sized to an 8x4
-- block array, which is 164x52 characters at 0.5 text scale. In Minecraft you would
-- place the monitors instead; periphemu does not exist there.
local function emulate_monitor()
    if periphemu == nil then return nil end
    if not pcall(function () periphemu.create("right", "monitor") end) then return nil end
    local mon = peripheral.wrap("right")
    if mon and mon.setBlockSize then pcall(function () mon.setBlockSize(8, 4) end) end
    return "right"
end

local mon_name = find_monitor() or emulate_monitor()

--
-- the computer's own screen: a front panel
--

local panel = mimic.init{ps=ps}

m.TextBox{parent=panel,y=1,text="MIMIC FACILITY CONTROLLER",
          alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}

local sys = m.Div{parent=panel,x=2,y=3,width=22,height=15}

mimic.LEDList{parent=sys,width=20,leds={
    { label="STATUS",    bind="status" },
    { label="HEARTBEAT", bind="heartbeat" },
    {},
    { label="MONITOR",   bind="has_monitor" },
    { label="DATA FEED", bind="feed_ok" },
    {},
    { label="NODE 01",   bind="n1_link" },
    { label="NODE 02",   bind="n2_link" },
    { label="NODE 03",   bind="n3_link" },
    { label="NODE 04",   bind="n4_link" },
}}

local right = m.Div{parent=panel,x=26,y=3,width=24,height=15}

m.DataIndicator{parent=right,x=1,y=1,label="Nodes:",unit="of 4",format="%3.0f",value=0,
                width=22,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="f_online"}
m.DataIndicator{parent=right,x=1,y=2,label="Power:",unit="W",format="%6.0f",value=0,
                width=22,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="f_power"}
m.DataIndicator{parent=right,x=1,y=3,label="Temp:",unit="C",format="%6.1f",value=0,
                width=22,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="f_temp"}

-- a small trend fits a computer screen too
m.TextBox{parent=right,x=1,y=5,width=22,text="throughput",fg_bg=style.label}
m.Trend{parent=right,x=1,y=6,width=22,height=4,max=4000,color=colors.green,bind="total_rps"}

local fault = false
m.PushButton{parent=right,x=1,y=11,text="FAULT NODE 4",min_width=16,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
             callback=function () fault = true end}
m.PushButton{parent=right,x=1,y=13,text="ALL NORMAL",min_width=16,
             fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
             callback=function () fault = false end}

m.TextBox{parent=panel,x=2,y=19,width=48,fg_bg=style.label,
          text=mon_name and ("dashboard on " .. mon_name) or "no monitor found - panel only"}

--
-- the monitor: a dashboard
--

local board
if mon_name then
    board = mimic.add_display{monitor=mon_name, ps=ps}

    local W, H = board.get_width(), board.get_height()

    if W < 100 or H < 40 then
        m.TextBox{parent=board,x=2,y=2,width=W-2,height=6,fg_bg=cpair(colors.red, style.theme.bg),
                  text="This monitor is " .. W .. "x" .. H .. ".\n" ..
                       "The dashboard needs 100x40 - use at least 8x4 blocks at 0.5 text scale."}
        board = nil
    end
end

if board then
    local W, H = board.get_width(), board.get_height()

    m.TextBox{parent=board,y=1,text="MIMIC FACILITY OVERVIEW",
              alignment=mimic.ALIGN.CENTER,fg_bg=style.theme.header}
    m.TextBox{parent=board,x=W-24,y=1,width=23,text="",alignment=mimic.ALIGN.RIGHT,
              fg_bg=style.theme.header,bind="clock"}

    local NODE_Y, NODE_H = 3, 14
    local MID_Y, MID_H = NODE_Y + NODE_H + 1, 14
    local BOT_Y = MID_Y + MID_H + 1
    local BOT_H = H - BOT_Y

    for i = 1, 4 do
        local p = mimic.Panel{parent=board,x=2 + (i - 1) * 40,y=NODE_Y,width=39,height=NODE_H,
                              title="NODE 0" .. i,
                              accent=(i == 4) and colors.orange or colors.cyan}

        m.StateIndicator{parent=p,x=2,y=1,min_width=16,value=1,states={
            { color = cpair(colors.black, colors.green),  text = "ONLINE" },
            { color = cpair(colors.black, colors.yellow), text = "DEGRADED" },
            { color = cpair(colors.white, colors.red),    text = "OFFLINE" },
            { color = cpair(colors.white, colors.gray),   text = "STANDBY" },
        },bind="n" .. i .. "_state"}

        m.DataIndicator{parent=p,x=20,y=1,label="",unit="req/s",format="%6.0f",value=0,
                        width=17,fg_bg=style.theme.highlight_box,lu_colors=style.lu_colors,
                        bind="n" .. i .. "_rps"}

        mimic.Gauge{parent=p,x=2,y=3,width=35,label="CPU ",bind="n" .. i .. "_cpu",
                    color=cpair(colors.green, style.ind_bkg)}
        mimic.Gauge{parent=p,x=2,y=4,width=35,label="MEM ",bind="n" .. i .. "_mem",
                    color=cpair(colors.lightBlue, style.ind_bkg)}
        mimic.Gauge{parent=p,x=2,y=5,width=35,label="DISK",bind="n" .. i .. "_disk",
                    color=cpair(colors.purple, style.ind_bkg)}

        m.DataIndicator{parent=p,x=2,y=7,label="Temp:",unit="C",format="%7.1f",value=0,
                        width=35,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                        bind="n" .. i .. "_temp"}
        m.DataIndicator{parent=p,x=2,y=8,label="Power:",unit="W",format="%6.0f",value=0,
                        width=35,fg_bg=style.text_colors,lu_colors=style.lu_colors,
                        bind="n" .. i .. "_pwr"}

        mimic.LEDList{parent=p,x=2,y=10,width=35,leds={
            { label="LINK",    bind="n" .. i .. "_link" },
            { label="THERMAL", bind="n" .. i .. "_thermal", color=style.ind_red },
        }}
    end

    -- throughput, as a filled area chart with a y axis
    local tp = mimic.Panel{parent=board,x=2,y=MID_Y,width=104,height=MID_H,
                           title="AGGREGATE THROUGHPUT",accent=colors.gray}
    local RPS_MAX = 4000
    m.TextBox{parent=tp,x=2,y=1,width=40,text="requests/sec, last 95 samples",fg_bg=style.label}
    m.DataIndicator{parent=tp,x=70,y=1,label="Now:",unit="req/s",format="%7.0f",value=0,
                    width=30,fg_bg=style.theme.highlight_box,lu_colors=style.lu_colors,
                    bind="total_rps"}
    m.TextBox{parent=tp,x=1,y=3,width=5,text=tostring(RPS_MAX),alignment=mimic.ALIGN.RIGHT,fg_bg=style.label}
    m.TextBox{parent=tp,x=1,y=6,width=5,text=tostring(RPS_MAX / 2),alignment=mimic.ALIGN.RIGHT,fg_bg=style.label}
    m.TextBox{parent=tp,x=1,y=10,width=5,text="0",alignment=mimic.ALIGN.RIGHT,fg_bg=style.label}
    mimic.Trend{parent=tp,x=7,y=3,width=95,height=8,max=RPS_MAX,color=colors.green,bind="total_rps"}

    local ap = mimic.Panel{parent=board,x=107,y=MID_Y,width=56,height=MID_H,
                           title="FACILITY ALARMS",accent=colors.red}
    mimic.LEDList{parent=ap,x=2,y=1,width=25,color=style.ind_red,leds={
        { label="NODE OFFLINE",  bind="a_offline", flash=true, period=mimic.PERIOD.BLINK_500_MS },
        { label="THERMAL LIMIT", bind="a_thermal" },
        { label="POWER FAULT",   bind="a_power" },
        { label="LINK DEGRADED", bind="a_link", color=style.ind_yel },
    }}
    mimic.LEDList{parent=ap,x=29,y=1,width=25,leds={
        { label="COOLING OK", bind="a_cooling" },
        { label="POWER OK",   bind="a_pwr_ok" },
        { label="NETWORK OK", bind="a_net_ok" },
        { label="STORAGE OK", bind="a_stor_ok" },
    }}

    local sum = mimic.Panel{parent=board,x=2,y=BOT_Y,width=104,height=BOT_H,
                            title="FACILITY SUMMARY",accent=colors.gray}
    mimic.Gauge{parent=sum,x=2,y=1,width=48,label="TOTAL CPU  ",bind="f_cpu",
                color=cpair(colors.green, style.ind_bkg)}
    mimic.Gauge{parent=sum,x=2,y=2,width=48,label="TOTAL MEM  ",bind="f_mem",
                color=cpair(colors.lightBlue, style.ind_bkg)}
    mimic.Gauge{parent=sum,x=2,y=3,width=48,label="COOLING    ",bind="f_cool",
                color=cpair(colors.cyan, style.ind_bkg)}
    m.DataIndicator{parent=sum,x=54,y=1,label="Nodes online:",unit="of 4",format="%3.0f",value=0,
                    width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="f_online"}
    m.DataIndicator{parent=sum,x=54,y=2,label="Total power:",unit="W",format="%8.0f",value=0,
                    width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="f_power"}
    m.DataIndicator{parent=sum,x=54,y=3,label="Uptime:",unit="s",format="%8.0f",value=0,
                    width=46,fg_bg=style.text_colors,lu_colors=style.lu_colors,bind="f_uptime"}

    local CH = sum.get_height() - 6
    m.TextBox{parent=sum,x=2,y=5,width=40,text="avg temperature (line)",fg_bg=style.label}
    mimic.Trend{parent=sum,x=2,y=6,width=64,height=CH,min=20,max=90,style="line",
                color=colors.orange,bind="f_temp",fill=20}
    m.TextBox{parent=sum,x=68,y=5,width=34,text="cpu by node",fg_bg=style.label}
    mimic.BarChart{parent=sum,x=68,y=6,width=34,height=CH,max=1.0,gap=2,bars={
        { label="N1", bind="n1_cpu", color=colors.green },
        { label="N2", bind="n2_cpu", color=colors.green },
        { label="N3", bind="n3_cpu", color=colors.green },
        { label="N4", bind="n4_cpu", color=colors.orange },
    }}

    local ctl = mimic.Panel{parent=board,x=107,y=BOT_Y,width=56,height=BOT_H,
                            title="CONTROLS",accent=colors.gray}
    m.TextBox{parent=ctl,x=2,y=1,width=52,height=6,fg_bg=style.label,
              text="Two displays, one program.\n\n" ..
                   "This monitor and the computer's own screen are driven by the same\n" ..
                   "psil. Touch here, or click the panel on the computer."}
    m.PushButton{parent=ctl,x=2,y=8,text="FAULT NODE 4",min_width=16,
                 fg_bg=style.wh_gray,active_fg_bg=style.ind_red,
                 callback=function () fault = true end}
    m.PushButton{parent=ctl,x=20,y=8,text="ALL NORMAL",min_width=16,
                 fg_bg=style.wh_gray,active_fg_bg=style.ind_grn,
                 callback=function () fault = false end}
end

--
-- one data feed, both displays
--

local ONLINE, OFFLINE, STANDBY = 1, 3, 4
local t, uptime, beat = 0, 0, false

local function rnd(base, spread) return base + (math.random() - 0.5) * spread end

local function tick()
    t = t + 1
    uptime = uptime + 1
    beat = not beat

    local total_rps, total_pwr, total_temp, online = 0, 0, 0, 0

    for i = 1, 4 do
        local st = ONLINE
        if i == 4 then st = fault and OFFLINE or STANDBY end

        local cpu, mem, temp, pwr, rps
        if st == ONLINE then
            cpu = math.min(1, math.max(0.05, 0.5 + math.sin(t / 10 + i) * 0.3 + rnd(0, 0.1)))
            mem = math.min(1, math.max(0.05, 0.45 + math.cos((t / 10 + i) * 0.7) * 0.25))
            temp = 40 + cpu * 35 + rnd(0, 3)
            pwr = 400 + cpu * 900
            rps = cpu * 1000
            online = online + 1
        elseif st == STANDBY then
            cpu, mem, temp, pwr, rps = 0.02, 0.15, 31 + rnd(0, 1), 90, 0
        else
            cpu, mem, temp, pwr, rps = 0, 0, 20, 0, 0
        end

        ps.publish("n" .. i .. "_state", st)
        ps.publish("n" .. i .. "_cpu", cpu)
        ps.publish("n" .. i .. "_mem", mem)
        ps.publish("n" .. i .. "_disk", math.min(1, 0.3 + i * 0.12))
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
    ps.publish("f_cpu", total_rps / 4000)
    ps.publish("f_mem", 0.5 + math.sin(t / 14) * 0.2)
    ps.publish("f_cool", 0.4 + math.cos(t / 9) * 0.2)

    ps.publish("status", true)
    ps.publish("heartbeat", beat)
    ps.publish("has_monitor", board ~= nil)
    ps.publish("feed_ok", true)
    ps.publish("a_offline", fault)
    ps.publish("a_thermal", false)
    ps.publish("a_power", false)
    ps.publish("a_link", false)
    ps.publish("a_cooling", true)
    ps.publish("a_pwr_ok", true)
    ps.publish("a_net_ok", true)
    ps.publish("a_stor_ok", true)
    ps.publish("clock", os.date("%H:%M:%S"))

    tcd.dispatch_unique(1.0, tick)
end

tick()

mimic.run()
