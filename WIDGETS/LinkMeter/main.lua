-- LinkMeter Widget
-- Copyright (C) 2025 Calari and ChatGPT
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

local options = {
  { "ShowPercent", BOOL, 1 },                           -- Prozentwert anzeigen
  { "Text", COLOR, lcd.RGB(255, 255, 255) },            -- Textfarbe
  { "Shadow", COLOR, lcd.RGB(85, 85, 85) },             -- Schattentextfarbe
  { "BarCount", VALUE, 10, 4, 22 },                     -- Anzahl Balken
  { "BarColor", COLOR, lcd.RGB(30, 30, 30) },           -- Leere Balken
  { "Low", COLOR, lcd.RGB(255, 0, 0) },                 -- < 80%
  { "Medium", COLOR, lcd.RGB(255, 165, 0) },            -- 80–89%
  { "High", COLOR, lcd.RGB(0, 255, 0) }                 -- >= 90%
}

local WEIGHT_RQ = 0.8
local WEIGHT_RSSI = 0.2

local function clampPercent(value)
  value = tonumber(value) or 0
  return math.min(100, math.max(0, math.floor(value)))
end

local function normalizeRSSI(rssi)
  if not rssi then return 0 end
  if rssi <= -110 then return 0 end
  if rssi >= -50 then return 100 end
  local x = (rssi + 110) / 60
  local curved = x ^ 1.5
  return math.floor(curved * 100 + 0.5)
end

local function getBestRSSI()
  local r1 = getValue("1RSS")
  local r2 = getValue("2RSS")
  local r  = getValue("RSSI")
  local best = nil
  if r1 and r1 ~= 0 then best = r1 end
  if r2 and r2 ~= 0 and (not best or r2 > best) then best = r2 end
  if r and r ~= 0 and (not best or r > best) then best = r end
  if best then
    return normalizeRSSI(best)
  end
  return nil
end

local function getSignalValue()
  local tq = getValue("RQly")
  local rssiNorm = getBestRSSI()
  if tq and rssiNorm then
    local tqClamped = clampPercent(tq)
    return math.floor(WEIGHT_RQ * tqClamped + WEIGHT_RSSI * rssiNorm + 0.5)
  elseif tq then
    return clampPercent(tq)
  elseif rssiNorm then
    return rssiNorm
  else
    return 0
  end
end

local function drawBars(x, y, w, h, percent, opts)
  local bars = opts.BarCount
--  local bars = 10
  local gap = 1
  local barWidth = math.floor((w - (bars - 1) * gap) / bars)
  local maxBarHeight = h - 4
  local minHeight = 6
  local growthFactor = 2.0

  local filledBars = math.floor((percent / 100) * bars + 0.5)

  local fillColor
  if percent < 80 then
    fillColor = opts.Low
  elseif percent < 90 then
    fillColor = opts.Medium
  else
    fillColor = opts.High
  end

  local lastHeight = 0
  for i = 1, bars do
    local factor = (i - 1) / (bars - 1)
    local rawHeight = minHeight + (maxBarHeight - minHeight) * (factor ^ growthFactor)
    local barHeight = math.max(lastHeight + 1, math.ceil(rawHeight)) -- garantiert +1 pro Balken
    if barHeight > maxBarHeight then barHeight = maxBarHeight end
    lastHeight = barHeight

    local barX = x + (i - 1) * (barWidth + gap)
    local barY = y + h - barHeight

    if i <= filledBars then
      lcd.drawFilledRectangle(barX, barY, barWidth, barHeight, fillColor)
    else
      lcd.drawFilledRectangle(barX, barY, barWidth, barHeight, opts.BarColor)
    end
  end
  return barWidth
end

local function drawPercentText(x, y, percent, opts)
  local text = string.format("%d", percent)
  lcd.drawText(x+1, y+1, text, opts.Shadow)
  lcd.drawText(x-1, y-1, text, opts.Text)
end

local function refresh(widget)
  local opts = {}
  for _, def in ipairs(options) do
    opts[def[1]] = widget.options[def[1]]
  end

  local percent = clampPercent(getSignalValue())

  local x = widget.zone.x or 0
  local y = widget.zone.y or 0
  local w = widget.zone.w or 100
  local h = widget.zone.h or 40

  -- Alles leicht nach oben verschieben
  y = y - 2

  drawBars(x, y, w, h, percent, opts)

  if opts.ShowPercent == 1 then
    drawPercentText(x , y, percent, opts)
  end
end

return {
  name = "LinkMeter",
  options = options,
  create = function(zone, options) return { zone = zone, options = options } end,
  update = function(widget, options) widget.options = options end,
  refresh = refresh
}
