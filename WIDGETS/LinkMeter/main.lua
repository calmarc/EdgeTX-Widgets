-- /WIDGETS/LinkMeter/main.lua
-- LinkMeter Widget
-- Version: 0.40
-- Copyright (C) 2025 Calari
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- Changelog:
--   0.51  log10-RSSI-Kurve statt x²; dual-scale fix (fill und Geometrie
--         auf gleicher Skala); denom-Refactor; Shadow-Hardening via
--         HAS_NATIVE_SHADOW; Debug-Flag; string.format → concat.

-- ─── Konstanten ─────────────────────────────────────────────────────────────
local GAP           = 1
local MIN_HEIGHT    = 6
local GROWTH_FACTOR = 2.0
local SHADOW_OFFSET = 1
local TEXT_OFFSET_X = 4
local TEXT_OFFSET_Y = 2
local ZONE_Y_ADJUST = -2   -- empirische Korrektur: EdgeTX-Zonen starten 2px zu tief

local RSSI_MIN = -110   -- dBm → 0 %
local RSSI_MAX = -50    -- dBm → 100 %

-- Gewichtung des heuristischen UX-Scores (kein RF-Diagnosemodell):
--   RQly  = diskrete Paketverlustrate       (dominant)
--   RSSI  = analoger HF-Pegel, normalisiert  (ergänzend)
local LINK_SCORE_WEIGHT_RQ   = 0.8
local LINK_SCORE_WEIGHT_RSSI = 0.2

-- Debug-Mode: bei true wird ein Fehlertext bei ungültiger Zone gezeichnet.
-- Im Feldbetrieb auf false setzen, um fremde Widgets nicht zu überdecken.
local DEBUG_MODE = false

local HAS_NATIVE_SHADOW = SHADOWED ~= nil

local options = {
  { "ShowPercent", BOOL,  1 },
  { "Text",        COLOR, lcd.RGB(255, 255, 255) },
  { "Shadow",      COLOR, lcd.RGB(85,  85,  85)  },
  { "BarCount",    VALUE, 10, 4, 22 },
  { "BarColor",    COLOR, lcd.RGB(30,  30,  30)  }, -- leere Balken
  { "Low",         COLOR, lcd.RGB(255,  0,   0)  }, -- < 80 %
  { "Medium",      COLOR, lcd.RGB(255, 165,  0)  }, -- 80–89 %
  { "High",        COLOR, lcd.RGB(0,  255,   0)  }  -- >= 90 %
}

-- ─── Signal-Layer ───────────────────────────────────────────────────────────

local function clampPercent(value)
  value = tonumber(value) or 0
  return math.max(0, math.min(100, math.floor(value)))
end

-- Logarithmische Sättigungskurve: log10(1 + 9x) bildet RF-Intuition besser
-- ab als quadratisch. Bleibt Heuristik – kein echtes Friis-Modell.
local function normalizeRSSI(rssi)
  local r = tonumber(rssi)
  if not r or r <= RSSI_MIN then return 0 end
  if r >= RSSI_MAX           then return 100 end
  local x = (r - RSSI_MIN) / (RSSI_MAX - RSSI_MIN)
  return math.floor(math.log10(1 + 9 * x) * 100 + 0.5)
end

-- Keine table-Allokation im hot path.
local function getBestRSSI()
  local v1 = getValue("1RSS")
  local v2 = getValue("2RSS")
  local v3 = getValue("RSSI")
  local best = 0
  if v1 and v1 ~= 0 then best = math.max(best, normalizeRSSI(v1)) end
  if v2 and v2 ~= 0 then best = math.max(best, normalizeRSSI(v2)) end
  if v3 and v3 ~= 0 then best = math.max(best, normalizeRSSI(v3)) end
  return best
end

-- Ergebnis: heuristischer UX-Score 0–100.
-- Geeignet für UI-Balken; NICHT für RF-Diagnose oder Systemtuning.
local function getSignalValue()
  local tq   = tonumber(getValue("RQly"))
  local rssi = getBestRSSI()
  if tq then
    return math.floor(
      LINK_SCORE_WEIGHT_RQ   * clampPercent(tq) +
      LINK_SCORE_WEIGHT_RSSI * rssi + 0.5
    )
  end
  return rssi
end

-- ─── Safety-Layer ───────────────────────────────────────────────────────────

local function safeZone(zone)
  if not zone then
    return { x = 0, y = 0, w = 0, h = 0 }
  end
  return {
    x = tonumber(zone.x) or 0,
    y = tonumber(zone.y) or 0,
    w = tonumber(zone.w) or 0,
    h = tonumber(zone.h) or 0,
  }
end

-- ─── Rendering-Layer ────────────────────────────────────────────────────────

local function drawBars(x, y, w, h, percent, widget)
  local bars = widget.options.BarCount

  local denom    = math.max(1, bars - 1)
  local barWidth = math.max(1, math.floor((w - (bars - 1) * GAP) / bars))
  local maxH     = h - 4

  -- filled nutzt dieselbe log10-Kurve wie die Balkenhöhen,
  -- damit fill state und Geometrie auf derselben Skala arbeiten.
  local fillX  = percent / 100
  local filled = math.floor(math.log10(1 + 9 * fillX) * bars + 0.5)

  local fillColor
  if percent < 80 then
    fillColor = widget.options.Low
  elseif percent < 90 then
    fillColor = widget.options.Medium
  else
    fillColor = widget.options.High
  end

  -- Nichtlineare ästhetische Progression: GROWTH_FACTOR komprimiert kleine
  -- Werte visuell – bewusster UX-Entscheid.
  for i = 1, bars do
    local factor    = (i - 1) / denom
    local barHeight = math.max(MIN_HEIGHT, math.ceil(
      MIN_HEIGHT + (maxH - MIN_HEIGHT) * (factor ^ GROWTH_FACTOR)
    ))
    if barHeight > maxH then barHeight = maxH end

    local barX  = x + (i - 1) * (barWidth + GAP)
    local barY  = y + h - barHeight
    local color = (i <= filled) and fillColor or widget.options.BarColor
    lcd.drawFilledRectangle(barX, barY, barWidth, barHeight, color)
  end
end

local function drawPercentText(x, y, percent, widget)
  local text = percent .. "%"
  if HAS_NATIVE_SHADOW then
    lcd.drawText(x, y, text, SMLSIZE + SHADOWED)
  else
    lcd.drawText(x + SHADOW_OFFSET, y + SHADOW_OFFSET, text, widget.options.Shadow)
    lcd.drawText(x,                 y,                  text, widget.options.Text)
  end
end

local function refresh(widget)
  local percent = clampPercent(getSignalValue())
  local z       = safeZone(widget.zone)

  if z.w <= 0 or z.h <= 0 then
    if DEBUG_MODE then
      lcd.drawText(0, 0, "LinkMeter: invalid zone", 0)
    end
    return
  end

  drawBars(z.x, z.y + ZONE_Y_ADJUST, z.w, z.h, percent, widget)
  if widget.options.ShowPercent == 1 then
    drawPercentText(
      z.x + TEXT_OFFSET_X,
      z.y + ZONE_Y_ADJUST + TEXT_OFFSET_Y,
      percent, widget
    )
  end
end

-- ─── Widget-API ─────────────────────────────────────────────────────────────

return {
  name    = "LinkMeter",
  options = options,
  create  = function(zone, opts) return { zone = zone, options = opts } end,
  update  = function(widget, opts) widget.options = opts end,
  refresh = refresh,
}
