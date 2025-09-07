-- /WIDGETS/Speed/main.lua
-- Speed-Widget: GSpd + geglättete Vertikalgeschwindigkeit
-- Stabil, Farboptionen, EdgeTX 2.11.x

local options = {
  { "Color", COLOR, lcd.RGB(30, 30, 30) },
}

local lastAlt
local lastTime
local lastCalcSpd = 0
local vspdBuffer = {}
local MAX_VSPD = 50 -- m/s
local SMOOTH_SECONDS = 3 -- Sekunden Glättung

local function create(zone, _options)
  return { zone = zone, options = _options }
end

local function update(widget, _options)
  widget.options = _options
end

local function refresh(widget)

    local gspd = getValue("GSpd") or 0
    local alt  = getValue("Alt")  or 0
    local now = getTime()
    local vspd = 0

    if lastAlt and lastTime then
        local dt = (now - lastTime) / 100
        if dt > 0.05 then
            vspd = (alt - lastAlt) / dt
            vspd = math.max(math.min(vspd, MAX_VSPD), -MAX_VSPD)
        end
    end
    lastAlt = alt
    lastTime = now

    -- Ringpuffer für 3-Sekunden-Glättung
    table.insert(vspdBuffer, 1, {vspd, now})
    for i=#vspdBuffer,1,-1 do
        if (now - vspdBuffer[i][2])/100 > SMOOTH_SECONDS then
            table.remove(vspdBuffer, i)
        end
    end

    local sum = 0
    for i=1,#vspdBuffer do sum = sum + vspdBuffer[i][1] end
    local vspdAvg = (#vspdBuffer>0) and (sum/#vspdBuffer) or 0

    lastCalcSpd = math.sqrt(gspd^2 + (vspdAvg*3.6)^2)

    -- Label oben links
    lcd.drawText(widget.zone.x + 2, widget.zone.y + 2, "Speed", SMLSIZE + widget.options.Color)

    -- Hauptwert zentriert
    lcd.drawText(widget.zone.x + widget.zone.w/2,
                 widget.zone.y + widget.zone.h/2 - 10,
                 string.format("%.1f km/h", lastCalcSpd),
                 DBLSIZE + CENTER + widget.options.Color)
end

return {
    name = "Speed",
    options = options,
    create = create,
    update = update,
    refresh = refresh
}
