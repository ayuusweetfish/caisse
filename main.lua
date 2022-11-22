local loadtemplate = function (s)
  local items = {}
  local last, cur = 0, 1
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
      -- Detect type
      local fn = load(
        'setmetatable(_ENV, {__index=...}) return ' .. expr,
        expr, 't')
      if fn ~= nil then
        items[#items + 1] = function (locals)
          return fn(locals)
        end
      else
        items[#items + 1] = expr
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
  return items
end

local render = function (template, locals)
  local i = 1
  while i <= #template do
    local item = template[i]
    if type(item) == 'function' then
      print(item({title = 'a', intro = 'b', contents = 'c'}))
    else print(item)
    end
    i = i + 1
  end
end

local t_creation = loadtemplate(io.open('content/creation.html', 'r'):read('a'))
local t_page = loadtemplate(io.open('content/daytime-cat/page.txt', 'r'):read('a'))
local locals = {}
--render(t_page, locals)
render(t_creation, locals)
--local t_main = loadtemplate(io.open('index.html', 'r'):read('a'))
