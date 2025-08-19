-- LinkMeter Widget
-- Copyright (C) 2025 Calari and ChatGPT
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

local options = {
  { "tx_voltage__RxBt", BOOL, 0 },
  { "Cells", VALUE, 2, 1, 8 },
  { "PerCell", BOOL, 1 },
  { "Text", COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow", COLOR, lcd.RGB(80, 80, 80) },
  { "BatColor", COLOR, lcd.RGB(30, 30, 30) },
  { "Full", COLOR, lcd.RGB(0, 170, 0) },
  { "High", COLOR, lcd.RGB(80, 170, 0) },
  { "Medium", COLOR, lcd.RGB(150, 150, 0) },
  { "Low", COLOR, lcd.RGB(255, 165, 0) }
}

local MIN_FILL = 8 -- Mindestbreite der gefüllten Balken

local function getBatteryColor(percent, opts)
  if percent >= 80 then return opts.Full end
  if percent >= 60 then return opts.High end
  if percent >= 40 then return opts.Medium end
  if percent >= 20 then return opts.Low end
  return opts.BatColor
end

local function getVoltagePercent(voltage, minV, maxV)
  local percent = math.floor((voltage - minV) / (maxV - minV) * 100)
  return math.min(100, math.max(0, percent))
end

local function drawBattery(frameX, frameY, frameW, frameH, voltage, percent, color, opts)
  local function textWidth(text, flags)
    if lcd.getTextWidth then
      return lcd.getTextWidth(flags, text)
    else
      return lcd.sizeText(text, flags)
    end
  end

  -- Batteriegröße
  local capW = math.max(2, math.floor(frameW * 0.03))
  if capW < 8 then capW = 6 end
  local bodyW = frameW - capW - 2
  local bodyH = frameH
  local capH = math.floor(bodyH * 0.35)

  -- Rahmen
  -- lcd.drawRectangle(frameX, frameY, bodyW, bodyH, SOLID, lcd.RGB(200, 200, 200))
  lcd.drawFilledRectangle(frameX + 1, frameY + 1, bodyW - 2, bodyH - 2, opts.BatColor)

  -- Pluspol
  local capX = frameX + bodyW - 1
  local capY = frameY + (bodyH - capH) // 2
  lcd.drawFilledRectangle(capX, capY, capW, capH, opts.BatColor)

  -- Füllung

  local fillW
  fillW = math.floor((bodyW - 6) * percent / 100) -- vorher -4
  if fillW < MIN_FILL then fillW = MIN_FILL end -- Mindestbreite

  lcd.drawFilledRectangle(frameX + 3, frameY + 3, fillW, bodyH - 6, color)

  -- Textgröße bestimmen
  local textFlags
  if voltage < 10 then
    textFlags = MIDSIZE + BOLD
  else
    textFlags = BOLD
  end

  local numText = string.format("%.1f", voltage)
  local unitText = "V"
  local numWidth = textWidth(numText, textFlags)
  local unitWidth = textWidth(unitText, SMLSIZE)
  local totalWidth = numWidth + unitWidth

  local textX = frameX + (bodyW - totalWidth) // 2

  -- Vertikal zentrieren
  local centerY = frameY + (bodyH // 2)
  local textY
  if textFlags & MIDSIZE ~= 0 then
    textY = centerY - 19 -- Feinkorrektur für MIDSIZE
  else
    textY = centerY - 10 -- Feinkorrektur für normale Größe
  end

  -- Schatten
  lcd.drawText(textX + 2, textY + 2, numText, textFlags + opts.Shadow)
  -- Text
  lcd.drawText(textX, textY, numText, textFlags + opts.Text)

  local unitX = textX + numWidth - 1
  lcd.drawText(unitX, textY + 4, unitText, SMLSIZE + opts.Text)
end

local function create(zone, _options)
  return { zone = zone, options = _options }
end

local function update(widget, _options)
  widget.options = _options
end

local function refresh(widget)
  local opts = {}
  for _, def in ipairs(options) do
    opts[def[1]] = widget.options[def[1]]
  end

  opts.Cells = math.max(1, math.min(opts.Cells or 2, 8))

  -- Quelle auswählen
  local rawVoltage
  if opts.tx_voltage__RxBt == 0 then
    rawVoltage = getValue("tx-voltage") or 0
  else
    rawVoltage = getValue("RxBt") or 0
  end

  local voltage = rawVoltage
  local lowlimit, full

  if opts.PerCell == 1 then
    voltage = voltage / opts.Cells
    lowlimit = 3.2
    full = 4.2
  else
    lowlimit = 3.2 * opts.Cells
    full = 4.2 * opts.Cells
  end

  local percent = getVoltagePercent(voltage, lowlimit, full)
  local color = getBatteryColor(percent, opts)

  local x = tonumber(widget.zone.x) or 0
  local y = tonumber(widget.zone.y) or 0
  local w = tonumber(widget.zone.w) or 100
  local h = tonumber(widget.zone.h) or 30

  drawBattery(x, y, w, h, voltage, percent, color, opts)
end

return {
  name = "BattMeter",
  options = options,
  create = create,
  update = update,
  refresh = refresh
}
