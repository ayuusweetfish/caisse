local inspect = require('caisse/deps/inspect')
local printerr = function (...)
  for i = 1, select('#', ...) do
    io.stderr:write(tostring(select(i, ...)))
    io.stderr:write(i == select('#', ...) and '\n' or '\t')
  end
end

local caisse = {
  lang = 'zh',
  envadditions = {},
  readfile = function (path) return io.open(path, 'r'):read('a') end,
}

-- Item format:
-- {type = 'string', expr = string}
-- {type = 'expr'/'stmt', expr = string, fn = function}
-- {type = 'block', expr = string, span = number}
-- {type = 'scope', expr = string,
--  ident = string/nil, fn = function, span = number}
-- {type = 'scopesep'}
local function parsetemplate(s)
  local items = {}
  local last, cur = 0, 1
  local levelbegin = {}
  local blockbegin = 0
  local loadfn = function (expr)
    local fn = load(expr, expr, 't')
    if fn == nil then error('Expression "' .. expr .. '" is invalid') end
    return function (locals)
      local prevmt = getmetatable(_ENV)
      setmetatable(_ENV, {
        __index = function (table, key)
          for i = #locals, 1, -1 do
            if locals[i][key] ~= nil then return locals[i][key] end
          end
          if caisse.envadditions[key] ~= nil then
            return caisse.envadditions[key]
          end
        end,
        __newindex = function (table, key, value)
          -- Look for outer levels
          -- TODO: Persistent nil
          for i = #locals, 1, -1 do
            if locals[i][key] ~= nil then
              locals[i][key] = value
              return
            end
          end
          -- Create new local variable
          locals[#locals][key] = value
        end,
      })
      local ret = fn()
      setmetatable(_ENV, prevmt)
      return ret
    end
  end
  while cur <= #s do
    if s:sub(cur, cur + 1) == '{{' then
      -- New text entry
      if last ~= cur then
        items[#items + 1] = {type = 'string', expr = s:sub(last + 1, cur - 1)}
      end
      -- Find matching closing brackets
      local obrkts = 2
      while s:sub(cur + obrkts, cur + obrkts) == '{' do obrkts = obrkts + 1 end
      local endmark = string.rep('}', obrkts)
      local endpos, endext = s:find('%s*' .. endmark, cur + obrkts)
      if endpos == nil then error('No matching closing brackets!') end
      -- Trim substring
      local startpos = s:find('[^%s]', cur + obrkts)
      local expr = s:sub(startpos, endpos - 1)
      if expr:sub(1, 1) == '@' then
        if expr:match('^@%s*end%s*$') then
          -- Move up one level
          items[levelbegin[#levelbegin]].span = #items
          levelbegin[#levelbegin] = nil
        elseif expr:match('^@%s*,%s*$') then
          -- Separator
          items[#items + 1] = {type = 'scopesep'}
        else
          -- Nested scope
          local ident, ctxexpr = expr:match('^@%s*([%a_][%w_]*)%s+in([^%w_].*)$')
          if ident == nil then ctxexpr = expr:sub(2) end
          local fn = loadfn('return ' .. ctxexpr)
          items[#items + 1] = {type = 'scope', expr = ctxexpr,
            ident = ident, fn = fn, span = 0}
          levelbegin[#levelbegin + 1] = #items
        end
      elseif expr:sub(-1) == '=' then
        -- Block
        if blockbegin ~= 0 then
          items[blockbegin].span = #items
        end
        items[#items + 1] = {type = 'block', expr = expr:sub(1, -2), span = 0}
        blockbegin = #items
      else
        -- Detect type
        local succeeded, fn
        if expr:sub(1, 1) == '!' then
          expr = expr:sub(2)
        else
          succeeded, fn = pcall(loadfn, 'return ' .. expr)
        end
        if succeeded then
          items[#items + 1] = {type = 'expr', expr = expr, fn = fn}
        else
          fn = loadfn(expr) -- Errors, if any, will bubble up
          items[#items + 1] = {type = 'stmt', expr = expr, fn = fn}
        end
      end
      last = endext
      cur = endext + 1
      -- Blocks special check: either single-line or skip newlines
      if items[#items].type == 'block' then
        local lineend = s:find('\n', cur)
        if lineend then lineend = lineend - 1 else lineend = #s end
        local linerem = s:sub(cur, lineend)
        if linerem:find('[^%s]') then
          -- Non-empty contents found; attach and close block
          items[#items + 1] = {type = 'string', expr = linerem}
          items[blockbegin].span = #items
          items[#items + 1] = {type = 'block', expr = '', span = 0}
          blockbegin = #items
          -- Skip the line and newlines
          cur = s:find('[^\n]', lineend + 1) or (#s + 1)
          last = cur - 1
        else
          -- Skip following new lines
          local skipto = s:match('^%s*\n()', cur)
          if skipto then
            print(s:sub(cur, cur + 20):gsub('\n', '$'), cur, skipto)
            last = skipto - 1
            cur = skipto
          end
        end
      end
    else
      cur = cur + 1
    end
  end
  if last ~= #s then
    items[#items + 1] = {type = 'string', expr = s:sub(last + 1, #s)}
  end
  if blockbegin ~= 0 then
    items[blockbegin].span = #items
  end
  return items
end

local function tr(value)
  if type(value) == 'table' then
    if value[caisse.lang] ~= nil and type(value[caisse.lang]) ~= 'table' then
      return tostring(value[caisse.lang])
    else
      return nil
    end
  else
    return value
  end
end

local function renderslice(template, locals, outputs, rangestart, rangeend)
  local i = rangestart
  while i <= rangeend do
    local item = template[i]
    if item.type == 'string' then
      -- Raw text
      outputs[#outputs + 1] = item.expr
    elseif item.type == 'expr' or item.type == 'stmt' then
      -- Expression or statement
      local value = item.fn(locals)
      if item.type == 'expr' then
        if value == nil then
          value = 'nil'
        elseif type(value) == 'table' then
          local trvalue = tr(value)
          if trvalue == nil then
            error('Table results are not allowed: ' .. inspect(value))
          end
          value = trvalue
        end
        outputs[#outputs + 1] = value
      end
    elseif item.type == 'scope' then
      -- Scope: conditional (if) / context (with/for-each) / call
      local ctx = item.fn(locals)
      if type(ctx) == 'table' then
        -- Context context (with/for-each): depends on whether #ctx > 0
        -- Unpack a table into the context and render a template slice
        local unpackctx = function (ctx)
          local ctxcopy = {}
          if item.ident ~= nil then
            ctxcopy[item.ident] = ctx
          else
            for k, v in pairs(ctx) do ctxcopy[k] = v end
          end
          locals[#locals + 1] = ctxcopy
          renderslice(template, locals, outputs, i + 1, item.span)
          locals[#locals] = nil
        end
        if #ctx > 0 or next(ctx) == nil then
          for j = 1, #ctx do unpackctx(ctx[j]) end
        else
          unpackctx(ctx)
        end
        i = item.span
      elseif type(ctx) == 'function' then
        -- Function call
        locals[#locals + 1] = {}
        local newoutputslist = {}
        local nextstart = i + 1
        for j = i + 1, item.span + 1 do
          if j == item.span + 1 or template[j].type == 'scopesep' then
            newoutputslist[#newoutputslist + 1] = {}
            renderslice(template, locals,
              newoutputslist[#newoutputslist], nextstart, j - 1)
            nextstart = j + 1
          end
        end
        locals[#locals] = nil
        local succeeded, result = pcall(ctx, table.unpack(newoutputslist))
        if not succeeded then
          for j = 1, #newoutputslist do
            newoutputslist[j] = table.concat(newoutputslist[j])
          end
          local succeeded2, result2 = pcall(ctx, table.unpack(newoutputslist))
          if not succeeded2 then
            error('Function call failed: ' .. tostring(item.expr) ..
              '\nError with original segments:\n' .. tostring(result) ..
              '\nError with concatenated strings:\n' .. tostring(result2))
          end
          result = result2
        end
        outputs[#outputs + 1] = result
        i = item.span
      else
        -- Conditional (if): boolean or existence check
        if not ctx then i = item.span end
      end
    elseif item.type == 'block' then
      -- Render to a completely new block
      local defaultoutput = (item.expr == '')
      local newoutputs = defaultoutput and outputs or {}
      if not defaultoutput then
        -- New variable scope
        locals[#locals + 1] = {}
      end
      renderslice(template, locals, newoutputs, i + 1, item.span)
      if not defaultoutput then
        locals[#locals] = nil
        -- Put the render result in a new variable
        -- Trim trailing whitespaces
        if #newoutputs > 0 then
          local n = #newoutputs
          newoutputs[n] = tostring(newoutputs[n]):gsub('%s*$', '')
        end
        local contents = table.concat(newoutputs)
        -- Assign the result to the variable specified,
        -- supporting nested table auto-creation through metatables
        local function metaindex(table, key)
          local result = setmetatable({}, {__index = metaindex})
          rawset(table, key, result)
          return result
        end
        local setfn = load(
          string.gsub('? = (type(?) == "table" and "" or (? and (? .. "\\n") or "")) .. ...',
            '[?]', item.expr),
          item.expr, 't')
        local prevmt = getmetatable(_ENV)
        setmetatable(_ENV, {__index = function (table, key)
          if locals[#locals][key] ~= nil then return locals[#locals][key] end
          local result = setmetatable({}, {__index = metaindex})
          rawset(locals[#locals], key, result)
          return result
        end, __newindex = function (table, key, value)
          rawset(locals[#locals], key, value)
        end})
        setfn(contents)
        setmetatable(_ENV, prevmt)
      end
      i = item.span
    end
    i = i + 1
  end
end

local templateregistry = {}
local function loadtemplate(path)
  if templateregistry[path] ~= nil then return templateregistry[path] end
  local t = parsetemplate(caisse.readfile(path))
  templateregistry[path] = t
  return t
end
-- Renders a template
-- Returns the rendered string if the path ends with ".html";
-- returns locals otherwise
local function render(path, locals)
  locals = locals or {}
  local outputs = {}
  local template = loadtemplate(path)
  renderslice(template, {locals}, outputs, 1, #template)
  if path:sub(-5) == '.html' then
    return table.concat(outputs), locals
  else
    return locals
  end
end

caisse.envadditions.render = render
caisse.envadditions.inspect = inspect
caisse.envadditions.tr = tr
caisse.render = render
return caisse
