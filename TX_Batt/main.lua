local options = {
  { "PerCell", BOOL, 1 },
  { "Text", COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow", COLOR, lcd.RGB(80, 80, 80) },
  { "Full", COLOR, lcd.RGB(0, 170, 0) },
  { "High", COLOR, lcd.RGB(80, 170, 0) },
  { "Medium", COLOR, lcd.RGB(150, 150, 0) },
  { "Low", COLOR, lcd.RGB(255, 165, 0) },
  { "Empty", COLOR, lcd.RGB(255, 0, 0) },
  { "Frame", COLOR, lcd.RGB(200, 200, 200) }, -- heller Rahmen
  { "EmptyBar", COLOR, lcd.RGB(50, 50, 50) }
}

local function getBatteryColor(percent, opts)
  if percent >= 80 then return opts.Full end
  if percent >= 60 then return opts.High end
  if percent >= 40 then return opts.Medium end
  if percent >= 20 then return opts.Low end
  return opts.Empty
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
  local capW = math.max(2, math.floor(frameW * 0.06))  -- etwas schmaler
  local bodyW = frameW - capW - 2
  local bodyH = frameH
  local capH = math.floor(bodyH * 0.35) -- etwas kürzer

  -- Batterie-Rahmen & Hintergrund
  lcd.drawRectangle(frameX, frameY, bodyW, bodyH, SOLID, opts.Frame)
  lcd.drawFilledRectangle(frameX + 1, frameY + 1, bodyW - 2, bodyH - 2, opts.EmptyBar)

  -- Pluspol
  local capX = frameX + bodyW
  local capY = frameY + (bodyH - capH) // 2
  lcd.drawFilledRectangle(capX, capY, capW, capH, opts.Frame)

  -- Füllung
  local fillW = math.floor((bodyW - 4) * percent / 100)
  if fillW > 0 then
    lcd.drawFilledRectangle(frameX + 2, frameY + 2, fillW, bodyH - 4, color)
  end

  -- Text (groß + kleines "V")
  local numText = string.format("%.1f", voltage)
  local unitText = "V"
  local numWidth = textWidth(numText, MIDSIZE + BOLD)
  local unitWidth = textWidth(unitText, SMLSIZE)
  local totalWidth = numWidth + unitWidth

  local textX = frameX + (bodyW - totalWidth) // 2
  local textY = frameY + (bodyH - 16) // 2 - 11  -- leicht höher gesetzt

  lcd.drawText(textX + 1, textY + 1, numText, MIDSIZE + BOLD + opts.Shadow)
  lcd.drawText(textX, textY, numText, MIDSIZE + BOLD + opts.Text)

  local unitX = textX + numWidth - 1 -- näher an Zahl
  lcd.drawText(unitX, textY + 4, unitText, SMLSIZE + opts.Text)
end

local function create(zone, _options)
  return { zone = zone, options = _options }
end

local function update(widget, _options)
  widget.options = _options
end

local function refresh(widget)
  local rawVoltage = getValue("tx-voltage") or 0

  local opts = {}
  for _, def in ipairs(options) do
    opts[def[1]] = widget.options[def[1]]
  end

  local voltage = rawVoltage
  local lowlimit = 6.4
  local full = 8.4
  if opts.PerCell == 1 then
    voltage = voltage / 2
    lowlimit = 3.2
    full = 4.2
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
  name = "TX_Batt",
  options = options,
  create = create,
  update = update,
  refresh = refresh
}
