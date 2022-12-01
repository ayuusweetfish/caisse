local function args(ss, n, verb)
  if n == 0 then return end
  local results = {}
  local cur = 1
  local ssi = 1
  local s = ss[1].text
  while (n and #results < n - 1) or (not n and ssi <= #ss) do
    -- Extract a whitespace-insensitive argument
    if not ss[ssi] or ss[ssi].unit then
      -- An unbreakable unit
      results[#results + 1] = s
      ssi = ssi + 1
    else
      -- Match a whitespace frontier or to the end of the string
      local endat = (s:find('%f[%s]', cur + 1) or (#s + 1)) - 1
      local arg = s:sub(cur, endat)
      if arg ~= '' then results[#results + 1] = arg end
      cur = s:find('[^%s]', endat + 2) or (#s + 1)
      if cur > #s then
        ssi = ssi + 1
        cur = 1
      end
    end
    s = ssi <= #ss and ss[ssi].text or ''
  end
  if n then
    if not verb then cur = s:find('[^%s]', cur) or (#s + 1) end
    local rems = {}
    for i = ssi + 1, #ss do rems[#rems + 1] = ss[i].text end
    results[n] = s:sub(cur) .. table.concat(rems)
  end
  return table.unpack(results)
end

local function render(s, fns)
  fns[''] = fns[''] or function (s) return s end  -- for <= ...>
  fns['-'] = fns['-'] or function (s) return s .. '\n' end
  fns['^'] = fns['^'] or function (s) return s end
  local linetransform = fns['-']
  local texttransform = fns['^']
  local allitems = {}
  local last, cur = 0, 1
  local levels = {{
    items = {},
    fn = linetransform,
    verb = false, -- Verbatim?
    endmark = '\n',
  }}
  -- Array of { items = array of string, fnname = string, endmark = string }
  while cur <= #s + 1 do
    local topitems = levels[#levels].items
    -- Top as in top of a the stack (innermost)
    if not levels[#levels].verb and s:sub(cur, cur) == '<' then
      topitems[#topitems + 1] = {
        text = texttransform(s:sub(last + 1, cur - 1)),
        unit = false,
      }
      local obrkts, fnname, endpos = s:match('^<*()%s*([^%s>]*)()', cur)
      obrkts = obrkts - cur
      local verb = false
      local eqpos = fnname:find('=')
      local endmark = string.rep('>', obrkts)
      if eqpos ~= nil then
        verb = true
        endmark = fnname:sub(eqpos + 1) .. endmark
        fnname = fnname:sub(1, eqpos - 1)
      end
      local fn = fns[fnname]
      if fn == nil then error('Markup function ' .. fnname .. ' not provided') end
      levels[#levels + 1] = {
        items = {},
        fn = fn,
        verb = verb,
        endmark = endmark,
      }
      -- Skip exactly one whitespace for verbatim text
      -- and all following whitespaces for ordinary functions
      if verb then
        endpos = endpos + 1
      else
        endpos = s:find('[^%s]', endpos) or (#s + 1)
      end
      cur = endpos
      last = endpos - 1
    else
      local mark = levels[#levels].endmark
      if cur == #s + 1 or s:sub(cur, cur + #mark - 1) == mark then
        local fn = levels[#levels].fn
        local fninfo = debug.getinfo(fn, 'u')
        local arity = fninfo.nparams
        if fninfo.isvararg then arity = nil end
        local outitems = levels[#levels].items
        local outverb = levels[#levels].verb
        local text = s:sub(last + 1, cur - 1)
        if not outverb then text = texttransform(text) end
        topitems[#topitems + 1] = {
          text = text,
          unit = false,
        }
        if #levels == 1 then
          topitems = allitems
          levels[1].items = {}
        else
          levels[#levels] = nil
          topitems = levels[#levels].items
        end
        topitems[#topitems + 1] = {
          text = fn(args(outitems, arity, outverb)),
          unit = true,
        }
        cur = cur + #mark
        last = cur - 1
      else
        cur = cur + 1
      end
    end
  end
  for i = 1, #allitems do allitems[i] = allitems[i].text end
  return table.concat(allitems)
end

return render
