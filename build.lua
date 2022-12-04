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
  return dst
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
local function ffprobe(path, stream, entries)
  local cmd = 'ffprobe' ..
    ' -v error -hide_banner -print_format flat -of default=noprint_wrappers=1' ..
    ' -select_streams ' .. stream .. ' -show_entries ' .. entries ..
    ' "' .. path .. '"'
  local results = {}
  for line in io.popen(cmd):lines() do
    local key, value = table.unpack(split(line, '='))
    if key ~= '' then results[key] = value end
  end
  return results
end
caisse.envadditions.image = function (path, alt, class, style)
  local realpath
  realpath = sitepath .. path
  local w, h = inspectimage(realpath)
  return '<img src="' .. path .. '"' ..
    ' width=' .. w .. ' height=' .. h ..
    (alt and (' alt="' .. alt .. '"') or '') ..
    (class and (' class="' .. class .. '"') or '') ..
    (style and (' style="' .. style .. '"') or '') ..
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
  return '/' .. copyfile(path)
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

local filetypes = {
  -- Music and audio
  ogg = 'audio', mp3 = 'audio', wav = 'audio',
  mid = 'musicnotes', midi = 'musicnotes',
  mscz = 'score',
  -- Images
  png = 'image', jpg = 'image', jpeg = 'image', gif = 'image', webp = 'image',
  -- Video
  mp4 = 'video', ogv = 'video', webm = 'video',
  -- Text, code, and documents
  txt = 'document', pdf = 'document',
  c = 'code', h = 'code', lua = 'code', js = 'code',
}
local filetypeicons = {
  [''] = 0x1f4e6,
  audio = 0x1f3a7,
  musicnotes = 0x1f3b6,
  score = 0x1f3bc,
  image = 0x1f5bc,
  video = 0x1f39e,
  document = 0x1f4c3,
  code = 0x1f47e,
}
local filetypeextrainfo = {
  audio = function (path)
    local info = ffprobe(path, 'a:0', 'stream=duration')
    return lengthstring(math.floor(tonumber(info.duration)))
  end,
  video = function (path)
    local info = ffprobe(path, 'v:0', 'stream=width,height,duration')
    return lengthstring(math.floor(tonumber(info.duration))) .. ', ' ..
      info.width .. 'x' .. info.height
  end,
  ['.pdf'] = function (path)
    local npages
    local cmd = 'pdfinfo "' .. path .. '"'
    for line in io.popen(cmd):lines() do
      if line:find('^Pages:') then
        npages = tonumber(line:match('[0-9]+'))
        break
      end
    end
    if npages then return tostring(npages) ..
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
    local parts = split(fileurl, '/')
    local basename = parts[#parts]
    local dotpos = basename:find('.', 1, true)
    local ext = (dotpos == nil and '' or basename:sub(dotpos + 1))
    local filetype = filetypes[ext] or ''
    local icon = filetypeicons[filetype]
    local extrainfo = filetypeextrainfo[filetype] or filetypeextrainfo['.' ..ext]
    if extrainfo then extrainfo = extrainfo(sitepath .. fileurl) end
    return '<tr><td>' .. text .. '</td>' ..
      '<td><a class="pastel ' .. item.cat .. '" href="' ..
      fileurl ..  '">' ..
      '<span class="little-icons">&#x' .. string.format('%x', icon) ..
      ';</span><strong class="file-table-name">' .. basename .. '</strong>(' ..
      sizestring(size) ..
      (extrainfo and (', ' .. extrainfo) or '') .. ')</a></td>'
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
  blockquote = function (text)
    return '<blockquote>' .. text .. '</blockquote>'
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
registeritem('stray', 'stray', {
  title = caisse.envadditions.tr(cats.stray.longtitle) or cats.stray.title
})
renderallitems()

renderpage('music', 'bannerlist.html', { curcat = 'music' })
renderpage('playful', 'bannerlist.html', { curcat = 'playful' })
renderpage('murmurs', 'bannerlist.html', { curcat = 'murmurs' })
renderpage('sundry', 'bannerlist.html', { curcat = 'sundry' })
