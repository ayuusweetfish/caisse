local caisse = require('caisse/caisse')
local rendermarkup = require('caisse/markup')
caisse.lang = 'zh'

local srcpath = 'content/'
local sitepath = 'build/'

caisse.readfile = function (path)
  return io.open(srcpath .. path, 'r'):read('a')
end
os.execute('rm -rf ' .. sitepath)
os.execute('mkdir ' .. sitepath)

local function shallowdup(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

local function writefile(file, s) io.open(file, 'w'):write(s) end
local function copyfile(src)
  local dst = 'bin/' .. src
  os.execute('mkdir -p $(dirname "' .. sitepath .. dst .. '")')
  os.execute('cp "' .. srcpath .. src .. '" "' .. sitepath .. dst .. '"')
end
local function render(...)
  return caisse.render(...)
end
local function renderpage(savepath, templatepath, locals)
  locals = locals or {}
  local contents = render(templatepath, locals)
  writefile(sitepath .. savepath,
    render('framework.html', {
      savepath = savepath,
      title = locals.title,
      curcat = locals.curcat,
      contents = contents,
    }))
end

local function split(s, delim)
  local i = 1
  local t = {}
  while i <= #s do
    local p = string.find(s, delim, i, true)
    if not p then break end
    t[#t + 1] = s:sub(i, p - 1)
    i = p + #delim
  end
  t[#t + 1] = s:sub(i)
  return t
end

local inspectimagecache = {}
local function inspectimage(path)
  if inspectimagecache[path] ~= nil then
    return table.unpack(inspectimagecache[path])
  end
  local p = io.popen('identify -format "%w %h" "' .. path .. '"')
  local w = p:read('n')
  local h = p:read('n')
  inspectimagecache[path] = {w, h}
  return w, h
end
caisse.envadditions.image = function (path, alt, class)
  local realpath
  if path:sub(1, 5) == '/bin/' then
    realpath = srcpath .. path:sub(6)
  else
    realpath = sitepath .. path
  end
  local w, h = inspectimage(realpath)
  return '<img src="' .. path .. '"' ..
    ' width=' .. w .. ' height=' .. h ..
    (alt and (' alt="' .. alt .. '"') or '') ..
    (class and (' class="' .. class .. '"') or '') ..
    '>'
end
caisse.envadditions.file = function (path, wd)
  if path:sub(1, 1) == '/' then
    path = path:sub(2)
    wd = {}
  else
    wd = wd and split(wd, '/') or {}
  end
  for _, part in ipairs(split(path, '/')) do
    if part == '.' then
      -- No-op
    elseif part == '..' then
      wd[#wd] = nil
    else
      wd[#wd + 1] = part
    end
  end
  local fullpath = table.concat(wd, '/')
  copyfile(fullpath)
  return '/bin/' .. fullpath
end

local function renderdate(datestr)
  local dates = {}
  for year, term in datestr:gmatch('([0-9]+)%.([0-9]+)') do
    dates[#dates + 1] = { year = tonumber(year, 10), term = tonumber(term, 10) }
  end
  return render('date.html', { dates = dates })
end
caisse.envadditions.renderdate = renderdate

local cats = render('categories.txt').cats

local itemreg = {}
local function registeritem(path, curcat)
  if itemreg[path] then return end
  -- `path` is the path in URL, without the leading `/`
  local locals = render('items/' .. path .. '/page.txt')
  itemreg[path] = {
    locals = locals,
    cat = curcat,
  }
end
local function renderallitems()
  for path, item in pairs(itemreg) do
    local locals = item.locals
    locals.name = path
    locals.curcat = item.cat
    print(item.cat, caisse.envadditions.tr(locals.title))
    renderpage(path, 'item.html', locals)
  end
end

local htmlescapelookup = {
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['&'] = '&amp;',
}
local function htmlescape(s)
  return s:gsub('[%<%>%&]', htmlescapelookup)
end
local markupfns
markupfns = {
  ['-'] = function (line)
    if line == '' then return ''
    elseif line:sub(1, 1) == '!' then return line:sub(2) .. '\n'
    else return '<p>' .. line .. '</p>' end
  end,
  ['^'] = htmlescape,
  b = function (text)
    return '<strong>' .. text .. '</strong>'
  end,
  hr = function ()
    return '<hr>'
  end,
  pre = function (text)
    return '<pre>' .. text .. '</pre>'
  end,
  rawlink = function (href, text)
    return '<a href="' .. href .. '">' .. text .. '</a>'
  end,
  extlink = function (href, text)
    return '<a class="pastel external" href="' .. href .. '">'
      .. htmlescape(text)
      .. '<sup>+</sup>'
      .. '</a>'
  end,
  link = function (path, text)
    local item = itemreg[path]
    if not item then return markupfns.extlink(path, text or path) end
    if text == '' then text = caisse.envadditions.tr(item.locals.title) end
    return '<a class="pastel ' .. item.cat .. '" href="/' .. path .. '">'
      .. htmlescape(text) .. '</a>'
  end,
  img = function (src, alt, class)
    return '<img src="' .. src .. '"'
      .. (alt and (' alt="' .. alt .. '"') or '')
      .. (class or (' class="' .. class .. '"') or '')
      .. '>'
  end,
}
caisse.envadditions.rendermarkup = function (s)
  return rendermarkup(s, markupfns)
end

copyfile('background.svg')
copyfile('top-fleuron.svg')
copyfile('Livvic-Regular.woff2')
copyfile('Livvic-Medium.woff2')
copyfile('Livvic-SemiBold.woff2')
copyfile('Sono_Monospace-Regular.woff2')
copyfile('Sono_Monospace-SemiBold.woff2')
copyfile('AaKaiSong2.woff2')

for i = 1, #cats do
  local pagelist = cats[i].pagelist or {}
  for j = 1, #pagelist do
    registeritem(pagelist[j].name, cats[i].name)
  end
end
registeritem('index', 'home')
registeritem('about', 'home')
registeritem('dates', 'home')
renderallitems()

renderpage('music', 'bannerlist.html', { curcat = 'music' })
renderpage('playful', 'bannerlist.html', { curcat = 'playful' })
renderpage('murmurs', 'textlist.html', { curcat = 'murmurs' })
