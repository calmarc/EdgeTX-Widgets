local options = {
  { "ShowPercent", BOOL, 1 },
  { "Text", COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow", COLOR, lcd.RGB(85, 85, 85) },
  { "Low", COLOR, lcd.RGB(255, 0, 0) },        -- 0–60 %
  { "Medium", COLOR, lcd.RGB(255, 165, 0) },   -- 60–90 %
  { "High", COLOR, lcd.RGB(0, 255, 0) },       -- 90–100 %
  { "Empty", COLOR, lcd.RGB(220, 220, 220) }   -- Nicht aktive Balken
}


local COLOR_BASE = 200

local function normalizeRSSI(rssi)
  if not rssi then return 0 end

  -- Begrenzung
  if rssi <= -110 then return 0 end
  if rssi >= -50 then return 100 end

  -- Sanfte Kurve im Bereich -110 bis -50
  local x = (rssi + 110) / 60  -- normiert in 0..1
  local curved = x ^ 1.5       -- nichtlinear, verstärkt Unterschiede im unteren Bereich

  return math.floor(curved * 100 + 0.5)
end

local function getBestRSSI()
  local r1 = getValue("1RSS")
  local r2 = getValue("2RSS")
  local r = getValue("RSSI")

  local best = nil
  if r1 and r1 ~= 0 then best = r1 end
  if r2 and r2 ~= 0 and (not best or r2 > best) then best = r2 end
  if r and r ~= 0 and (not best or r > best) then best = r end

  if best then
    return normalizeRSSI(best)
  end

  return nil
end

local function clampPercent(value)
  value = tonumber(value) or 0
  return math.min(100, math.max(0, math.floor(value)))
end

local function getSignalValue()
  local tq = getValue("TQly")
  local rssiNorm = getBestRSSI()

  if tq and rssiNorm then
    local tqClamped = clampPercent(tq)

    -- Gewichtung: TQly dominiert
    local weightTQ = 0.8
    local weightRSSI = 0.2

    local result = weightTQ * tqClamped + weightRSSI * rssiNorm
    return math.floor(result + 0.5)
  elseif tq then
    return clampPercent(tq)
  elseif rssiNorm then
    return rssiNorm
  else
    return 0
  end
end

local function estimateTextWidth(text)
  return #text * 5
end

local function drawBars(x, y, w, h, percent, opts)
  local bars = 9
  local gap = 1
  local barWidth = math.floor((w - (bars - 1) * gap) / bars)
  local maxBarHeight = h - 4

  local filledBars
  if percent > 97 then
    filledBars = 9
  else
    filledBars = math.floor(percent / (100 / bars))
  end

  for i = 1, bars do
    local barHeight = math.floor(i * maxBarHeight / bars)
    local barX = x + (i - 1) * (barWidth + gap)
    local barY = y + h - barHeight

    local color
    if i <= filledBars then
      if percent >= 92 then
        color = opts.High
      elseif percent >= 80 then
        color = opts.Medium
      else
        color = opts.Low
      end
    else
      color = opts.Empty
    end

    lcd.setColor(COLOR_BASE + i, color)
    lcd.drawFilledRectangle(barX, barY, barWidth, barHeight, COLOR_BASE + i)
  end
end

local function drawPercentText(x, y, percent, opts)
  local text = string.format("%d", percent)
  lcd.setColor(COLOR_BASE + 50, opts.Text or lcd.RGB(255, 255, 255))
  lcd.drawText(x+2, y+2, text, SMLSIZE + BOLD + opts.Shadow)
  lcd.drawText(x, y, text, SMLSIZE + BOLD, COLOR_BASE + 50)
end

local function refresh(widget)
  local opts = {}
  for _, def in ipairs(options) do
    opts[def[1]] = widget.options[def[1]]
  end

  local signal = getSignalValue()
  local percent = clampPercent(signal)

  local x = widget.zone.x or 0
  local y = widget.zone.y or 0
  local w = widget.zone.w or 100
  local h = widget.zone.h or 40

  drawBars(x, y, w, h, percent, opts)

  if opts.ShowPercent == 1 then
    drawPercentText(x, y, percent, opts)
  end
end

return {
  name = "LQ_Qual",
  options = options,
  create = function(zone, options) return { zone = zone, options = options } end,
  update = function(widget, options) widget.options = options end,
  refresh = refresh
}
