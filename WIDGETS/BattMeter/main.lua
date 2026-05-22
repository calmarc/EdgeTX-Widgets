-- /WIDGETS/BattMeter/main.lua
-- BattMeter Widget
-- Copyright (C) 2025 Calari + Grok

local options = {
  { "tx_voltage__RxBt", BOOL, 0 },     -- 0 = Sender Akku (tx-voltage), 1 = Empfänger Akku (RxBt)
  { "Cells",            VALUE, 2, 1, 8 },
  { "PerCell",          BOOL,  1 },     -- 1 = pro Zelle, 0 = Gesamtspannung
  { "Text",             COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow",           COLOR, lcd.RGB(80, 80, 80) },
  { "BatColor",         COLOR, lcd.RGB(30, 30, 30) },
  { "Full",             COLOR, lcd.RGB(0, 170, 0) },
  { "High",             COLOR, lcd.RGB(80, 170, 0) },
  { "Medium",           COLOR, lcd.RGB(150, 150, 0) },
  { "Low",              COLOR, lcd.RGB(255, 165, 0) }
}

local MIN_FILL = 8

local function getBatteryColor(percent, widget)
  if percent >= 80 then return widget.options.Full end
  if percent >= 60 then return widget.options.High end
  if percent >= 40 then return widget.options.Medium end
  if percent >= 20 then return widget.options.Low end
  return widget.options.BatColor
end

local function getVoltagePercent(voltage, minV, maxV)
  if maxV <= minV or voltage <= 0 then return 0 end
  local percent = math.floor(((voltage - minV) / (maxV - minV)) * 100 + 0.5)
  return math.max(0, math.min(100, percent))
end

local function drawBattery(frameX, frameY, frameW, frameH, voltage, percent, color, widget)
  local capW = math.max(6, math.floor(frameW * 0.07))
  local bodyW = frameW - capW - 2
  local bodyH = frameH
  local capH = math.floor(bodyH * 0.38)

  -- Batteriekörper
  lcd.drawFilledRectangle(frameX + 1, frameY + 1, bodyW - 2, bodyH - 2, widget.options.BatColor)
  
  -- Pluspol
  lcd.drawFilledRectangle(frameX + bodyW - 1, frameY + (bodyH - capH)//2, capW, capH, widget.options.BatColor)

  -- Füllung
  local fillW = math.max(MIN_FILL, math.floor((bodyW - 6) * percent / 100))
  lcd.drawFilledRectangle(frameX + 3, frameY + 3, fillW, bodyH - 6, color)

  -- Text
  local textFlags = (voltage < 10) and (MIDSIZE + BOLD) or BOLD
  local numText = string.format("%.1f", voltage)
  local unitText = "V"

  local numWidth = lcd.getTextWidth and lcd.getTextWidth(textFlags, numText) or lcd.sizeText(numText, textFlags)
  local unitWidth = lcd.getTextWidth and lcd.getTextWidth(SMLSIZE, unitText) or lcd.sizeText(unitText, SMLSIZE)

  local totalWidth = numWidth + unitWidth
  local textX = frameX + (bodyW - totalWidth) // 2
  local textY = frameY + (bodyH // 2) - (textFlags & MIDSIZE ~= 0 and 19 or 11)

  -- Schatten
  lcd.drawText(textX + 2, textY + 2, numText, textFlags + widget.options.Shadow)
  -- Haupttext
  lcd.drawText(textX, textY, numText, textFlags + widget.options.Text)
  lcd.drawText(textX + numWidth + 2, textY + 4, unitText, SMLSIZE + widget.options.Text)
end

local function create(zone, options)
  return { zone = zone, options = options }
end

local function update(widget, options)
  widget.options = options
end

local function refresh(widget)
  local opts = widget.options

  local rawVoltage = opts.tx_voltage__RxBt == 0
                    and (getValue("tx-voltage") or 0)
                    or  (getValue("RxBt") or 0)

  local voltage = rawVoltage
  local minV, maxV = 3.2, 4.25

  if opts.PerCell == 1 then
    voltage = rawVoltage / opts.Cells
  else
    minV = minV * opts.Cells
    maxV = maxV * opts.Cells
  end

  local percent = getVoltagePercent(voltage, minV, maxV)
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
