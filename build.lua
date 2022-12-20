local caisse = require('caisse/caisse')
local rendermarkup = require('caisse/markup')

os.setlocale('C')

caisse.envadditions.siteroot = 'http://localhost:1123'
caisse.envadditions.domain = 'ayuu.ink'

local postproc = require('postproc')

local srcpath = 'content/'
local sitepath = 'build/'

caisse.readfile = function (path)
  local f = io.open(srcpath .. path, 'r')
  if f then return f:read('a') end
end
os.execute('rm -rf ' .. sitepath)
os.execute('mkdir ' .. sitepath)

local bufferedcmds = {}

local function writefile(file, s) io.open(file, 'w'):write(s) end
--local function writefile(file, s) end
-- `filepath` is an absolute path without the leading slash
local existingdirs = {}
local function ensuredir(filepath)
  local dirname = filepath:match('^(.*)/')
  if dirname and not existingdirs[dirname] then
    os.execute('mkdir -p "' .. sitepath .. dirname .. '"')
    existingdirs[dirname] = true
  end
end
local contentpath = {}
-- `src` is an absolute path without the leading slash
local function copydst(src)
  local dst
  if src:find('^items/') then
    dst = src:sub(7)
  else
    dst = 'bin/' .. src
  end
  ensuredir(dst)
  return dst
end

local function basehash(s)
  local h = 0
  for i = 1, #s do
    h = h * 997 + string.byte(s, i) + 1
  end
  return string.format('%08x', (h >> 32) ~ (h & ((1 << 32) - 1)))
end
caisse.envadditions.basehash = basehash

local function hashverhash(hash, targetpath)
  local name, ext = targetpath:match('(.+)%.([^./]+)')
  local pathwithver
  if name ~= nil then
    pathwithver = name .. '.' .. hash .. '.' .. ext
  else
    pathwithver = targetpath .. '.' .. hash
  end
  return pathwithver
end
local function hashverstr(str, targetpath)
  local hash = basehash(str)
  return hashverhash(hash, targetpath), hash
end
local filehashreg = {}
local function hashverfile(path, targetpath)
  local hash = filehashreg[path]
  if hash == nil then
    hash = basehash(io.open(srcpath .. path):read('a'))
    filehashreg[hash] = hash
  end
  return hashverhash(hash, targetpath or path)
end
caisse.envadditions.hashverfile = hashverfile

