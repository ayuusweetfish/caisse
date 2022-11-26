local function args(s, n)
  if n == 0 then return end
  local results = {}
  local cur = 1
  while (n and #results < n - 1) or (not n and cur <= #s) do
    local endat
    if s:sub(cur, cur) == '"' then
      endat = s:find('%f["]"%f[^"]', cur + 1) - 1
      results[#results + 1] = s:sub(cur + 1, endat)
    else
      endat = (s:find('%s', cur + 1) or (#s + 1)) - 1
      results[#results + 1] = s:sub(cur, endat)
    end
    cur = s:find('%g', endat + 2) or (#s + 1)
  end
  if n then results[n] = s:sub(cur) end
  return table.unpack(results)
end

local function render(s, fns)
  fns['='] = fns['='] or function (s) return s end
  fns['-'] = fns['-'] or function (s) return s .. '\n' end
  local allitems = {}
  local last, cur = 0, 1
  local levels = {{
    items = {},
    fn = fns['-'],
    endmark = '\n',
  }}
  -- Array of { items = array of string, fnname = string, endmark = string }
  local escape = false
  while cur <= #s + 1 do
    local topitems = levels[#levels].items
    -- Top as in top of a the stack (innermost)
    if not escape and s:sub(cur, cur) == '<' then
      topitems[#topitems + 1] = s:sub(last + 1, cur - 1):gsub('\\(.)', '%1')
      local obrkts, fnname, endpos = s:match('^<*()%s*([^%s>]*)%s*()', cur)
      obrkts = obrkts - cur
      local fn = fns[fnname]
      if fn == nil then error('Markup function ' .. fnname .. ' not provided') end
      levels[#levels + 1] = {
        items = {},
        fn = fn,
        endmark = string.rep('>', obrkts)
      }
      cur = endpos
      last = endpos - 1
      escape = false
    else
      local mark = levels[#levels].endmark
      if cur == #s + 1 or s:sub(cur, cur + #mark - 1) == mark then
        topitems[#topitems + 1] = s:sub(last + 1, cur - 1):gsub('\\(.)', '%1')
        local fn = levels[#levels].fn
        local fninfo = debug.getinfo(fn, 'u')
        local arity = fninfo.nparams
        if fninfo.isvararg then arity = nil end
        local outitems = levels[#levels].items
        if #levels == 1 then
          topitems = allitems
          levels[1].items = {}
        else
          levels[#levels] = nil
          topitems = levels[#levels].items
        end
        topitems[#topitems + 1] =
          fn(args(table.concat(outitems), arity))
        cur = cur + #mark
        last = cur - 1
        escape = false
      else
        escape = not escape and s:sub(cur, cur) == '\\'
        cur = cur + 1
      end
    end
  end
  return table.concat(allitems)
end

return render
