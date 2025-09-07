-- /WIDGETS/Speed/main.lua
-- Speed-Widget: GSpd + geglättete Vertikalgeschwindigkeit
-- EdgeTX 2.11.x, keine globalen Variablen

local name = "Speed"

local options = {
    { "Color", COLOR, lcd.RGB(130, 230, 30) }
}

local MAX_VSPD = 50        -- m/s
local SMOOTH_SECONDS = 3   -- Sekunden Glättung

-- Runs once when the widget instance is created
local function create(zone, options)
    local widget = {
        zone = zone,
        options = options,
        lastAlt = nil,
        lastTime = nil,
        vspdBuffer = {},
        lastCalcSpd = 0
    }
    return widget
end

-- Runs when options are changed from the Widget Settings menu
local function update(widget, options)
    widget.options = options
end

-- Runs periodically when the widget instance is visible
local function refresh(widget, event, touchState)
    local gspd = getValue("GSpd") or 0
    local alt  = getValue("Alt")  or 0
    local now = getTime()
    local vspd = 0

    if widget.lastAlt and widget.lastTime then
        local dt = (now - widget.lastTime) / 100
        if dt > 0.05 then
            vspd = (alt - widget.lastAlt) / dt
            vspd = math.max(math.min(vspd, MAX_VSPD), -MAX_VSPD)
        end
    end
    widget.lastAlt = alt
    widget.lastTime = now

    -- Ringpuffer für Glättung
    table.insert(widget.vspdBuffer, 1, {vspd, now})
    for i = #widget.vspdBuffer, 1, -1 do
        if (now - widget.vspdBuffer[i][2])/100 > SMOOTH_SECONDS then
            table.remove(widget.vspdBuffer, i)
        end
    end

    local sum = 0
    for i = 1, #widget.vspdBuffer do
        sum = sum + widget.vspdBuffer[i][1]
    end
    local vspdAvg = (#widget.vspdBuffer > 0) and (sum / #widget.vspdBuffer) or 0

    widget.lastCalcSpd = math.sqrt(gspd^2 + (vspdAvg*3.6)^2)

    -- Label oben links
    lcd.drawText(widget.zone.x + 2, widget.zone.y + 2, "Speed", SMLSIZE + widget.options.Color)

    -- Hauptwert zentriert
    lcd.drawText(widget.zone.x + widget.zone.w/2,
                 widget.zone.y + widget.zone.h/2 - 10,
                 string.format("%.1f km/h", widget.lastCalcSpd),
                 DBLSIZE + CENTER + widget.options.Color)
end

-- Optional: Runs periodically when widget is not visible
local function background(widget)
    -- nichts nötig
end

return {
    name = name,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background
}
