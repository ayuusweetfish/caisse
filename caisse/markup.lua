local function args(ss, n, verb)
  if n == 0 then return end
  local results = {}
  local cur = 1
  local ssi = 1
  local s = ss[1].text
  while (n > 0 and #results < n - 1) or (n < 0 and ssi <= #ss) do
    -- Extract a whitespace-insensitive argument
    if not ss[ssi] or ss[ssi].unit then
      -- An unbreakable unit
      results[#results + 1] = s
      ssi = ssi + 1
      s = ssi <= #ss and ss[ssi].text or ''
      cur = s:find('[^%s]') or (#s + 1)
    else
      -- Match a whitespace frontier or to the end of the string
      local endat = (s:find('%f[%s]', cur + 1) or (#s + 1)) - 1
      local arg = s:sub(cur, endat)
      if arg ~= '' then results[#results + 1] = arg end
      cur = s:find('[^%s]', endat + 2) or (#s + 1)
      if cur > #s then
        ssi = ssi + 1
        s = ssi <= #ss and ss[ssi].text or ''
        cur = s:find('[^%s]') or (#s + 1)
      end
    end
  end
  if n > 0 then
    if not verb then cur = s:find('[^%s]', cur) or (#s + 1) end
    local rems = {}
    for i = ssi + 1, #ss do rems[#rems + 1] = ss[i].text end
    results[n] = s:sub(cur) .. table.concat(rems)
  end
  return table.unpack(results)
end

local function render(s, fns, ignoremissingfns)
  fns[''] = fns[''] or function (s) return s end  -- for <= ...>
  fns['-'] = fns['-'] or function (s) return s .. '\n' end
  fns['--'] = fns['--'] or function (s) return '' end
  fns['^'] = fns['^'] or function (s) return s end
  fns['~'] = fns['~'] or function (s)
    local r = render('!' .. s:gsub('\n', ' '), fns, ignoremissingfns)
    local endpos = r:find('[^%s]%s*$')
    if endpos then r = r:sub(1, endpos) end
    return r
  end
  fns['~~'] = fns['~~'] or function (s)
    return render(s, fns, ignoremissingfns)
  end
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
  local endmarkpos = {}
  local eoln = s:find('\n', 1, true) or (#s + 1)
  endmarkpos['\n'] = eoln
  local endmarkpostop = eoln
  -- Array of { items = array of string, fnname = string, endmark = string }
  local top = levels[#levels]
  while cur <= #s + 1 do
    local topitems = top.items
    -- Top as in top of a the stack (innermost)
    if not top.verb and s:byte(cur) == 60 --[[ '<' ]] then
      local text = s:sub(last + 1, cur - 1)
      if #levels == 1 then text = texttransform(text) end
      topitems[#topitems + 1] = {
        text = text,
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
      if fn == nil then
        if ignoremissingfns then fn = function () return '' end
        else error('Markup function ' .. fnname .. ' not provided') end
      end
      top = {
        items = {},
        fn = fn,
        verb = verb,
        endmark = endmark,
      }
      levels[#levels + 1] = top
      -- Skip exactly one whitespace for verbatim text
      -- and all following whitespaces for ordinary functions
      if verb then
        endpos = endpos + 1
      else
        endpos = s:find('[^%s]', endpos) or (#s + 1)
      end
      cur = endpos
      last = endpos - 1
      local e = endmarkpos[endmark]
      if not e or e < cur then
        e = s:find(endmark, cur, true)
        endmarkpos[endmark] = e
      end
      endmarkpostop = e
    elseif cur == endmarkpostop then
      local mark = top.endmark
      local fn = top.fn
      local fninfo = debug.getinfo(fn, 'u')
      local arity = fninfo.isvararg and -1 or fninfo.nparams
      local outitems = top.items
      local outverb = top.verb
      local text = s:sub(last + 1, cur - 1)
      if #levels == 1 then text = texttransform(text) end
      topitems[#topitems + 1] = {
        text = text,
        unit = false,
      }
      if #levels == 1 then
        topitems = allitems
        top.items = {}
      else
        levels[#levels] = nil
        top = levels[#levels]
        topitems = top.items
      end
      topitems[#topitems + 1] = {
        text = fn(args(outitems, arity, outverb)),
        unit = true,
      }
      cur = cur + #mark
      last = cur - 1
      local e = endmarkpos[top.endmark]
      if e < cur then
        e = s:find(top.endmark, cur, true) or (#s + 1)
        endmarkpos[top.endmark] = e
      end
      endmarkpostop = e
    else
      cur = cur + 1
    end
  end
  for i = 1, #allitems do allitems[i] = allitems[i].text end
  return table.concat(allitems)
end

return render
