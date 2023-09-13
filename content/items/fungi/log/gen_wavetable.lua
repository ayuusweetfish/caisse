local SAMPLE_RATE = 4000
local SAMPLE_DUR = 1 / SAMPLE_RATE

local tables = {}

tables.stringsTable = function (a)
  local Length = 1.5
  local N = math.floor(Length * SAMPLE_RATE)
  local function tone(i, F1)
    local t = i * SAMPLE_DUR
    local x = F1 * t
    local Y = 0
    -- Triangle + sine
    Y = Y + 0.5 * (0.5 - (x - math.floor(x))) / 0.5
    Y = Y + 0.5 * math.sin(x * math.pi * 2)
    -- Attack, release, vibrato
    Y = Y * (t < 0.20 and t / 0.20 or 1)
    Y = Y * (Length - t < 0.20 and (Length - t) / 0.20 or 1)
    Y = Y * (1 + math.sin(t / 0.7 * math.pi * 2) * 0.1)
    return Y
  end
  local Y1, Y2, Y3 = 0, 0, 0
  for i = 1, N do
    local Y = 0
    Y = Y + tone(i, 220)
    Y = Y + tone(i, 440)
    Y = Y + tone(i, 660)
    Y = Y + Y1 * 0.2 + Y2 * 0.1 + Y3 * 0.04
    Y1, Y2, Y3 = Y, Y1, Y2
    a[i] = Y / 4
  end
end

tables.kickTable = function (a)
--[[
  -- Chirp
  local F0 = 150
  local K = 0.1
  for i = 1, 400 do
    local t = i * SAMPLE_DUR
    a[i] = math.sin(2 * math.pi * F0 * ((K^t - 1) / math.log(K)))
      * ((400 - i) / 400)
  end
]]
  -- Fine-grained control over chirp
  local Length = 0.07
  local N = math.floor(Length * SAMPLE_RATE)
  local F1 = 1200
  local phase = 0
  for i = 1, N do
    local t = i * SAMPLE_DUR
    local F = F1 * (1 - 0.5 * t / Length)
    phase = phase + (SAMPLE_DUR * F)
    -- a[i] = math.abs(phase - math.floor(phase) - 0.5) * 4 - 1 -- Triangle
    a[i] = phase - math.floor(phase) < 0.5 and -1 or 1          -- Square
    a[i] = a[i] * ((Length - t) / Length)
  end
end

local results = {}
for k, v in pairs(tables) do
  local values = {}
  v(values)
  for i = 1, #values do
    local x = math.max(-1, math.min(1, values[i]))
    values[i] = math.floor(x * 32767.5 - 0.5)
  end
  results[#results + 1] = {
    k = k,
    v = 'const PROGMEM int16_t ' .. k .. '[] = {' .. table.concat(values, ',') .. '};'
  }
end
table.sort(results, function (a, b) return a.k < b.k end)
for i = 1, #results do print(results[i].v) end
