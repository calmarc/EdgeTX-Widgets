-- /WIDGETS/BattMeter/main.lua
-- BattMeter Widget
-- Copyright (C) 2026 Calari

-- Sensor-Map: CHOICE index → sensor name
local SENSOR_MAP = {
  [1] = "tx-voltage",
  [2] = "RxBt"
}

-- Batterie-Typen: { minV, maxV, state rules }
-- STATE_RULES: geordnet von hoch nach tief, { threshold%, state }
local BATT_TYPES = {
  [1] = {                                          -- Li-Po
    minV = 3.20, maxV = 4.20,
    rules = {
      { threshold = 80, state = "FULL"     },
      { threshold = 60, state = "HIGH"     },
      { threshold = 40, state = "MEDIUM"   },
      { threshold = 20, state = "LOW"      },
      { threshold =  0, state = "CRITICAL" },
    }
  },
  [2] = {                                          -- Li-Ion
    minV = 3.00, maxV = 4.20,
    rules = {
      { threshold = 80, state = "FULL"     },
      { threshold = 60, state = "HIGH"     },
      { threshold = 40, state = "MEDIUM"   },
      { threshold = 20, state = "LOW"      },
      { threshold =  0, state = "CRITICAL" },
    }
  },
  [3] = {                                          -- LiFe
    minV = 2.80, maxV = 3.60,
    rules = {
      { threshold = 80, state = "FULL"     },
      { threshold = 60, state = "HIGH"     },
      { threshold = 40, state = "MEDIUM"   },
      { threshold = 20, state = "LOW"      },
      { threshold =  0, state = "CRITICAL" },
    }
  },
}

-- Font-Profile: kalibriert auf gemessene Zonengrössen
-- baseline: empirisch ermittelt (h=39 Zone → 40 ergibt korrekte Y-Zentrierung)
local FONT_PROFILES = {
  large  = { flags = MIDSIZE + BOLD, baseline = 40 },  -- bodyH >= 35, kalibriert h=39
  medium = { flags = BOLD,           baseline = 13 },  -- bodyH >= 22
  small  = { flags = SMLSIZE + BOLD, baseline =  9 },  -- bodyH <  22
}

-- Smoothing: moving average über N samples
local SMOOTH_SAMPLES = 5
local voltageHistory = {}

local options = {
  { "Battery-Sensor", CHOICE, 1, {"tx-voltage", "RxBt"} },      -- 1 / 2
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

-- LCD text width helper
local function textWidth(flags, text)
  if lcd.getTextWidth then
    return lcd.getTextWidth(flags, text)
  else
    return lcd.sizeText(text, flags)
  end
end

-- ─── Smoothing ────────────────────────────────────────────────────────────────

local function smoothVoltage(key, newValue)
  if not voltageHistory[key] then
    voltageHistory[key] = {}
  end
  local h = voltageHistory[key]
  table.insert(h, newValue)
  if #h > SMOOTH_SAMPLES then
    table.remove(h, 1)
  end
  local sum = 0
  for _, v in ipairs(h) do sum = sum + v end
  return sum / #h
end

-- ─── Pipeline: 1) Sensor lesen ───────────────────────────────────────────────

local function readSensor(opts)
  local sensorName = SENSOR_MAP[opts["Battery-Sensor"]]
  if not sensorName then
    return nil
  end
  local raw = getValue(sensorName)
  if raw == nil or type(raw) ~= "number" or raw <= 0 or raw > 60 then
    return nil
  end
  local smoothed = smoothVoltage(sensorName, raw)
  return { name = sensorName, raw = raw, voltage = smoothed }
end

-- ─── Pipeline: 2) Spannung normalisieren ─────────────────────────────────────

local function normalizeVoltage(voltage, btype, cells, isPerCell)
  local minV, maxV = btype.minV, btype.maxV
  if isPerCell then
    voltage = voltage / cells
  else
    minV = minV * cells
    maxV = maxV * cells
  end
  return voltage, minV, maxV
end

-- ─── Pipeline: 3a) Prozent berechnen ─────────────────────────────────────────

local function computePercent(voltage, minV, maxV)
  if maxV <= minV or voltage <= 0 then return 0 end
  local p = ((voltage - minV) / (maxV - minV)) * 100
  return math.max(0, math.min(100, math.floor(p + 0.5)))
end

-- ─── Pipeline: 3b) State aus Prozent (table-driven) ──────────────────────────

