-- /WIDGETS/BattMeter/main.lua
-- BattMeter Widget
-- Copyright (C) 2025 Calari + Grok

local DEBUG = true  -- auf false setzen wenn alles läuft

local function dbg(msg) if DEBUG then print("[BattMeter] " .. msg) end end

-- Batterie-Typen: { minV, maxV, thFull, thHigh, thMedium, thLow }
local BATT_TYPES = {
  [1] = { minV = 3.20, maxV = 4.20, thFull = 80, thHigh = 60, thMedium = 40, thLow = 20 },  -- Li-Po
  [2] = { minV = 3.00, maxV = 4.20, thFull = 80, thHigh = 60, thMedium = 40, thLow = 20 },  -- Li-Ion
  [3] = { minV = 2.80, maxV = 3.60, thFull = 80, thHigh = 60, thMedium = 40, thLow = 20 },  -- LiFe
}

local options = {
  { "Battery-Sensor", CHOICE, 1, {"tx-voltage", "RxBt"} },      -- 1 = tx-voltage, 2 = RxBt
  { "Battery-Type",   CHOICE, 1, {"Li-Po", "Li-Ion", "LiFe"} }, -- 1 / 2 / 3
  { "Cells",          VALUE,  2, 1, 8 },
  { "PerCell",        BOOL,   1 },
  { "Text",           COLOR,  lcd.RGB(255, 255, 255) },
  { "Shadow",         COLOR,  lcd.RGB(80, 80, 80) },
  { "BatColor",       COLOR,  lcd.RGB(30, 30, 30) },
  { "Full",           COLOR,  lcd.RGB(0, 170, 0) },
  { "High",           COLOR,  lcd.RGB(80, 170, 0) },
  { "Medium",         COLOR,  lcd.RGB(150, 150, 0) },
  { "Low",            COLOR,  lcd.RGB(255, 165, 0) },
  { "Critical",       COLOR,  lcd.RGB(255, 0, 0) }
}

local MIN_FILL = 8

local function getBatteryColor(percent, btype, widget)
  if percent >= btype.thFull   then return widget.options.Full     end
  if percent >= btype.thHigh   then return widget.options.High     end
  if percent >= btype.thMedium then return widget.options.Medium   end
  if percent >= btype.thLow    then return widget.options.Low      end
  return widget.options.Critical
end

local function getVoltagePercent(voltage, minV, maxV)
  if maxV <= minV or voltage <= 0 then return 0 end
  local percent = math.floor(((voltage - minV) / (maxV - minV)) * 100 + 0.5)
  return math.max(0, math.min(100, percent))
end

local function drawBattery(frameX, frameY, frameW, frameH, voltage, percent, color, widget)
  local capW  = math.max(6, math.floor(frameW * 0.07))
  local bodyW = frameW - capW - 2
  local bodyH = frameH
  local capH  = math.floor(bodyH * 0.38)

  -- Batteriekörper
  lcd.drawFilledRectangle(frameX + 1, frameY + 1, bodyW - 2, bodyH - 2, widget.options.BatColor)

  -- Pluspol
  lcd.drawFilledRectangle(frameX + bodyW - 1, frameY + (bodyH - capH) // 2, capW, capH, widget.options.BatColor)

  -- Füllung
  local fillW = math.max(MIN_FILL, math.floor((bodyW - 6) * percent / 100))
  lcd.drawFilledRectangle(frameX + 3, frameY + 3, fillW, bodyH - 6, color)

  -- Text
  local textFlags  = (voltage < 10) and (MIDSIZE + BOLD) or BOLD
  local numText    = string.format("%.1f", voltage)
  local unitText   = "V"
  local numWidth   = lcd.getTextWidth and lcd.getTextWidth(textFlags, numText) or lcd.sizeText(numText, textFlags)
  local unitWidth  = lcd.getTextWidth and lcd.getTextWidth(SMLSIZE, unitText)  or lcd.sizeText(unitText, SMLSIZE)
  local totalWidth = numWidth + unitWidth
  local textX      = frameX + (bodyW - totalWidth) // 2
  local textY      = frameY + (bodyH // 2) - (textFlags & MIDSIZE ~= 0 and 19 or 11)

  lcd.drawText(textX + 2,            textY + 2, numText,  textFlags + widget.options.Shadow)
  lcd.drawText(textX,                textY,     numText,  textFlags + widget.options.Text)
  lcd.drawText(textX + numWidth + 2, textY + 4, unitText, SMLSIZE   + widget.options.Text)
end

local function drawNoSensor(frameX, frameY, frameW, frameH, widget)
  local msg   = "No sensor!"
  local msgW  = lcd.getTextWidth and lcd.getTextWidth(SMLSIZE, msg) or lcd.sizeText(msg, SMLSIZE)
  local textX = frameX + (frameW - msgW) // 2
  local textY = frameY + (frameH // 2) - 12
  lcd.drawText(textX + 2, textY + 2, msg, SMLSIZE + widget.options.Shadow)
  lcd.drawText(textX,     textY,     msg, SMLSIZE + lcd.RGB(255, 0, 0))
end

local function create(zone, options)
  return { zone = zone, options = options }
end

local function update(widget, options)
  widget.options = options
end

local function refresh(widget)
  local opts   = widget.options
  local sensor = opts["Battery-Sensor"]
  local btype  = BATT_TYPES[opts["Battery-Type"]] or BATT_TYPES[1]
  local cells  = math.max(1, opts.Cells or 1)  -- minimum 1, nie division durch 0

  local x = tonumber(widget.zone.x) or 0
  local y = tonumber(widget.zone.y) or 0
  local w = tonumber(widget.zone.w) or 100
  local h = tonumber(widget.zone.h) or 30

  dbg("sensor-index=" .. tostring(sensor) ..
      "  battery-type=" .. tostring(opts["Battery-Type"]) ..
      "  cells=" .. tostring(cells) ..
      "  minV=" .. btype.minV .. "  maxV=" .. btype.maxV)

  if sensor == nil or (sensor ~= 1 and sensor ~= 2) then
    dbg("ERROR: ungültiger sensor-index!")
    drawNoSensor(x, y, w, h, widget)
    return
  end

  local sensorName = (sensor == 1) and "tx-voltage" or "RxBt"
  local rawVoltage = getValue(sensorName)

  dbg("sensorName=" .. sensorName .. "  rawVoltage=" .. tostring(rawVoltage))
  dbg("PerCell=" .. tostring(opts.PerCell) .. "  Cells=" .. tostring(cells))

  if rawVoltage == nil or type(rawVoltage) ~= "number" then
    dbg("ERROR: kein gültiger Wert von sensor '" .. sensorName .. "'")
    drawNoSensor(x, y, w, h, widget)
    return
  end

  local voltage    = rawVoltage
  local minV, maxV = btype.minV, btype.maxV

  if opts.PerCell == 1 then
    voltage = rawVoltage / cells
  else
    minV = minV * cells
    maxV = maxV * cells
  end

  local percent = getVoltagePercent(voltage, minV, maxV)
  local color   = getBatteryColor(percent, btype, widget)

  dbg("voltage=" .. string.format("%.2f", voltage) ..
      "V  minV=" .. string.format("%.2f", minV) ..
      "  maxV=" .. string.format("%.2f", maxV) ..
      "  percent=" .. tostring(percent) .. "%")

  drawBattery(x, y, w, h, voltage, percent, color, widget)
end

return {
  name    = "BattMeter",
  options = options,
  create  = create,
  update  = update,
  refresh = refresh
}
