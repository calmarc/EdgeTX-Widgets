-- /WIDGETS/LinkMeter/main.lua
-- LinkMeter Widget
-- Copyright (C) 2025 Calari + Grok

local options = {
  { "ShowPercent", BOOL, 1 },           -- Prozentwert anzeigen
  { "Text",        COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow",      COLOR, lcd.RGB(85, 85, 85) },
  { "BarCount",    VALUE, 10, 4, 22 },
  { "BarColor",    COLOR, lcd.RGB(30, 30, 30) },   -- Leere Balken
  { "Low",         COLOR, lcd.RGB(255, 0, 0) },    -- < 80%
  { "Medium",      COLOR, lcd.RGB(255, 165, 0) },  -- 80-89%
  { "High",        COLOR, lcd.RGB(0, 255, 0) }     -- >= 90%
}

local WEIGHT_RQ   = 0.8
local WEIGHT_RSSI = 0.2

local function clampPercent(value)
  value = tonumber(value) or 0
  return math.max(0, math.min(100, math.floor(value)))
end

local function normalizeRSSI(rssi)
  if not rssi or rssi <= -110 then return 0 end
  if rssi >= -50 then return 100 end
  local x = (rssi + 110) / 60
  return math.floor(x ^ 1.5 * 100 + 0.5)
end

local function getBestRSSI()
  local r1 = getValue("1RSS")
  local r2 = getValue("2RSS")
  local r  = getValue("RSSI")
  
  local best = nil
  if r1 and r1 ~= 0 then best = r1 end
  if r2 and r2 ~= 0 and (not best or r2 > best) then best = r2 end
  if r  and r  ~= 0 and (not best or r  > best) then best = r  end

  return best and normalizeRSSI(best) or 0
end

local function getSignalValue()
  local tq = getValue("RQly")
  local rssiNorm = getBestRSSI()

  if tq and rssiNorm then
    return math.floor(WEIGHT_RQ * clampPercent(tq) + WEIGHT_RSSI * rssiNorm + 0.5)
  elseif tq then
    return clampPercent(tq)
  else
    return rssiNorm
  end
end

local function drawBars(x, y, w, h, percent, widget)
  local bars = widget.options.BarCount
  local gap = 1
  local barWidth = math.floor((w - (bars - 1) * gap) / bars)
  local maxBarHeight = h - 4
  local minHeight = 6
  local growthFactor = 2.0

  local filledBars = math.floor((percent / 100) * bars + 0.5)

  local fillColor
  if percent < 80 then
    fillColor = widget.options.Low
  elseif percent < 90 then
    fillColor = widget.options.Medium
  else
    fillColor = widget.options.High
  end

  local lastHeight = 0
  for i = 1, bars do
    local factor = (i - 1) / (bars - 1)
    local rawHeight = minHeight + (maxBarHeight - minHeight) * (factor ^ growthFactor)
    local barHeight = math.max(lastHeight + 1, math.ceil(rawHeight))
    if barHeight > maxBarHeight then barHeight = maxBarHeight end
    lastHeight = barHeight

    local barX = x + (i - 1) * (barWidth + gap)
    local barY = y + h - barHeight

    if i <= filledBars then
      lcd.drawFilledRectangle(barX, barY, barWidth, barHeight, fillColor)
    else
      lcd.drawFilledRectangle(barX, barY, barWidth, barHeight, widget.options.BarColor)
    end
  end
end

local function drawPercentText(x, y, percent, widget)
  local text = string.format("%d%%", percent)
  lcd.drawText(x + 1, y + 1, text, widget.options.Shadow)
  lcd.drawText(x,     y,     text, widget.options.Text)
end

local function refresh(widget)
  local percent = clampPercent(getSignalValue())

  local zone = widget.zone or {}
  local x = tonumber(zone.x) or 0
  local y = tonumber(zone.y) or 0
  local w = tonumber(zone.w) or 100
  local h = tonumber(zone.h) or 40

  y = y - 2   -- leichte Anpassung wie vorher

  drawBars(x, y, w, h, percent, widget)

  if widget.options.ShowPercent == 1 then
    drawPercentText(x + 4, y + 2, percent, widget)   -- etwas besser positioniert
  end
end

return {
  name = "LinkMeter",
  options = options,
  create = function(zone, options)
    return { zone = zone, options = options }
  end,
  update = function(widget, options)
    widget.options = options
  end,
  refresh = refresh
}