local function copyfile(src, ishashver)
  local dst = copydst(src)
  if ishashver then dst = hashverfile(src, dst) end
  if contentpath[dst] then return dst end
  -- Hard link
  bufferedcmds[#bufferedcmds + 1] =
    'ln "' .. srcpath .. src .. '" "' .. sitepath .. dst .. '"'
  contentpath[dst] = src
  return dst
end
local function copydir(src)
  local dst = copydst(src)
  if contentpath[dst] then return dst end
  -- Symbolic link
  bufferedcmds[#bufferedcmds + 1] =
    'ln -s ' ..
    '"$(realpath --relative-to="$(dirname "' .. sitepath .. dst .. '")" "' .. srcpath .. src .. '")" ' ..
    '"' .. sitepath .. dst .. '"'
  contentpath[dst] = src
  return dst
end
local function render(...)
  return caisse.render(...)
end
local function renderpage(savepath, templatepath, locals)
  locals = locals or {}
  local contents = render(templatepath, locals)
  local filepath = savepath .. '/index.' .. caisse.lang .. '.html'
  ensuredir(filepath)
  writefile(sitepath .. filepath,
    postproc.html(render('framework.html', {
      savepath = savepath,
      title = locals.title,
      curcat = locals.curcat,
      contents = contents,
    })))
end
local function renderraw(savepath, templatepath, locals, ishashver)
  locals = locals or {}
  local contents = render(templatepath, locals)
  if ishashver then
    savepath, hash = hashverstr(contents, savepath)
    filehashreg[templatepath] = hash
  end
  ensuredir(savepath)
  writefile(sitepath .. savepath, contents)
end

local function seq(start, finish, step)
  step = step or 1
  local ret = {}
  for i = start, finish, step do ret[#ret + 1] = i end
  return ret
end
caisse.envadditions.seq = seq

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

local datecache = {}
local function renderdate(datestr, nolink)
  local content
  if datecache[datestr] then
    content = datecache[datestr]
  else
    local dates = {}
    for year, term in datestr:gmatch('([0-9]+)%.([0-9]+)') do
      dates[#dates + 1] = { year = tonumber(year, 10), term = tonumber(term, 10) }
    end
    content = render('date.html', { dates = dates })
    datecache[datestr] = content
  end
  if not nolink then
    content = '<a href="/dates" class="hidden-pastel date-term-link">'
      .. content .. '</a>'
  end
  return content
end
caisse.envadditions.renderdate = renderdate

local AaKaiSong_css = io.open('misc/typeface/AaKaiSong.css'):read('a')
caisse.envadditions.AaKaiSong_css = AaKaiSong_css

local cats = render('categories.txt').cats

local itemreg = {}
local function registeritemmarkup(path, curcat, extralocals, pageextralocals)
  if itemreg[path] then return end
  -- `path` is the path in URL, without the leading `/`
  local locals = render('items/' .. path .. '/page.txt', pageextralocals)
  local extrastyle = caisse.readfile('items/' .. path .. '/page.css')
  if extrastyle then locals.extrastyle = extrastyle end
  if extralocals then
    for k, v in pairs(extralocals) do locals[k] = v end
  end
  itemreg[path] = {
    cat = curcat,
    locals = locals,
  }
end
local function registeritemtempl(path, curcat, templatepath, extralocals)
  itemreg[path] = {
    cat = curcat,
    locals = extralocals or {},
    template = templatepath,
  }
end
local function registeritemfile(path, curcat)
  itemreg[path] = { cat = curcat, isfile = true }
end
local function registeritemempty(path, curcat)
  itemreg[path] = { cat = curcat, isempty = true }
end

-- KaTeX prerendering registry
local katexrendered = {}
local katexf = io.open('misc/katex/rendered.txt')
if katexf then
  for line in katexf:lines() do
    local tabpos = line:find('\t')
    katexrendered[line:sub(1, tabpos - 1)] = line:sub(tabpos + 1):gsub('\t', '\n')
  end
  katexf:close()
end
local katexstringlist = {}
local function katexrender(string, isdisp)
  string = string:match('^%s*(.-)%s*$'):gsub('\t', ' ')
  local hash = basehash(string)
  katexstringlist[#katexstringlist + 1] =
    hash .. (isdisp and '\t1\t' or '\t0\t') .. string:gsub('\n', '\t')
  return katexrendered[hash] or '(formula not rendered)'
end

-- Base64
local base64seq = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64encode(s)
  local bits = {}
  for i = 1, #s do
    local b = s:byte(i)
    for j = 7, 0, -1 do bits[#bits + 1] = (b >> j) & 1 end
  end
  while #bits % 6 ~= 0 do bits[#bits + 1] = 0 end
  while #bits % 24 ~= 0 do bits[#bits + 1] = -1 end
  local output = {}
  for i = 1, #bits, 6 do
    if bits[i] == -1 then output[#output + 1] = '='
    else
      output[#output + 1] = string.char(base64seq:byte(
        (bits[i + 0] << 5) + (bits[i + 1] << 4) + (bits[i + 2] << 3) +
        (bits[i + 3] << 2) + (bits[i + 4] << 1) + (bits[i + 5] << 0) + 1
      ))
    end
  end
  return table.concat(output)
end
caisse.envadditions.base64encode = base64encode

local htmlescapelookup = {
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['&'] = '&amp;',
}
local function htmlescape(s)
--[[
  local cps = {utf8.codepoint(s, 1, #s)}
  for i = 1, #cps do
    if cps[i] == utf8.codepoint('!') then cps[i] = '!'
    else cps[i] = string.format('&#x%x;', cps[i]) end
  end
  return table.concat(cps)
]]
  return s:gsub('[%<%>%&]', htmlescapelookup)
end
caisse.envadditions.htmlescape = htmlescape

local function uriescape(s)
  return s:gsub(' ', '%%20')
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
local function durstring(seconds)
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
    return durstring(tonumber(dur))
  end,
  video = function (dur, w, h)
    return durstring(tonumber(dur)) .. ', ' .. w .. 'x' .. h
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

local function heading(tag, text)
  local bodytext, anchor = text:match('^(.+[^%s])%s*#([^#]*)$')
  if bodytext then text = bodytext end
  return '<' .. tag ..
    (anchor and (' id="' .. anchor .. '"') or '') ..
    '>' .. text .. '</' .. tag .. '>'
end

local markupfnsenvitem  -- Item name of the item currently being processed
local markupfns
markupfns = {
  ['-'] = function (line)
    if line == '' then return ''
    elseif line:sub(1, 1) == '!' then return line:sub(2) .. '\n'
    else return '<p>' .. line .. '</p>' end
  end,
  ['^'] = htmlescape,
  rawhtml = function (text) return text end,
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
  tt = function (text)
    return '<span class="tt">' .. text .. '</span>'
  end,
  lang = function (lang, text)
    return '<span lang="' .. lang .. '">' .. text .. '</span>'
  end,
  nobr = function (text)
    return '<span class="no-break">' .. text .. '</span>'
  end,
  rawlink = function (href, text)
    return '<a href="' .. href .. '">' .. htmlescape(text) .. '</a>'
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
  subpagelink = function (path, text)
    local itemname = split(path, '/')[1]
    local item = itemreg[itemname]
    copydir('items/' .. path)
    return '<a class="pastel ' .. item.cat .. '" href="/' .. path .. '">'
      .. htmlescape(text) .. '</a>'
  end,
  img = function (src, alt, class)
    return '<div class="image-container">' ..
      caisse.envadditions.image(
        caisse.envadditions.file(src, 'items/' .. markupfnsenvitem),
        alt, class) ..
      (class:find('caption') and ('<p>' .. htmlescape(alt) .. '</p>') or '') ..
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
    return '<tr><td>' .. htmlescape(text) .. '</td>' ..
      '<td><a class="pastel ' .. item.cat .. '" href="' ..
      uriescape(fileurl) ..  '">' ..
      '<span class="little-icons">&#x' .. string.format('%x', icon) ..
      ';</span><strong class="file-table-name">' .. htmlescape(basename) .. '</strong>(' ..
      htmlescape(sizestring(size) ..
        (extrainfo and (', ' .. extrainfo) or '')) .. ')</a></td>'
  end,
  h1 = function (text) return heading('h1', text) end,
  h2 = function (text) return heading('h2', text) end,
  h3 = function (text) return heading('h3', text) end,
  list = function (...)
    return '<ul>' .. table.concat({...}) .. '</ul>'
  end,
  listcompact = function (...)
    return '<ul class="compact">' .. table.concat({...}) .. '</ul>'
  end,
  li = function (text)
    return '<li>' .. text .. '</li>'
  end,
  cen = function (text)
    return '<p class="text-center">' .. text .. '</p>'
  end,
  blockquote = function (text)
    return '<blockquote class="quote">' .. text .. '</blockquote>'
  end,
  note = function (text)
    return '<blockquote class="note">' .. text .. '</blockquote>'
  end,
  clearfloat = function ()
    return '<div style="clear: both"></div>'
  end,
  table = function (...)
    return '<div class="table-container"><table>'
      .. table.concat({...}) .. '</table></div>'
  end,
  tr = function (...) return '<tr>' .. table.concat({...}) .. '</tr>' end,
  th = function (text) return '<th>' .. text .. '</th>' end,
  td = function (text) return '<td>' .. text .. '</td>' end,
  tdspan = function (rowspan, colspan, text)
    return '<td rowspan="' .. rowspan .. '" colspan="' .. colspan .. '">' .. text .. '</td>'
  end,
  date = function (datestr)
    return renderdate(datestr)
  end,
  kao = function (text)
    return '<span class="kaomoji">' ..
      io.open('misc/kaomoji/gen/moji-' .. basehash(text) .. '.svg'):read('a') ..
      '</span>'
  end,
  gridtable = function (class, ...)
    local builder = {'<div class="' .. class .. '">', ...}
    for i = 2, #builder do
      builder[i] = '<div>' .. builder[i] .. '</div>'
    end
    builder[#builder + 1] = '</div>'
    return table.concat(builder)
  end,
  musictrack = function (artist, title, origtitle, image, alt)
    -- Extract composer and vocalist from artist
    local artiststr
    local slashpos = artist:find('//', 1, true)
    if slashpos ~= nil then
      local composer, vocalist = artist:sub(1, slashpos - 1), artist:sub(slashpos + 2)
      artiststr =
        '<span class="little-icons">&#x1f58c;</span>' .. composer ..
        ' / <span class="little-icons">&#x1f3a4;</span>' .. vocalist
    else
      artiststr =
        '<span class="little-icons">&#x1f3b6;</span>' .. artist
    end
    -- Extract album name from original title
    slashpos = origtitle:find('//', 1, true)
    if slashpos ~= nil then
      local title, album = origtitle:sub(1, slashpos - 1), origtitle:sub(slashpos + 2)
      origtitle =
        title .. ' / <span class="little-icons">&#x1f4bf;</span>' .. album
    end
    return '<div class="music-track">' ..
      (image and
        '<img src="' .. caisse.envadditions.file(image, 'items/' .. markupfnsenvitem) ..
        (alt and ('" alt="' .. alt) or '') .. '">'
       or '') ..
      '<div><strong>' .. title .. '</strong><br>' ..
      (origtitle ~= '' and ('<span class="orig-title">' .. origtitle .. '</span>') or '') ..
      artiststr ..
      '</div></div>'
  end,
  math = function (string) return katexrender(string, false) end,
  dispmath = function (string) return katexrender(string, true) end,
}
caisse.envadditions.rendermarkup = function (s)
  return rendermarkup(s, markupfns)
end

local function renderallitems()
  for path, item in pairs(itemreg) do
    if item.isempty then  -- No-op
    elseif item.isfile then copyfile(path)
    else
      local locals = item.locals
      locals.name = path
      locals.curcat = item.cat
      print(item.cat, caisse.envadditions.tr(locals.title))
      if item.template ~= nil then
        renderpage(path, item.template, item.locals)
      else
        -- Markup
        markupfnsenvitem = path
        renderpage(path, 'item.html', locals)
        markupfnsenvitem = nil
      end
    end
  end
end

local function trmerge(...)
  local origlang = caisse.lang
  local merged = {}
  local all = {...}
  for _, lang in ipairs({'zh', 'en'}) do
    caisse.lang = lang
    for i = 1, #all do
      local w = caisse.envadditions.tr(all[i])
      if w then
        merged[lang] = w
        break
      end
    end
  end
  caisse.lang = origlang
  return merged
end

-- Site content

copyfile('background.svg', true)
copyfile('background-dark.svg', true)
copyfile('top-fleuron.svg', true)
copyfile('chalk-bg-w.png', true)
copyfile('chalk-bg-b.png', true)

copyfile('divider-end.svg', true)
copyfile('divider-fleuron-cloudy.svg', true)
copyfile('divider-fleuron-heart.svg', true)
copyfile('divider-fleuron-windy.svg', true)

renderraw('bin/main.css', 'main.css', nil, true)
copydir('fonts')
copydir('katex')

for i = 1, #cats do
  local pagelist = cats[i].pagelist or {}
  for j = 1, #pagelist do
    registeritemmarkup(pagelist[j].name, cats[i].name)
  end
end
registeritemmarkup('index', 'home')
registeritemmarkup('about', 'home')
registeritemmarkup('dates', 'home')

local revloglatest = 2022*12 + 11
local revlogfirst = 2022*12 + 10
registeritemmarkup('revlog', 'home', nil, { revloglatest = revloglatest, revlogfirst = revlogfirst })
for _, lang in ipairs({'zh', 'en'}) do
  registeritemempty('rss.' .. lang .. '.xml', 'home')
  registeritemempty('atom.' .. lang .. '.xml', 'home')
  renderraw('rss.' .. lang .. '.xml', 'items/revlog/rss.xml',
    { lang = lang, revloglatest = revloglatest, revlogfirst = revlogfirst })
  renderraw('atom.' .. lang .. '.xml', 'items/revlog/atom.xml',
    { lang = lang, revloglatest = revloglatest, revlogfirst = revlogfirst })
end

registeritemtempl('music', 'music', 'bannerlist.html')
registeritemtempl('playful', 'playful', 'bannerlist.html')
registeritemtempl('murmurs', 'murmurs', 'bannerlist.html')
registeritemtempl('potpourri', 'potpourri', 'bannerlist.html', { compact = true })
registeritemmarkup('pebbles', 'pebbles', {
  title = trmerge(cats.pebbles.longtitle, cats.pebbles.title)
})

for _, lang in ipairs({'zh', 'en'}) do
  caisse.lang = lang
  caisse.envadditions.lang = caisse.lang
  renderallitems()
end

os.execute(table.concat(bufferedcmds, '; '))
io.open('misc/katex/list.txt', 'w'):write(table.concat(katexstringlist, '\n')):close()
