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
local function filesize(src)
  -- macOS 10.14
  return io.popen('stat -f "%z" "' .. sitepath .. src .. '"'):read('n')
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
  copyfile(path)
  return '/bin/' .. path
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
-- %s/, /,\r/g
-- v/0x[0-9a-f]\+/d
-- %s/^.*0x\([0-9a-f]\+\).*$/\1/g
-- %!sort | uniq
local filetypeicons = {
  [''] = 0x1f4e6,
  -- Music and audio
  ogg = 0x1f3a7, mp3 = 0x1f3a7, wav = 0x1f3a7,
  mid = 0x1f3b6, midi = 0x1f3b6,
  mscz = 0x1f3bc,
  -- Images
  png = 0x1f5bc, jpg = 0x1f5bc, jpeg = 0x1f5bc, gif = 0x1f5bc, webp = 0x1f5bc,
  -- Video
  mp4 = 0x1f39e, ogv = 0x1f39e, webm = 0x1f39e,
  -- Text, code, and documents
  txt = 0x1f4c3, pdf = 0x1f4c3,
  c = 0x1f47e, h = 0x1f47e, lua = 0x1f47e, js = 0x1f47e,
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
    local item = itemreg[path]
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
    local fileurl = caisse.envadditions.file(src, 'items/' .. markupfnsenvitem)
    local size = filesize(fileurl)
    local sizestring
    if size < 1024 then
      sizestring = string.format('%d B', size)
    elseif size < 1024 * 100 then
      sizestring = string.format('%.1f KiB', size / 1024)
    elseif size < 1024 * 1024 then
      sizestring = string.format('%.0f KiB', size / 1024)
    elseif size < 1024 * 1024 * 100 then
      sizestring = string.format('%.1f MiB', size / (1024 * 1024))
    elseif size < 1024 * 1024 * 1024 then
      sizestring = string.format('%.0f MiB', size / (1024 * 1024))
    else
      sizestring = string.format('%.2f GiB', size / (1024 * 1024 * 1024))
    end
    local parts = split(fileurl, '/')
    local basename = parts[#parts]
    local dotpos = basename:find('.', 1, true)
    local ext = (dotpos == nil and '' or basename:sub(dotpos + 1))
    local filetypeicon = filetypeicons[ext] or filetypeicons['']
    return '<tr><td>' .. text .. '</td>' ..
      '<td><a class="pastel ' .. item.cat .. '" href="' ..
      fileurl ..  '">' ..
      '<span class="little-icons">&#x' .. string.format('%x', filetypeicon) ..
      ';</span><strong class="file-table-name">' .. basename .. '</strong>(' ..
      sizestring .. ')</a></td>'
  end,
  h1 = function (text)
    return '<h1>' .. htmlescape(text) .. '</h1>'
  end,
  list = function (contents)
    return '<ul>' .. contents .. '</ul>'
  end,
  li = function (text)
    return '<li>' .. htmlescape(text) .. '</li>'
  end,
  cen = function (text)
    return '<p style="text-align: center">' .. text .. '</p>'
  end,
  kao = function (text)
    local function fxhash(s)
      local h = 0
      for i = 1, #s do
        h = ((h << 5) ~ string.byte(s, i)) * 0x517cc1b727220a95
      end
      return string.format('%016x', h)
    end
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
registeritem('sundry', 'sundry', {
  title = caisse.envadditions.tr(cats.sundry.longtitle) or cats.sundry.title
})
registeritem('stray', 'stray', {
  title = caisse.envadditions.tr(cats.stray.longtitle) or cats.stray.title
})
renderallitems()

renderpage('music', 'bannerlist.html', { curcat = 'music' })
renderpage('playful', 'bannerlist.html', { curcat = 'playful' })
renderpage('murmurs', 'bannerlist.html', { curcat = 'murmurs' })
