-- XXX: Written by Google Gemini 3 Flash. Not human reviewed in detail.

local unpack = unpack or table.unpack

local function get_bezier_extrema(p0, p1, p2, p3)
  local vals = {p0, p3} -- Endpoints are always candidates

  -- Derivative coefficients for at^2 + bt + c = 0
  local a = 3 * (-p0 + 3*p1 - 3*p2 + p3)
  local b = 6 * (p0 - 2*p1 + p2)
  local c = 3 * (p1 - p0)

  local function check_t(t)
    if t > 0 and t < 1 then
      local mt = 1 - t
      table.insert(vals, mt^3*p0 + 3*mt^2*t*p1 + 3*mt*t^2*p2 + t^3*p3)
    end
  end

  -- Solve quadratic: t = (-b ± sqrt(b^2 - 4ac)) / 2a
  local disc = b*b - 4*a*c
  if disc >= 0 then
    local sqrt_d = math.sqrt(disc)
    check_t((-b + sqrt_d) / (2 * a))
    check_t((-b - sqrt_d) / (2 * a))
  elseif math.abs(a) < 1e-9 and math.abs(b) > 1e-9 then
    -- Fallback to linear if a is near zero
    check_t(-c / b)
  end

  return math.min(unpack(vals)), math.max(unpack(vals))
end

local function calculate_svg_bbox(path_str)
  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge
  local cur_x, cur_y = 0, 0

  local function update_bbox(x, y)
    min_x, max_x = math.min(min_x, x), math.max(max_x, x)
    min_y, max_y = math.min(min_y, y), math.max(max_y, y)
  end

  -- Basic parser for M, L, C commands
  for cmd, args in path_str:gmatch("([MLC])%s*([^MLC]+)") do
    local coords = {}
    for val in args:gmatch("-?%d*%.?%d+") do
      table.insert(coords, tonumber(val))
    end

    if cmd == "M" or cmd == "L" then
      cur_x, cur_y = coords[1], coords[2]
      update_bbox(cur_x, cur_y)
    elseif cmd == "C" then
      local x1, y1, x2, y2, x3, y3 = unpack(coords)

      local bx_min, bx_max = get_bezier_extrema(cur_x, x1, x2, x3)
      local by_min, by_max = get_bezier_extrema(cur_y, y1, y2, y3)

      update_bbox(bx_min, by_min)
      update_bbox(bx_max, by_max)

      cur_x, cur_y = x3, y3
    end
  end

  return min_x, min_y, max_x, max_y
end

return calculate_svg_bbox
