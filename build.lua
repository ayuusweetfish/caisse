local caisse = require('caisse/caisse')
local rendermarkup = require('caisse/markup')

os.setlocale('C')

caisse.envadditions.sitename = { zh = '甜鱼/Ayu', en = 'Sweetfish Ayu' }
caisse.envadditions.siteroot = 'https://ayu.land'
caisse.envadditions.domain = 'ayu.land'
caisse.envadditions.distbuild = (os.getenv('DIST') == '1')

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

local function copyfile(src, ishashver, dstsuffix)
  local dst = copydst(src)
  if ishashver then dst = hashverfile(src, dst) end
  if dstsuffix then
    dst = dst .. dstsuffix
    ensuredir(dst)
  end
  if contentpath[dst] then return dst end
  if caisse.envadditions.distbuild then
    bufferedcmds[#bufferedcmds + 1] =
      'cp "' .. srcpath .. src .. '" "' .. sitepath .. dst .. '"'
  else
    -- Hard link
    bufferedcmds[#bufferedcmds + 1] =
      'ln "' .. srcpath .. src .. '" "' .. sitepath .. dst .. '"'
  end
  contentpath[dst] = src
  return dst
end
local function copydir(src)
  local dst = copydst(src)
  if contentpath[dst] then return dst end
  if caisse.envadditions.distbuild then
    -- Recursive copy
    bufferedcmds[#bufferedcmds + 1] =
      'cp -r "' .. srcpath .. src .. '" "' .. sitepath .. dst .. '"'
  else
    -- Symbolic link
    local dircompcount = select(2, (sitepath .. dst):gsub('[^/]+/', ''))
    bufferedcmds[#bufferedcmds + 1] =
      'ln -s ' ..
      '"' .. string.rep('../', dircompcount) .. srcpath .. src .. '" ' ..
      '"' .. sitepath .. dst .. '"'
  end
  contentpath[dst] = src
  return dst
end
local function render(...)
  return caisse.render(...)
end
local function renderlang(lang, ...)
  local origlang = caisse.lang
  caisse.lang = lang
  local result = caisse.render(...)
  caisse.lang = origlang
  return result
end
caisse.envadditions.renderlang = renderlang
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
      aside = locals.aside or {},
      h_entry = locals.h_entry,
    })))
end
local function renderraw(savepath, templatepath, locals, ishashver, filter)
  locals = locals or {}
  local contents = render(templatepath, locals)
  if filter then contents = filter(contents) end
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
for _, path in ipairs({
  'misc/stat/database.tsv', 'content/items/backyard/stat_database.tsv'
}) do
  for line in io.open(path, 'r'):lines() do
    local fields = split(line, '\t')
    filedb[fields[1]] = {
      size = tonumber(fields[2]),
      type = fields[3],
      args = {table.unpack(fields, 4)},
    }
  end
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

local highlightmap = {
  ['cc'] = 'cpp',
  ['ino'] = 'cpp',
}
local contentfile = function (path, curcat, iscode)
  local origlang = caisse.lang
  path = fullpath(path, wd)
  local origdst = copydst(path)
  if iscode then
    copyfile(path, false, '/raw')
    local mainname, ext = path:match('/([^/]*)%.([^.]+)$')
    for _, lang in ipairs({'zh', 'en'}) do
      caisse.lang = lang
      caisse.envadditions.lang = caisse.lang
      renderpage(origdst, 'code.html', {
        curcat = curcat,
        title = mainname .. '.' .. ext,
        code = caisse.readfile(path),
        highlightlang = highlightmap[ext] or ext,
      })
    end
  else
    copyfile(path)
  end
  caisse.lang = origlang
  caisse.envadditions.lang = origlang
  return '/' .. origdst
end