local function computeStateFromPercent(percent, rules)
  for _, rule in ipairs(rules) do
    if percent >= rule.threshold then
      return rule.state
    end
  end
  return "CRITICAL"
end

-- ─── Pipeline: 4) Rendern ────────────────────────────────────────────────────

local function getColorForState(state, widget)
  if state == "FULL"   then return widget.options.Full     end
  if state == "HIGH"   then return widget.options.High     end
  if state == "MEDIUM" then return widget.options.Medium   end
  if state == "LOW"    then return widget.options.Low      end
  return widget.options.Critical
end

local function getFontProfile(bodyH)
  if bodyH >= 35 then return FONT_PROFILES.large  end
  if bodyH >= 22 then return FONT_PROFILES.medium end
  return FONT_PROFILES.small
end

local function drawNoSensor(frameX, frameY, frameW, frameH, widget)
  local msg   = "No sensor!"
  local msgW  = textWidth(SMLSIZE, msg)
  local textX = frameX + math.floor((frameW - msgW) / 2)
  local textY = frameY + math.floor(frameH / 2) - 8
  lcd.drawText(textX + 2, textY + 2, msg, SMLSIZE + widget.options.Shadow)
  lcd.drawText(textX,     textY,     msg, SMLSIZE + lcd.RGB(255, 0, 0))
end

local function drawBattery(frameX, frameY, frameW, frameH, voltage, percent, color, widget)
  local capW  = math.max(6, math.floor(frameW * 0.07))
  local bodyW = frameW - capW - 2
  local bodyH = frameH
  local capH  = math.floor(bodyH * 0.38)

  -- Batteriekörper
  lcd.drawFilledRectangle(frameX + 1, frameY + 1, bodyW - 2, bodyH - 2, widget.options.BatColor)

  -- Pluspol
  lcd.drawFilledRectangle(
    frameX + bodyW - 1,
    frameY + math.floor((bodyH - capH) / 2),
    capW, capH,
    widget.options.BatColor
  )

  -- Füllung: geclampt, kein fake Ladestand
  local maxFill = bodyW - 6
  local fillW   = math.max(0, math.min(maxFill, math.floor(maxFill * percent / 100)))
  lcd.drawFilledRectangle(frameX + 3, frameY + 3, fillW, bodyH - 6, color)

  -- Font abhängig von bodyH
  local font     = getFontProfile(bodyH)
  local numText  = string.format("%.1f", voltage)
  local unitText = "V"
  local numW     = textWidth(font.flags, numText)
  local unitW    = textWidth(SMLSIZE,    unitText)
  local textX    = frameX + math.floor((bodyW - numW - unitW) / 2)
  local textY    = frameY + math.floor((bodyH - font.baseline) / 2)

  lcd.drawText(textX + 2,        textY + 2, numText,  font.flags + widget.options.Shadow)
  lcd.drawText(textX,            textY,     numText,  font.flags + widget.options.Text)
  lcd.drawText(textX + numW + 2, textY + 2, unitText, SMLSIZE    + widget.options.Text)
end

-- ─── Widget Lifecycle ─────────────────────────────────────────────────────────

local function create(zone, options)
  return { zone = zone, options = options }
end

local function update(widget, options)
  widget.options = options
end

local function refresh(widget)
  local opts      = widget.options
  local btype     = BATT_TYPES[opts["Battery-Type"]] or BATT_TYPES[1]
  local cells     = math.max(1, opts.Cells or 1)
  local isPerCell = (opts.PerCell == 1)

  local x = tonumber(widget.zone.x) or 0
  local y = tonumber(widget.zone.y) or 0
  local w = tonumber(widget.zone.w) or 100
  local h = tonumber(widget.zone.h) or 30

  -- 1) Sensor lesen + smoothing
  local sensor = readSensor(opts)
  if not sensor then
    drawNoSensor(x, y, w, h, widget)
    return
  end

  -- 2) Normalisieren
  local voltage, minV, maxV = normalizeVoltage(sensor.voltage, btype, cells, isPerCell)

  -- 3a) Prozent
  local percent = computePercent(voltage, minV, maxV)

  -- 3b) State (table-driven)
  local state = computeStateFromPercent(percent, btype.rules)

  -- 4) Rendern
  local color = getColorForState(state, widget)
  drawBattery(x, y, w, h, voltage, percent, color, widget)
end

return {
  name    = "BattMeter",
  options = options,
  create  = create,
  update  = update,
  refresh = refresh
}
