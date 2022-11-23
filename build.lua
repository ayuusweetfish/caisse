local caisse = require('caisse/caisse')

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
local function copyfile(src, dst)
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
      contents = contents,
    }))
end

local function inspectimage(path)
  local p = io.popen('identify -format "%w %h" "' .. path .. '"')
  local w = p:read('n')
  local h = p:read('n')
  return w, h
end
caisse.envadditions.image = function (path, class)
  local w, h = inspectimage(sitepath .. path)
  return '<img src="' .. path .. '"' ..
    ' width=' .. w .. ' height=' .. h ..
    (class and (' class="' .. class .. '"') or '') ..
    '>'
end

local pagelist = {}
for i, name in ipairs(render('list-playful.txt').pages) do
  local page = render(name .. '/page.txt')
  copyfile(
    name .. '/' .. page.bannerimg,
    'bin/' .. name .. '/' .. page.bannerimg)
  pagelist[i] = { name = name, page = page }

  local innerlocals = shallowdup(page)
  innerlocals.name = name
  renderfile(name, 'creation.html', innerlocals)
end

renderfile('playful', 'list.html', {pagelist = pagelist})
