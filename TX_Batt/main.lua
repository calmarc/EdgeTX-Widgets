local options = {
  { "PerCell", BOOL, 1 },
  { "Text", COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow", COLOR, lcd.RGB(80, 80, 80) },
  { "Full", COLOR, lcd.RGB(0, 170, 0) },
  { "High", COLOR, lcd.RGB(80, 170, 0) },
  { "Medium", COLOR, lcd.RGB(150, 150, 0) },
  { "Low", COLOR, lcd.RGB(255, 165, 0) },
  { "Empty", COLOR, lcd.RGB(255, 0, 0) },
  { "Frame", COLOR, lcd.RGB(180, 180, 180) },
  { "EmptyBar", COLOR, lcd.RGB(50, 50, 50) }
}

local BAT_COLOR_INDEX = 0

local function getBatteryColor(percent, opts)
  percent = tonumber(percent)
  if not percent or percent < 0 or percent > 100 then
    print("⚠️ Invalid percentage value:", tostring(percent))
    return lcd.RGB(255, 255, 255)
  end
  if percent >= 80 then return opts.Full end
  if percent >= 60 then return opts.High end
  if percent >= 40 then return opts.Medium end
  if percent >= 20 then return opts.Low end
  return opts.Empty
end

local function getVoltagePercent(voltage, minV, maxV)
  local v = tonumber(voltage) or 0
  local percent = math.floor((v - minV) / (maxV - minV) * 100)
  return math.min(100, math.max(0, percent))
end

local function safeSetColor(index, color)
  if type(color) ~= "number" then
    print("⚠️ Invalid or nil color, falling back to white")
    color = lcd.RGB(255, 255, 255)
  end
  lcd.setColor(index, color)
end

local function estimateTextWidth(text, size)
  local avgCharW = (size == SMLSIZE) and 5 or 6
  return #text * avgCharW
end

local function drawBattery(x, y, zoneW, zoneH, percent, color, voltage, opts)
  local levels = 8
  local barGap = 1

  local barWidth = math.max(4, math.floor((zoneW - 20) / levels - barGap))
  local barHeight = math.max(8, zoneH - 8)

  local marginX = 3
  local marginY = 1

  local totalGap = (levels - 1) * barGap
  local totalWidth = levels * barWidth + totalGap + 2 * marginX
  local totalHeight = barHeight + 2 * marginY

  local filled = math.floor((tonumber(percent) or 0) * levels / 100)

  local frameX = x
  local frameY = y
  local frameW = totalWidth + 6
  local frameH = totalHeight + 6

  -- Outer contrast frame
  safeSetColor(BAT_COLOR_INDEX + 10, color)
  lcd.drawRectangle(frameX, frameY, frameW, frameH, BAT_COLOR_INDEX + 10)

  -- Battery frame (thick)
  safeSetColor(BAT_COLOR_INDEX, color)
  lcd.drawRectangle(frameX + 1, frameY + 1, frameW - 2, frameH - 2, BAT_COLOR_INDEX)
  lcd.drawRectangle(frameX + 2, frameY + 2, frameW - 4, frameH - 4, BAT_COLOR_INDEX)

  -- Battery bars
  local barX = frameX + marginX + 3
  local barY = frameY + marginY + 3
  for i = 0, levels - 1 do
    local thisX = barX + i * (barWidth + barGap)
    local barColor = (i < filled) and color or opts.EmptyBar
    safeSetColor(BAT_COLOR_INDEX + 1 + i, barColor)
    lcd.drawFilledRectangle(thisX, barY, barWidth, barHeight, BAT_COLOR_INDEX + 1 + i)
  end

  -- Battery positive terminal
  local capW = 4
  local capH = math.max(2, math.floor(totalHeight / 3))
  local capX = frameX + frameW
  local capY = frameY + (frameH - capH) // 2
  safeSetColor(BAT_COLOR_INDEX + 20, color)
  lcd.drawFilledRectangle(capX, capY, capW, capH, BAT_COLOR_INDEX + 20)
  lcd.drawRectangle(capX, capY, capW, capH, BAT_COLOR_INDEX + 10)

  -- Voltage text
  local text = string.format("%.1fV", voltage)
  local textWidth = estimateTextWidth(text, SMLSIZE)
  local textX = frameX + (frameW - textWidth) // 2 - 14
  local textY = frameY + 6
  lcd.drawText(textX + 2, textY + 2, text, SMLSIZE + BOLD + opts.Shadow)
  lcd.drawText(textX, textY, text, SMLSIZE + BOLD + opts.Text)
end

local function create(zone, _options)
  return { zone = zone, options = _options }
end

local function update(widget, _options)
  widget.options = _options
end

local function refresh(widget)
  local rawVoltage = getValue("tx-voltage") or 0

  -- Read options into table
  local opts = {}
  for _, def in ipairs(options) do
    opts[def[1]] = widget.options[def[1]]
  end

  -- Adjust voltage and thresholds depending on per-cell setting
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

  drawBattery(x, y, w, h, percent, color, voltage, opts)
end

return {
  name = "TX_Batt",
  options = options,
  create = create,
  update = update,
  refresh = refresh
}
