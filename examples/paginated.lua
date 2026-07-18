--
-- mimic - paginated overview
--
-- Many nodes, more than fit on one screen, paged N at a time with live data.
-- Each node's gauges are bound, including on hidden pages: flip to a page and it
-- already shows current values.
--
--   paginated
--

require("/initenv").init_env()

local mimic = require("mimic")
local m     = require("mimic.elements")

local psil = require("scada-common.psil")
local tcd  = require("scada-common.tcd")

local style = mimic.style
local cpair = mimic.cpair

local ps = psil.create()
local root = mimic.init{ps=ps}

local W, H = root.get_width(), root.get_height()

m.TextBox{parent=root, y=1, text="NODE OVERVIEW (paginated)",
          alignment=mimic.ALIGN.CENTER, fg_bg=style.theme.header}

-- 12 nodes; on a computer screen we show a few per page
local NODES = 12
local nodes = {}
for i = 1, NODES do nodes[i] = i end

local box = mimic.Panel{parent=root, x=1, y=2, width=W, height=H - 1,
                        title="NODES", accent=colors.cyan}
local CW, CH = box.get_width(), box.get_height()

mimic.Paginator{parent=box, x=1, y=1, width=CW, height=CH, items=nodes, per_page=3, cols=1,
    render=function (slot, id, index)
        local p = mimic.Panel{parent=slot, x=1, y=1, width=slot.get_width(), height=slot.get_height(),
                              title="NODE " .. string.format("%02d", id),
                              accent=(id % 4 == 0) and colors.orange or colors.gray}
        m.StateIndicator{parent=p, x=2, y=1, min_width=10, value=1, states={
            { color=cpair(colors.black, colors.green),  text="ONLINE" },
            { color=cpair(colors.white, colors.red),    text="OFFLINE" },
        }, bind="n" .. id .. "_state"}
        mimic.Gauge{parent=p, x=14, y=1, width=slot.get_width() - 15, label="CPU ",
                    bind="n" .. id .. "_cpu", color=cpair(colors.green, style.ind_bkg)}
    end}

-- live feed for every node, whether its page is visible or not
local t = 0
local function tick()
    t = t + 1
    for i = 1, NODES do
        ps.publish("n" .. i .. "_state", 1)
        ps.publish("n" .. i .. "_cpu", math.min(1, math.max(0.05,
            0.5 + math.sin(t / 8 + i) * 0.35)))
    end
    tcd.dispatch_unique(1.0, tick)
end
tick()

mimic.run()
