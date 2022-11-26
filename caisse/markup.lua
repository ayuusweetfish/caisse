local inspect = require('caisse/deps/inspect')
local function render(s, fns)
  local items = {}
  local last, cur = 0, 1
  local levels = {{
    items = {},
    fnname = nil,
    endmark = '\naaaa',
  }}
  -- Array of { items = array of string, fnname = string, endmark = string }
  while cur <= #s do
    local topitems = levels[#levels].items
    -- Top as in top of a the stack (innermost)
    if s:sub(cur, cur) == '<' then
      topitems[#topitems + 1] = s:sub(last + 1, cur - 1)
      local obrkts, fnname, endpos = s:match('^<*()%s*(%g*)%s*()', cur)
      obrkts = obrkts - cur
      levels[#levels + 1] = {
        items = {},
        fnname = fnname,
        endmark = string.rep('>', obrkts)
      }
      print('in', inspect(levels[#levels]))
      cur = endpos
      last = endpos - 1
    else
      local mark = levels[#levels].endmark
      if s:sub(cur, cur + #mark - 1) == mark then
        topitems[#topitems + 1] = s:sub(last + 1, cur - 1)
        local toplevel = levels[#levels]
        print('out', inspect(toplevel))
        levels[#levels] = nil
        topitems = levels[#levels].items
        topitems[#topitems + 1] =
          fns[toplevel.fnname](table.concat(toplevel.items))
        cur = cur + #mark
        last = cur - 1
      else
        cur = cur + 1
      end
    end
  end
  return table.concat(levels[1].items)
end

local function args(s, n)
  local results = {}
  local cur = 1
  for i = 1, n do
    local endat
    if s:sub(cur, cur) == '"' then
      endat = s:find('%f["]"%f[^"]', cur + 1) - 1
      results[i] = s:sub(cur + 1, endat):gsub('""', '"')
    else
      endat = s:find('%s', cur + 1) - 1
      results[i] = s:sub(cur, endat)
    end
    cur = s:find('%g', endat + 2)
  end
  results[n + 1] = s:sub(cur)
  return table.unpack(results)
end

return {
  render = render,
  args = args,
}
