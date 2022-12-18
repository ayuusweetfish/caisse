local function normalizetint(v)
  return v:gsub('hsl%((.+)deg, (.+), (.+)%)',
    function (h, s, l)
      return string.format('hsl(%s, %s, %s)',
        h, s, l)
    end)
       :gsub('hsla%((.+)deg, (.+), (.+), (.+)%%%)',
    function (h, s, l, a)
      return string.format('hsla(%s, %s, %s, %g)',
        h, s, l, tonumber(a) / 100)
    end)
       :gsub('rgba%((.+), (.+), (.+), (.+)%%%)',
    function (r, g, b, a)
      return string.format('rgba(%s, %s, %s, %g)',
        r, g, b, tonumber(a) / 100)
    end)
end

local function css(s)
  -- Caveat: cannot handle '}' characters inside rules (strings)
  return s:gsub('({%s+)([^{}]*)(%s+})', function (init, block, fin)
    local logical = {
      size = {}, minsize = {}, maxsize = {},
      inset = {},
      border = {},
      margin = {},
      padding = {},
    }
    local function set(table, side, value, singleval)
      if side == 'block-start' then table[1] = value
      elseif side == 'block-end' then table[3] = value
      elseif side == 'inline-start' then table[4] = value
      elseif side == 'inline-end' then table[2] = value
      elseif side == 'block' or side == 'inline' then
        local v1, v2
        if singleval then
          v1, v2 = value, value
        else
          v1 = value:match('^(%g+%b())') or value:match('^(%g+)')
          v2 = value:match('(%g+%b())$') or value:match('(%g+)$')
        end
        if side == 'block' then table[1], table[3] = v1, v2
        else table[4], table[2] = v1, v2 end
      else return false end
      return true
    end
    local rules = {}
    local concat = table.concat
    local function serialize(table, ...)
      local count = (table[1] and 1 or 0) + (table[2] and 1 or 0) +
        (table[3] and 1 or 0) + (table[4] and 1 or 0)
      if count == 0 then return end
      for i = 1, 4 do
        if table[i] then table[i] = normalizetint(table[i]) end
      end
      local n = select('#', ...)
      if n >= 2 then
        -- Separate names
        for i = 1, n do if table[i] then
          rules[#rules + 1] = select(i, ...) .. ': ' .. table[i] .. ';'
        end end
      else
        -- Shorthands
        local name = select(1, ...)
        local dirs = {'top', 'right', 'bottom', 'left'}
        if count < 4 then
          -- Trivial dump
          for i = 1, 4 do if table[i] then
            rules[#rules + 1] = name .. '-' .. dirs[i] .. ': ' .. table[i] .. ';'
          end end
        else
          if table[4] == table[2] then
            table[4] = nil
            if table[3] == table[1] then
              table[3] = nil
              if table[2] == table[1] then table[2] = nil end
            end
          end
          rules[#rules + 1] = name .. ': ' .. concat(table, ' ') .. ';'
        end
      end
    end
    local function processrule(k, v)
      if not (
           (k:sub(-5) == '-size' and (
             set(logical.size, k:sub(1, -6), v)) or
             (k:sub(1, 4) == 'min-' and set(logical.minsize, k:sub(5, -6), v)) or
             (k:sub(1, 4) == 'max-' and set(logical.maxsize, k:sub(5, -6), v))
           )
        or (k:sub(1, 6) == 'inset-' and set(logical.inset, k:sub(7), v))
        or (k:sub(1, 7) == 'border-' and set(logical.border, k:sub(8), v, true))
        or (k:sub(1, 7) == 'margin-' and set(logical.margin, k:sub(8), v))
        or (k:sub(1, 8) == 'padding-' and set(logical.padding, k:sub(9), v))
      ) then
        -- Logical properties (float)
        v = (v == 'inline-end' and 'right'
          or (v == 'inline-start' and 'left') or v)
        -- Colours
        v = normalizetint(v)
        -- Emit a rule
        rules[#rules + 1] = k .. ': ' .. v .. ';'
        -- Grid for IE11
        if k == 'display' and v == 'grid' then
          rules[#rules + 1] = 'display: -ms-grid;'
        end
        if k == 'grid-template-columns' then
          rules[#rules + 1] = '-ms-grid-columns: ' .. v .. ';'
        end
        if k == 'grid-row' or k == 'grid-column' then
          local start, span = v:match('(%d+) / span (%d+)')
          if start then
            rules[#rules + 1] = '-ms-' .. k .. ': ' .. start .. ';'
            rules[#rules + 1] = '-ms-' .. k .. '-span: ' .. span .. ';'
          else
            local span = v:match('span (%d+)')
            if span then
              rules[#rules + 1] = '-ms-' .. k .. '-span: ' .. span .. ';'
            else
              rules[#rules + 1] = '-ms-' .. k .. ': ' .. v .. ';'
            end
          end
        end
        -- Writing mode for IE11
        if k == 'writing-mode' and v == 'vertical-rl' then
          rules[#rules + 1] = '-ms-writing-mode: tb-rl;'
        end
      end
    end
    local cur = 1
    while cur <= #block do
      cur = block:find('%g', cur)
      if cur == nil then break end
      if block:sub(cur, cur + 1) == '/*' then
        cur = block:find('*/', cur + 2, true) + 2
      else
        local key, p1 = block:match('(%g+)%s*:%s*()%g', cur)
        local paren = 0
        cur = p1
        while true do
          local ch = block:sub(cur, cur)
          if ch == ';' and paren == 0 then
            break
          elseif ch == '(' then
            paren = paren + 1
          elseif ch == ')' then
            paren = paren - 1
          elseif ch == '"' or ch == "'" then
            cur = block:find(ch, cur + 1, true)
          end
          cur = cur + 1
        end
        local value = block:sub(p1, cur - 1)
        processrule(key, value)
        cur = cur + 1
      end
    end
    serialize(logical.size, 'height', 'width')
    serialize(logical.minsize, 'min-height', 'min-width')
    serialize(logical.maxsize, 'max-height', 'max-width')
    serialize(logical.inset, 'top', 'right', 'bottom', 'left')
    serialize(logical.border, 'border')
    serialize(logical.margin, 'margin')
    serialize(logical.padding, 'padding')
    return init .. table.concat(rules, init:sub(2)) .. fin
  end)
end

local function html(s)
  local cur = 1
  local ret = {}
  local styles = {}
  local firststylestart = nil
  while cur <= #s do
    local pos1s, pos1e = s:match('()<style>()', cur)
    if not pos1s then break end
    local pos2s, pos2e = s:match('()</style>()', pos1e)
    ret[#ret + 1] = s:sub(cur, pos1s - 1)
    styles[#styles + 1] = s:sub(pos1e, pos2s - 1)
    if not firststylestart then firststylestart = #ret + 1 end
    cur = pos2e
  end
  ret[#ret + 1] = s:sub(cur)
  if firststylestart then
    table.insert(ret, firststylestart,
      '<style>' .. css(table.concat(styles)) .. '</style>')
  end
  return table.concat(ret)
end

return {
  html = html,
  css = css,
}
