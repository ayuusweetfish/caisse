local caisse = require('caisse/caisse')
local rendermarkup = require('caisse/markup')
caisse.lang = 'zh'

local srcpath = 'content/'
local sitepath = 'build/'

local function exists(path)
  return io.open(srcpath .. path, 'r') ~= nil
end
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

local categories = render('categories.txt')
caisse.envadditions.ensurepage = function (path)
  -- `path` is the path in URL, without the leading `/`
  -- TODO: Deduplicate
  local locals = render('items/' .. path .. '/page.txt')
  locals.name = path
  locals.curcat = 'music'
  renderpage(path, 'creation.html', locals)
end

local htmlescapelookup = {
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['&'] = '&amp;',
}
local function htmlescape(s)
  return s:gsub('[%<%>%&]', htmlescapelookup)
end
local markupfns = {
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
  link = function (href, text)
    return '<a href="' .. href .. '">' .. text .. '</a>'
  end,
  img = function (src, alt, class)
    return '<image src="' .. src .. '"'
      .. (alt and (' alt="' .. alt .. '"') or '')
      .. (class or (' class="' .. class .. '"') or '')
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

renderpage('music', 'cat-music.html')
renderpage('playful', 'cat-playful.html')
