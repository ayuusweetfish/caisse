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
-- `filepath` is an absolute path without the leading slash
local function ensuredir(filepath)
  os.execute('mkdir -p $(dirname "' .. sitepath .. filepath .. '")')
end
local contentpath = {}
-- `src` is an absolute path without the leading slash
local function copyfile(src)
  local dst
  if src:find('^items/') then
    dst = src:sub(7)
  else
    dst = 'bin/' .. src
  end
  ensuredir(dst)
  os.execute('cp "' .. srcpath .. src .. '" "' .. sitepath .. dst .. '"')
  contentpath[dst] = src
  return dst
end
local function render(...)
  return caisse.render(...)
end
local function renderpage(savepath, templatepath, locals)
  locals = locals or {}
  local contents = render(templatepath, locals)
  local filepath = savepath .. '/index.html'
  ensuredir(filepath)
  writefile(sitepath .. filepath,
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
caisse.envadditions.split = split

local filedb = {}
for line in io.open('misc/stat/database.tsv', 'r'):lines() do
  local fields = split(line, '\t')
  filedb[fields[1]] = {
    size = tonumber(fields[2]),
    type = fields[3],
    args = {table.unpack(fields, 4)},
  }
end
local function fileinfo(src)
  if not filedb[src] then error('File ' .. src .. ' not recorded') end
  return filedb[src]
end

local function fxhash(s)
  local h = 0
  for i = 1, #s do
    h = ((h << 5) ~ string.byte(s, i)) * 0x517cc1b727220a95
  end
  return string.format('%016x', h)
end

local function fullpath(path, wd)
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
  return table.concat(wd, '/')
end
caisse.envadditions.file = function (path, wd)
  path = fullpath(path, wd)
  return '/' .. copyfile(path)
end

local function inspectimage(path)
  return table.unpack(fileinfo(path).args)
end
caisse.envadditions.image = function (path, alt, class, style)
  local w, h = inspectimage(contentpath[fullpath(path)])
  return '<img src="' .. path .. '"' ..
    ' width=' .. w .. ' height=' .. h ..
    (alt and (' alt="' .. alt .. '"') or '') ..
    (class and (' class="' .. class .. '"') or '') ..
    (style and (' style="' .. style .. '"') or '') ..
    '>'
end

local function renderdate(datestr, nolink)
  local dates = {}
  for year, term in datestr:gmatch('([0-9]+)%.([0-9]+)') do
    dates[#dates + 1] = { year = tonumber(year, 10), term = tonumber(term, 10) }
  end
  local content = render('date.html', { dates = dates })
  if not nolink then
    content = '<a href="/dates" class="hidden-pastel date-term-link">'
      .. content .. '</a>'
  end
  return content
end
caisse.envadditions.renderdate = renderdate

local cats = render('categories.txt').cats

local itemreg = {}
local function registeritem(path, curcat, extralocals)
  if itemreg[path] then return end
  -- `path` is the path in URL, without the leading `/`
  local locals = render('items/' .. path .. '/page.txt')
  if extralocals then
    for k, v in pairs(extralocals) do locals[k] = v end
  end
  itemreg[path] = {
    locals = locals,
    cat = curcat,
  }
end

local htmlescapelookup = {
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['&'] = '&amp;',
}
local function htmlescape(s)
  return s:gsub('[%<%>%&]', htmlescapelookup)
end

local function sizestring(size)
  if size < 1024 then
    return string.format('%d B', size)
  elseif size < 1024 * 100 then
    return string.format('%.1f KiB', size / 1024)
  elseif size < 1024 * 1024 then
    return string.format('%.0f KiB', size / 1024)
  elseif size < 1024 * 1024 * 100 then
    return string.format('%.1f MiB', size / (1024 * 1024))
  elseif size < 1024 * 1024 * 1024 then
    return string.format('%.0f MiB', size / (1024 * 1024))
  else
    return string.format('%.2f GiB', size / (1024 * 1024 * 1024))
  end
end
local function lengthstring(seconds)
  if seconds < 60 * 60 then
    return string.format('%02d:%02d', seconds // 60, seconds % 60)
  else
    return string.format('%d:%02d:%02d',
      seconds // 3600, (seconds % 3600) // 60, seconds % 60)
  end
end

local filetypeicons = {
  unknown = 0x1f4e6,
  audio = 0x1f3a7,
  musicnotes = 0x1f3b6,
  score = 0x1f3bc,
  image = 0x1f5bc,
  video = 0x1f39e,
  document = 0x1f4c3,
  code = 0x1f47e,
}
local filetypeextrainfo = {
  audio = function (dur)
    return lengthstring(tonumber(dur))
  end,
  video = function (dur, w, h)
    return lengthstring(tonumber(dur)) .. ', ' .. w .. 'x' .. h
  end,
  document = function (npages)
    if npages then
      npages = tonumber(npages)
      return tostring(npages) ..
        (caisse.lang == 'en' and (npages == 1 and ' page' or ' pages')
         or ' 页')
    end
  end,
}

local markupfnsenvitem  -- Item name of the item currently being processed
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
  br = function () return '<br>' end,
  hr = function (class)
    return '<div role="separator"' ..
      (class ~= '' and ' class="' .. class .. '"' or '') ..
      '></div>'
  end,
  pre = function (text)
    return '<pre>' .. text .. '</pre>'
  end,
  rawlink = function (href, text)
    return '<a href="' .. href .. '">' .. text .. '</a>'
  end,
  extlink = function (href, text)
    return '<a class="pastel external" href="' .. href .. '" target="_blank">'
      .. htmlescape(text)
      .. '<sup class="little-icons">&#x1fa90;</sup>'
      .. '</a>'
  end,
  link = function (path, text)
    local itemname = path
    local anchor
    local hashpos = path:find('#')
    if hashpos ~= nil then
      itemname = path:sub(1, hashpos - 1)
      anchor = path:sub(hashpos + 1)
      if text == '' then text = anchor end
    end
    local item = itemreg[itemname]
    if not item then return markupfns.extlink(path, text ~= '' and text or path) end
    if text == '' then text = caisse.envadditions.tr(item.locals.title) end
    return '<a class="pastel ' .. item.cat .. '" href="/' .. path .. '">'
      .. htmlescape(text) .. '</a>'
  end,
  img = function (src, alt, class)
    return '<div class="image-container">' ..
      caisse.envadditions.image(
        caisse.envadditions.file(src, 'items/' .. markupfnsenvitem),
        alt, class) ..
      '</div>'
  end,
  filetable = function (contents)
    return '<table class="file-table"><tbody>' .. contents .. '</tbody></table>'
  end,
  file = function (src, text)
    local item = itemreg[markupfnsenvitem]
    local fullpath = fullpath(src, 'items/' .. markupfnsenvitem)
    local fileurl = caisse.envadditions.file(fullpath)
    local size = fileinfo(fullpath).size
    local parts = split(fileurl, '/')
    local basename = parts[#parts]
    local filetype = fileinfo(fullpath).type
    local icon = filetypeicons[filetype]
    local extrainfo = filetypeextrainfo[filetype]
    if extrainfo then
      extrainfo = extrainfo(table.unpack(fileinfo(fullpath).args))
    end
    return '<tr><td>' .. text .. '</td>' ..
      '<td><a class="pastel ' .. item.cat .. '" href="' ..
      fileurl ..  '">' ..
      '<span class="little-icons">&#x' .. string.format('%x', icon) ..
      ';</span><strong class="file-table-name">' .. basename .. '</strong>(' ..
      sizestring(size) ..
      (extrainfo and (', ' .. extrainfo) or '') .. ')</a></td>'
  end,
  h1 = function (text, anchor)
    return '<h1' ..
      (anchor and (' id="' .. anchor .. '"') or '') ..
      '>' .. htmlescape(text) .. '</h1>'
  end,
  list = function (contents)
    return '<ul>' .. contents .. '</ul>'
  end,
  li = function (text)
    return '<li>' .. text .. '</li>'
  end,
  cen = function (text)
    return '<p style="text-align: center">' .. text .. '</p>'
  end,
  blockquote = function (text)
    return '<blockquote>' .. text .. '</blockquote>'
  end,
  clearfloat = function ()
    return '<div style="clear: both"></div>'
  end,
  date = function (datestr)
    return renderdate(datestr)
  end,
  kao = function (text)
    return '<span class="kaomoji">' ..
      io.open('misc/kaomoji/gen/moji-' .. fxhash(text) .. '.svg'):read('a') ..
      '</span>'
  end,
}
caisse.envadditions.rendermarkup = function (s)
  return rendermarkup(s, markupfns)
end

local function renderallitems()
  for path, item in pairs(itemreg) do
    local locals = item.locals
    locals.name = path
    locals.curcat = item.cat
    print(item.cat, caisse.envadditions.tr(locals.title))
    markupfnsenvitem = path
    renderpage(path, 'item.html', locals)
  end
  markupfnsenvitem = nil
end

copyfile('background.svg')
copyfile('top-fleuron.svg')
copyfile('Livvic-Regular.woff2')
copyfile('Livvic-Medium.woff2')
copyfile('Livvic-SemiBold.woff2')
copyfile('Sono_Monospace-Regular.woff2')
copyfile('Sono_Monospace-SemiBold.woff2')
copyfile('AaKaiSong2.woff2')
copyfile('little-icons.woff2')

copyfile('divider-end.svg')
copyfile('divider-fleuron-cloudy.svg')
copyfile('divider-fleuron-heart.svg')
copyfile('divider-fleuron-windy.svg')

for i = 1, #cats do
  local pagelist = cats[i].pagelist or {}
  for j = 1, #pagelist do
    registeritem(pagelist[j].name, cats[i].name)
  end
end
registeritem('index', 'home')
registeritem('about', 'home')
registeritem('dates', 'home')
registeritem('pile', 'pile', {
  title = caisse.envadditions.tr(cats.pile.longtitle) or cats.pile.title
})
renderallitems()

renderpage('music', 'bannerlist.html', { curcat = 'music' })
renderpage('playful', 'bannerlist.html', { curcat = 'playful' })
renderpage('murmurs', 'bannerlist.html', { curcat = 'murmurs' })
renderpage('potpourri', 'bannerlist.html', { curcat = 'potpourri' })
