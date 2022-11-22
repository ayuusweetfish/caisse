-- Item format:
-- string
-- function
-- {type = string, expr = string/function, span = number}
local loadtemplate = function (s)
  local items = {}
  local last, cur = 0, 1
  local levelbegin = {}
  local blockbegin = 0
  local loadfn = function (expr)
    local fn = load('return ' .. expr, expr, 't')
    if fn == nil then
      fn = load(expr, expr, 't')
      if fn == nil then error('Statement "' .. expr:sub(2) .. '" is invalid') end
    end
    return function (locals)
      setmetatable(_ENV, {
        __index = locals,
        __newindex = function (table, key, value) locals[key] = value end,
      })
      local ret = fn()
      setmetatable(_ENV, nil)
      return ret
    end
  end
  while cur <= #s do
    if s:sub(cur, cur + 1) == '{{' then
      -- New text entry
      if last ~= cur then
        items[#items + 1] = s:sub(last + 1, cur - 1)
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
        else
          -- Nested scope
          local fn = loadfn(expr:sub(2))
          items[#items + 1] = {type = 'scope', expr = fn, span = 0}
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
        items[#items + 1] = loadfn(expr)
      end
      last = endext
      cur = endext + 1
    else
      cur = cur + 1
    end
  end
  if last ~= #s then
    items[#items + 1] = s:sub(last + 1, #s)
  end
  if blockbegin ~= 0 then
    items[blockbegin].span = #items
  end
  return items
end

local function render(template, locals, outputs, rangestart, rangeend)
  outputs = outputs or {}
  rangestart = rangestart or 1
  rangeend = rangeend or #template
  local i = rangestart
  while i <= rangeend do
    local item = template[i]
    if type(item) == 'string' then
      -- Raw text
      outputs[#outputs + 1] = item
    elseif type(item) == 'function' then
      -- Expression or statement
      local value = item(locals)
      if value ~= nil then
        if type(value) == 'table' then
          local lang = 'zh'
          if value[lang] ~= nil and type(value[lang]) ~= 'table' then
            value = tostring(value[lang])
          else
            error('Tables results are not allowed')
          end
        end
        outputs[#outputs + 1] = value
      end
    elseif type(item) == 'table' then
      -- Scope: conditional (if) / context (with/for-each)
      if item.type == 'scope' then
        local ctx = item.expr(locals)
        if type(ctx) == 'boolean' or ctx == nil then
          -- Conditional (if): boolean or existence check
          if not ctx then i = item.span end
        elseif type(ctx) == 'table' then
          -- Context context (with/for-each): depends on whether #ctx > 0
          -- Unpack a table into the context and render a template slice
          local unpackctx = function (ctx)
            local stash = {}
            for k, v in pairs(ctx) do
              stash[k] = locals[k]
              locals[k] = v
            end
            render(template, locals, outputs, i + 1, item.span)
            for k, v in pairs(ctx) do
              locals[k] = stash[k]
            end
          end
          if #ctx > 0 then
            for j = 1, #ctx do unpackctx(ctx[j]) end
          else
            unpackctx(ctx)
          end
          i = item.span
        else
          error('Expression should either be a boolean or a table value')
        end
      elseif item.type == 'block' then
        -- Render to a completely new block
        local newoutputs = {}
        render(template, locals, newoutputs, i + 1, item.span)
        local contents = table.concat(newoutputs, '')
        -- Assign the result to the variable specified,
        -- supporting nested table auto-creation through metatables
        local function metaindex(table, key)
          local result = setmetatable({}, {__index = metaindex})
          rawset(table, key, result)
          return result
        end
        local setfn = load(
          string.gsub('? = (type(?) == "table" and "" or ?) .. ...',
            '[?]', item.expr),
          item.expr, 't')
        setmetatable(_ENV, {__index = function (table, key)
          if locals[key] ~= nil then return locals[key] end
          local result = setmetatable({}, {__index = metaindex})
          rawset(locals, key, result)
          return result
        end})
        setfn(contents)
        setmetatable(_ENV, nil)
        i = item.span
      end
    end
    i = i + 1
  end
  if rangestart == 1 and rangeend == #template then
    return table.concat(outputs, '')
  end
end

local t_creation = loadtemplate(io.open('content/creation.html', 'r'):read('a'))
local t_page = loadtemplate(io.open('content/daytime-cat/page.txt', 'r'):read('a'))
local t_main = loadtemplate(io.open('index.html', 'r'):read('a'))
local locals = {}
--render(t_page, locals)
--local pagemain = render(t_creation, locals)
local pagemain = render(loadtemplate(io.open('content/list.html', 'r'):read('a')), locals)
local pageall = render(t_main, {contents = pagemain})
print(pageall)
