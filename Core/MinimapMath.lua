-- Minimap button placement (v0.6.1). Pure math, so the harness can test it.
-- The button sits on the minimap rim at an angle (degrees, 0 = east, counter-clockwise).
-- Square and partly-square minimaps (GetMinimapShape) put it on the edge instead.
local _, ns = ...

local MM = {}
ns.MinimapMath = MM

MM.DEFAULT_ANGLE = 225 -- lower left, clear of the clock and the tracking button
MM.RADIUS_PAD = 5

-- Which quadrants are round: q1 = bottom-right ... same order as LibDBIcon uses.
-- Quadrant: 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0).
MM.SHAPES = {
  ROUND = { true, true, true, true },
  SQUARE = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

function MM.Normalize(angle)
  angle = tonumber(angle) or MM.DEFAULT_ANGLE
  if angle ~= angle then angle = MM.DEFAULT_ANGLE end -- NaN
  return angle % 360
end

-- Offset of the button center from the minimap center.
function MM.Position(angle, shape, minimapWidth)
  local rad = math.rad(MM.Normalize(angle))
  local x, y = math.cos(rad), math.sin(rad)
  local q = 1
  if x < 0 then q = q + 1 end
  if y > 0 then q = q + 2 end
  local r = (tonumber(minimapWidth) or 140) / 2 + MM.RADIUS_PAD
  local quad = MM.SHAPES[shape or "ROUND"] or MM.SHAPES.ROUND
  if quad[q] then
    return x * r, y * r
  end
  local diag = math.sqrt(2 * r * r) - 10
  return math.max(-r, math.min(r, x * diag)), math.max(-r, math.min(r, y * diag))
end

-- Angle (degrees) of a point relative to the minimap center (cursor while dragging).
function MM.AngleFrom(dx, dy)
  if (dx or 0) == 0 and (dy or 0) == 0 then return MM.DEFAULT_ANGLE end
  local atan2 = math.atan2 or function(a, b) return math.atan(a, b) end
  return MM.Normalize(math.deg(atan2(dy, dx)))
end
