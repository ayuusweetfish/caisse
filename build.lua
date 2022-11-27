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
local function renderfile(savepath, templatepath, locals)
  local contents = render(templatepath, locals)
  writefile(sitepath .. savepath,
    render('index.html', {
      savepath = savepath,
      title = locals.title,
      cat = locals.cat,
      contents = contents,
    }))
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

local function renderlist(cat)
  local pagelist = {}
  listtemplate = render('list-' .. cat .. '.txt')
  local pagedarktitle = {}
  if listtemplate.pagedarktitle then
    for _, name in ipairs(listtemplate.pagedarktitle) do
      pagedarktitle[name] = true
    end
  end
  for i, name in ipairs(listtemplate.pages) do
    local page = render(name .. '/page.txt')
    local bannerimg
    if page.bannerimg:find('/') ~= nil then
      bannerimg = '/bin/' .. page.bannerimg
    else
      bannerimg = '/bin/' .. name .. '/' .. page.bannerimg
      copyfile(name .. '/' .. page.bannerimg)
    end
    pagelist[i] = {
      name = name,
      page = page,
      pagedarktitle = pagedarktitle[name] or false,
      bannerimg = bannerimg,
    }

    local innerlocals = shallowdup(page)
    innerlocals.cat = cat
    innerlocals.name = name
    innerlocals.bannerimg = bannerimg
    renderfile(name, 'creation.html', innerlocals)
  end

  renderfile(cat, 'list.html', {
    cat = cat,
    pagelist = pagelist,
  })
end
renderlist('music')
renderlist('playful')