caisse.envadditions.highlightcode = function (text, linenum)
  local pos = text:find('\n')
  local lang = text:sub(1, pos - 1)
  local s = text:sub(pos + 1)
  local hash = basehash(s)
  local f = io.open('misc/highlight/res.' .. hash .. '.' .. lang .. '.html', 'r')
  if not f then
    f = io.open('misc/highlight/src.' .. hash .. '.' .. lang, 'w')
    f:write(s)
    f:close()
    return '<pre class="code">(code not rendered)</pre>'
  end
  local result = f:read('a')
  f:close()
  if linenum then
    -- string.gmatch does not properly handle nesting
    local lines = split(result, '<span class="line">')
    table.remove(lines, 1)
    local len = #tostring(#lines)
    local pad = function (s) return string.rep('&nbsp;', len - #s) .. s end
    local processed = {}
    for i, line in ipairs(lines) do
      processed[#processed + 1] = '<a class="line-num'
        .. (i % 10 == 0 and ' line-num-accent' or '')
        .. '" id="L'
        .. tostring(i) .. '" href="#L' .. tostring(i) .. '">'
        .. pad(tostring(i)) .. '</a><span class="line">'
      processed[#processed + 1] = line
    end
    result = table.concat(processed)
  end
  return '<pre class="code'
    .. (linenum and ' with-line-num' or '')
    .. ' chroma">' .. result .. '</pre>'
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
  if datecache[caisse.lang .. datestr] then
    content = datecache[caisse.lang .. datestr]
  else
    local dates = {}
    for year, term in datestr:gmatch('([0-9]+)%.([0-9]+)') do
      dates[#dates + 1] = { year = tonumber(year, 10), term = tonumber(term, 10) }
    end
    content = render('date.html', { dates = dates })
    datecache[caisse.lang .. datestr] = content
  end
  if not nolink then
    content = '<a href="/dates" class="hidden-pastel date-term-link">'
      .. content .. '</a>'
  end
  return content
end
caisse.envadditions.renderdate = renderdate

-- Chinese font subsetting
local AaKaiSong_css = io.open('misc/typeface-zh/AaKaiSong.css'):read('a')
caisse.envadditions.AaKaiSong_css = AaKaiSong_css
local AaKaiSong_subsethashes = {}
local typefacestrayrec = io.open('misc/typeface-zh/stray.txt')
if typefacestrayrec then
  for line in typefacestrayrec:lines() do
    local tabpos = line:find('\t')
    local docid = line:sub(1, tabpos - 1)
    local h = 0
    for w in line:gmatch('[0-9a-f]+', tabpos + 1) do
      h = h * 100019 + tonumber(w, 16) + 1
    end
    AaKaiSong_subsethashes[docid] =
      string.format('%08x', (h >> 32) ~ (h & ((1 << 32) - 1)))
  end
  typefacestrayrec:close()
end
local function AaKaiSong_subsethash(docid)
  local hash = AaKaiSong_subsethashes[docid]
  return hash
end
caisse.envadditions.AaKaiSong_subsethash = AaKaiSong_subsethash

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
local function registeritemtempl(path, curcat, templatepath, extralocals, pagination)
  itemreg[path] = {
    cat = curcat,
    locals = extralocals or {},
    template = templatepath,
    pagination = pagination,
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

-- Dates
caisse.envadditions.accuratetime = function (utc, tz)
  local tz = tz or 8
  local Y, M, D, h, m, s, ms =
    utc:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)Z')
  return os.date('%F %T', os.time({
    year = Y, month = M, day = D,
    hour = h + tz, min = m, sec = s
  }))
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
caisse.envadditions.sizestring = sizestring
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

local markupfnsenvitem  -- Item name of the item currently being processed
local markupfns

local function splitheading(text)
  local bodytext, anchor = text:match('^(.+[^%s])%s*#([^#]*)$')
  if bodytext then return bodytext, anchor
  else return text, nil end
end
local function heading(tag, text)
  local bodytext, anchor = splitheading(text)
  return '<' .. tag ..
    (anchor and (' id="' .. anchor .. '"') or '') ..
    '>' .. bodytext .. '</' .. tag .. '>'
end

local function itemlink(path, text, israw)
  local itemname = path
  if path:sub(1, 1) == '#' or path:sub(1, 1) == '?' then
    itemname = markupfnsenvitem
    path = itemname .. path
  else
    local hashpos = path:find('#')
    if hashpos ~= nil then
      itemname = path:sub(1, hashpos - 1)
      local anchor = path:sub(hashpos + 1)
      if text == '' then text = anchor end
    end
  end
  local item = itemreg[itemname]
  if not item then
    text = (text ~= '' and text or path)
    if israw then
      return '<a href="' .. path .. '">' .. text .. '</a>'
    else
      return markupfns.extlink(path, text)
    end
  end
  if text == '' then text = '%' end
  text = text:gsub('%%%%?', function (s)
    if s == '%%' then return '%'
    else return caisse.envadditions.tr(item.locals.title) end
  end)
  if israw then
    return '<a href="' .. caisse.envadditions.siteroot .. '/' .. path .. '">'
      .. text .. '</a>'
  else
    return '<a class="pastel ' .. item.cat .. '" href="/' .. path .. '">'
      .. text .. '</a>'
  end
end

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
  it = function (text)
    return '<i>' .. text .. '</i>'
  end,
  br = function () return '<br><span class="br-indent"></span>' end,
  hr = function (class)
    return '<div role="separator"' ..
      (class ~= '' and ' class="' .. class .. '"' or '') ..
      '></div>'
  end,
  marker = function (class) return '<span class="' .. class .. '"></span>' end,
  pre = function (text)
    return '<pre>' .. text .. '</pre>'
  end,
  code = function (text)
    return caisse.envadditions.highlightcode(text)
  end,
  tt = function (text)
    return '<span class="tt">' .. text .. '</span>'
  end,
  wbrs = function (text)
    return text:gsub('/', '<wbr>/<wbr>')
  end,
  lang = function (lang, text)
    return '<span lang="' .. lang .. '">' .. text .. '</span>'
  end,
  nobr = function (text)
    return '<span class="no-break">' .. text .. '</span>'
  end,
  allbr = function (text)
    return '<span class="all-break">' .. text .. '</span>'
  end,
  title = function (title, text)
    return '<span title="' .. title .. '">' .. text .. '</span>'
  end,
  hovernote = function (text, note)
    return '<span title="' .. note .. '" class="pastel noexpand hovernote">' .. text .. '</span>'
  end,
  symbols = function (text)
    return '<span class="symbols">' .. text .. '</span>'
  end,
  rawlink = function (href, text)
    return '<a href="' .. href .. '">' .. text .. '</a>'
  end,
  extlink = function (href, text)
    return '<a class="pastel external" href="' .. href .. '" target="_blank">'
      .. text
      .. '<sup class="little-icons">&#x1fa90;</sup>'
      .. '</a>'
  end,
  catlink = function (path, cat, text)
    return '<a class="pastel ' .. cat .. '" href="' .. path .. '">'
      .. text .. '</a>'
  end,
  link = function (path, text) return itemlink(path, text, false) end,
  subpagelink = function (path, text)
    local itemname = split(path, '/')[1]
    local item = itemreg[itemname]
    copydir('items/' .. path)
    return '<a class="pastel ' .. item.cat .. '" href="/' .. path .. '">'
      .. htmlescape(text) .. '</a>'
  end,
  anchor = function (id)
    return '<a id="' .. id .. '"></a>'
  end,
  relme = function (text)
    return text:gsub('^<a ', '<a rel="me" ')
  end,
  img = function (src, alt, class)
    local altmain, altcap = alt:match('^([^/]*)//(.*)$')
    if altmain then alt = altmain end
    return '<div class="image-container">' ..
      caisse.envadditions.image(
        caisse.envadditions.file(src, 'items/' .. markupfnsenvitem),
        alt, class) ..
      (class:find('caption') and ('<p>' .. (altcap or alt) .. '</p>') or '') ..
      '</div>'
  end,
  filetable = function (contents)
    return '<table class="file-table"><tbody>' .. contents .. '</tbody></table>'
  end,
  file = function (src, text)
    local item = itemreg[markupfnsenvitem]
    local fullpath = fullpath(src, 'items/' .. markupfnsenvitem)
    local filetype = fileinfo(fullpath).type
    local fileurl = contentfile(fullpath, curcat, filetype == 'code')
    local size = fileinfo(fullpath).size
    local parts = split(fileurl, '/')
    local basename = parts[#parts]
    local icon = filetypeicons[filetype]
    local extrainfo = filetypeextrainfo[filetype]
    if extrainfo then
      extrainfo = extrainfo(table.unpack(fileinfo(fullpath).args))
    end
    return '<tr><td>' .. text .. '</td>' ..
      '<td><a class="pastel ' .. item.cat .. '" href="' ..
      uriescape(fileurl) ..  '" target="_blank">' ..
      '<span class="little-icons">&#x' .. string.format('%x', icon) ..
      ';</span><strong class="file-table-name">' .. htmlescape(basename) .. '</strong>(' ..
      htmlescape(sizestring(size) ..
        (extrainfo and (', ' .. extrainfo) or '')) .. ')</a></td>'
  end,
  h1 = function (text) return heading('h2', text) end,
  h2 = function (text) return heading('h3', text) end,
  h3 = function (text) return heading('h4', text) end,
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
    return '<blockquote class="quote"><div class="quote-main">' .. text .. '</div></blockquote>'
  end,
  blockquoteby = function (by, text)
    return '<blockquote class="quote"><div class="quote-main">' .. text .. '</div>' ..
      '<div class="quote-by">' .. by .. '</div></blockquote>'
  end,
  note = function (text)
    return '<blockquote class="note"><div class="quote-main">' .. text .. '</div></blockquote>'
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
  musictrack = function (artist, title, origtitle, image, link, alt)
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
    return '<a class="music-track-link" href="' .. link .. '"><div class="music-track">' ..
      (image and
        '<img src="' .. caisse.envadditions.file(image, 'items/' .. markupfnsenvitem) ..
        '" alt="' .. alt .. '">'
       or '') ..
      '<div class="music-track-gap"></div>' ..
      '<div><strong>' .. title .. '</strong><br>' ..
      (origtitle ~= '' and ('<span class="orig-title">' .. origtitle .. '</span>') or '') ..
      '<span class="music-track-artist">' .. artiststr .. '</span>' ..
      '</div></div></a>'
  end,

  math = function (string) return katexrender(string, false) end,
  dispmath = function (string) return katexrender(string, true) end,

  chordtab = function (s)
    local lines = split(s, '\n')
    local list = {}
    local paropen = false
    local firstpar = true
    for i = 1, #lines do
      local line = lines[i]
      if line == '' then
        if paropen then
          list[#list + 1] = '</div>'
          paropen = false
          firstpar = false
        end
      else
        local p = 1
        local nextchord = ''
        local first = true
        while p <= #line + 1 do
          local q = line:find('[', p, true) or (#line + 1)
          if p ~= 1 or p < q then
            if not paropen then
              if not firstpar then
                list[#list + 1] = '<div role="separator" class="cloudy"></div>'
              end
              list[#list + 1] = '<div class="chord-tab-par">'
              paropen = true
            end
            if first then
              list[#list + 1] = '<div class="chord-tab-row">'
              first = false
            end
            list[#list + 1] = '<div class="chord-tab-item' ..
                (nextchord == '' and ' chord-tab-item-empty' or '') .. '">' ..
              '<span class="chord-tab-chord">' ..
                nextchord:gsub('*', 'ø')
                  :gsub('[()M7913o+%-,ø]+', '<sup>%1</sup>') ..
              '</span><span class="chord-tab-text">' ..
                line:sub(p, q - 1) ..
              '</span></div>'
          end
          local r = line:find(']', q + 1, true) or (#line + 1)
          nextchord = line:sub(q + 1, r - 1)
          p = r + 1
        end
        if not first then list[#list + 1] = '</div>' end
      end
    end
    if paropen then list[#list + 1] = '</div>' end
    return '<div class="chord-tab">' ..
      table.concat(list) .. '</div>'
  end,

  base64 = function (text)
    local title = tr({
      zh = '请使用 Base64 解码工具揭晓明文',
      en = 'Please use a Base64 decoding tool to reveal the text',
    })
    return '<span title="' .. title .. '" class="pastel noexpand hovernote">' ..
      '<span class="tt all-break">' .. base64encode(text) .. '</span>' ..
      '</span>'
  end
}
caisse.envadditions.rendermarkup = function (s, item)
  local oldmarkupfnsenvitem = markupfnsenvitem
  if item then markupfnsenvitem = item end
  local result = rendermarkup(s, markupfns)
  if item then markupfnsenvitem = oldmarkupfnsenvitem end
  return result
end
-- Used by XML feeds
caisse.envadditions.rendermarkupabslink = function (s)
  local oldlinkfn = markupfns.link
  markupfns.link = function (path, text) return itemlink(path, text, true) end
  local result = rendermarkup(s, markupfns)
  markupfns.link = oldlinkfn
  return result
end

local function markupheadings(s)
  local list = {}
  local function fn(n, w)
    local text, anchor = splitheading(w)
    if anchor ~= nil then
      list[#list + 1] = {n, text, anchor}
    end
  end
  rendermarkup(s, {
    h1 = function (w) fn(1, w) return '' end,
    h2 = function (w) fn(2, w) return '' end,
    h3 = function (w) fn(3, w) return '' end,
    lang = markupfns.lang,
  }, true)
  return list
end
caisse.envadditions.markupheadings = markupheadings

local renderlist = split(os.getenv('render') or '', ',')
local renderquery = nil
if renderlist[1] ~= '' then
  renderquery = {}
  for _, item in ipairs(renderlist) do renderquery[item] = true end
end

local function renderallitems()
  local catalogue = {}
  for path, item in pairs(itemreg) do if renderquery == nil or renderquery[path] or path:sub(1, 2) == '_/' then
    if item.isempty then  -- No-op
    elseif item.isfile then copyfile(path)
    else
      local locals = item.locals
      locals.name = path
      locals.curcat = item.cat
      if item.template ~= nil then
        if item.pagination ~= nil then
          local list = item.pagination.list
          local perpage = item.pagination.perpage
          local var = item.pagination.name
          local pagestotal = math.ceil(#list / perpage)
          locals.pagenumtotal = pagestotal
          locals.mainsavepath = path
          for i = 1, pagestotal do
            local locals2 = {}
            for k, v in pairs(locals) do locals2[k] = v end
            local listseg = {}
            for j = 1, perpage do listseg[j] = list[(i - 1) * perpage + j] end
            locals2.pagenum = i
            locals2[var] = listseg
            renderpage(path .. (i == 1 and '' or '/p' .. i), item.template, locals2)
          end
        else
          renderpage(path, item.template, locals)
        end
      else
        -- Markup
        markupfnsenvitem = path
        renderpage(path, 'item.html', locals)
        markupfnsenvitem = nil
      end
      if path:sub(1, 9) ~= 'backyard/' and path ~= 'index' and path:sub(1, 2) ~= '_/' then
        local title = caisse.envadditions.tr(locals.title)
        print(item.cat, title)
        catalogue[#catalogue + 1] = {
          path = path,
          cat = item.cat,
          title = title,
        }
      end
    end
  end end
  table.sort(catalogue, function (a, b) return a.path < b.path end)
  return catalogue
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

copyfile('favicon.png')

copyfile('background.svg', true)
copyfile('background-dark.svg', true)
copyfile('top-fleuron.svg', true)
copyfile('chalk-bg-w.png', true)
copyfile('chalk-bg-b.png', true)
copyfile('puffs.svg', true)

copyfile('divider-end.svg', true)
copyfile('divider-fleuron-cloudy.svg', true)
copyfile('divider-fleuron-heart.svg', true)
copyfile('divider-fleuron-windy.svg', true)

renderraw('bin/main.css', 'main.css', nil, true, postproc.css)
renderraw('bin/main.js', 'main.js', nil, true)
for _, fontname in ipairs({
  'Livvic-Regular', 'Livvic-SemiBold', 'Livvic-Medium',
  'Sono_Monospace-Regular', 'Sono_Monospace-SemiBold',
  'OpenSans-Regular-Greek',
  'little-icons',
}) do
  copyfile('fonts/' .. fontname .. '.woff2', true)
  copyfile('fonts/' .. fontname .. '.woff', true)
end
copydir('fonts-zh')
copydir('vendor/katex-0.16.4')

for i = 1, #cats do
  local pagelist = cats[i].pagelist or {}
  for j = 1, #pagelist do
    registeritemmarkup(pagelist[j].name, cats[i].name)
  end
end
registeritemmarkup('index', 'home')
registeritemmarkup('about', 'home')
registeritemtempl('friends', 'home',
  'items/friends/page.html',
  render('items/friends/page.txt'))
registeritemtempl('email', 'home',
  'items/email/page.html',
  render('items/email/page.txt'))
registeritemtempl('planetarium', 'home',
  'items/planetarium/page.html',
  render('items/planetarium/page.txt'))
registeritemmarkup('dates', 'home')
registeritemmarkup('colophon', 'home')

local backyarditems = require('content/items/backyard/list')
for i = 1, #backyarditems do
  if backyarditems[i].templ then
    registeritemtempl('backyard/' .. backyarditems[i].name, 'backyard', backyarditems[i].templ,
      render('items/backyard/' .. backyarditems[i].name .. '/page.txt'),
      backyarditems[i].pagination)
  else
    registeritemmarkup('backyard/' .. backyarditems[i].name, 'backyard')
  end
end
registeritemmarkup('backyard', 'backyard')

registeritemtempl('music', 'music', 'bannerlist.html')
registeritemtempl('playful', 'playful', 'bannerlist.html')
registeritemtempl('murmurs', 'murmurs', 'bannerlist.html')
registeritemtempl('potpourri', 'potpourri', 'bannerlist.html', { compact = true })
registeritemmarkup('pebbles', 'pebbles', {
  title = trmerge(cats.pebbles.longtitle, cats.pebbles.title)
})
registeritemtempl('flow', 'flow', 'bannerlist.html')

local revloglatest = 2023*12 + 10
local revlogfirst = 2022*12 + 10
registeritemmarkup('revlog', 'home', nil, { revloglatest = revloglatest, revlogfirst = revlogfirst })
for _, lang in ipairs({'zh', 'en'}) do
  registeritemempty('rss.' .. lang .. '.xml', 'home')
  registeritemempty('atom.' .. lang .. '.xml', 'home')
  caisse.lang = lang
  renderraw('rss.' .. lang .. '.xml', 'items/revlog/rss.xml',
    { lang = lang, revloglatest = revloglatest, revlogfirst = revlogfirst })
  renderraw('atom.' .. lang .. '.xml', 'items/revlog/atom.xml',
    { lang = lang, revloglatest = revloglatest, revlogfirst = revlogfirst })
end

ensuredir('_/')
local itemregglobal = itemreg
for _, lang in ipairs({'zh', 'en'}) do
  caisse.lang = lang
  caisse.envadditions.lang = caisse.lang
  local catalogue = renderallitems()
  local itemregglobal = itemreg
  itemreg = {}
  registeritemtempl('_/404', 'home', '404.html', {
    catalogue = catalogue,
  })
  renderallitems()
  itemreg = itemregglobal
end

os.execute(table.concat(bufferedcmds, '; '))
io.open('misc/katex/list.txt', 'w'):write(table.concat(katexstringlist, '\n')):close()
