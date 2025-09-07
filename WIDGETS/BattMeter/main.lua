-- /WIDGETS/BattMeter/main.lua
-- BattMeter Widget
-- Copyright (C) 2025 Calari and ChatGPT
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- Optionen des Widgets
local options = {
  { "tx_voltage__RxBt", BOOL, 0 },               -- 0=tx-voltage, 1=RxBt
  { "Cells", VALUE, 2, 1, 8 },                   -- Anzahl Zellen
  { "PerCell", BOOL, 1 },                        -- Spannung pro Zelle oder Gesamtspannung
  { "Text", COLOR, lcd.RGB(255, 255, 255) },    -- Textfarbe
  { "Shadow", COLOR, lcd.RGB(80, 80, 80) },     -- Schattenfarbe für Text
  { "BatColor", COLOR, lcd.RGB(30, 30, 30) },   -- Hintergrundfarbe
  { "Full", COLOR, lcd.RGB(0, 170, 0) },        -- volle Batterie
  { "High", COLOR, lcd.RGB(80, 170, 0) },       -- hoher Ladezustand
  { "Medium", COLOR, lcd.RGB(150, 150, 0) },    -- mittlerer Ladezustand
  { "Low", COLOR, lcd.RGB(255, 165, 0) }        -- niedriger Ladezustand
}

local MIN_FILL = 8 -- Mindestbreite der gefüllten Balken

-- Funktion zur Ermittlung der Batterie-Farbe je nach Ladezustand
local function getBatteryColor(percent, widget)
  if percent >= 80 then return widget.options.Full end
  if percent >= 60 then return widget.options.High end
  if percent >= 40 then return widget.options.Medium end
  if percent >= 20 then return widget.options.Low end
  return widget.options.BatColor
end

-- Berechnet prozentualen Ladezustand zwischen minV und maxV
local function getVoltagePercent(voltage, minV, maxV)
  local percent = math.floor((voltage - minV) / (maxV - minV) * 100)
  return math.min(100, math.max(0, percent))
end

-- Zeichnet die Batterie inkl. Rahmen, Füllung, Text
local function drawBattery(frameX, frameY, frameW, frameH, voltage, percent, color, widget)
  -- Hilfsfunktion zur Breitenberechnung des Textes
  local function textWidth(text, flags)
    if lcd.getTextWidth then
      return lcd.getTextWidth(flags, text)
    else
      return lcd.sizeText(text, flags)
    end
  end

  -- Berechnung Batteriegröße
  local capW = math.max(2, math.floor(frameW * 0.03))
  if capW < 8 then capW = 6 end
  local bodyW = frameW - capW - 2
  local bodyH = frameH
  local capH = math.floor(bodyH * 0.35)

  -- Hintergrund / Rahmen
  lcd.drawFilledRectangle(frameX + 1, frameY + 1, bodyW - 2, bodyH - 2, widget.options.BatColor)

  -- Pluspol
  local capX = frameX + bodyW - 1
  local capY = frameY + (bodyH - capH) // 2
  lcd.drawFilledRectangle(capX, capY, capW, capH, widget.options.BatColor)

  -- Füllung
  local fillW = math.floor((bodyW - 6) * percent / 100)
  if fillW < MIN_FILL then fillW = MIN_FILL end
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

  -- Vertikale Zentrierung
  local centerY = frameY + (bodyH // 2)
  local textY
  if textFlags & MIDSIZE ~= 0 then
    textY = centerY - 19 -- Feinkorrektur MIDSIZE
  else
    textY = centerY - 10 -- Feinkorrektur normale Größe
  end

  -- Schatten zeichnen
  lcd.drawText(textX + 2, textY + 2, numText, textFlags + widget.options.Shadow)
  -- Text zeichnen
  lcd.drawText(textX, textY, numText, textFlags + widget.options.Text)

  local unitX = textX + numWidth - 1
  lcd.drawText(unitX, textY + 4, unitText, SMLSIZE + widget.options.Text)
end

-- Widget erzeugen
local function create(zone, options)
  return { zone = zone or { x=0, y=0, w=100, h=30 }, options = options }
end

-- Widget aktualisieren
local function update(widget, options)
  widget.options = options
end

-- Widget zeichnen / refresh
local function refresh(widget)
  -- Zellenanzahl korrekt begrenzen
  widget.options.Cells = math.max(1, math.min(widget.options.Cells or 2, 8))

  -- Spannungsquelle wählen
  local rawVoltage
  if widget.options.tx_voltage__RxBt == 0 then
    rawVoltage = getValue("tx-voltage") or 0
  else
    rawVoltage = getValue("RxBt") or 0
  end

  local voltage = rawVoltage
  local lowlimit, full

  if widget.options.PerCell == 1 then
    voltage = voltage / widget.options.Cells
    lowlimit = 3.2
    full = 4.2
  else
    lowlimit = 3.2 * widget.options.Cells
    full = 4.2 * widget.options.Cells
  end

  local percent = getVoltagePercent(voltage, lowlimit, full)
  local color = getBatteryColor(percent, widget)

  local x = tonumber(widget.zone.x) or 0
  local y = tonumber(widget.zone.y) or 0
  local w = tonumber(widget.zone.w) or 100
  local h = tonumber(widget.zone.h) or 30

  drawBattery(x, y, w, h, voltage, percent, color, widget)
end

return {
  name = "BattMeter",
  options = options,
  create = create,
  update = update,
  refresh = refresh
}
