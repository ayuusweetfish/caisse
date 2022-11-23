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
  writefile(sitepath .. savepath, render(templatepath, locals))
end

local pagelist = {}
for i, name in ipairs(render('list-playful.txt').pages) do
  local page = render(name .. '/page.txt')
  copyfile(
    name .. '/' .. page.bannerimg,
    'bin/' .. name .. '/' .. page.bannerimg)
  pagelist[i] = { name = name, page = page }

  local creationcontents = render('creation.html', shallowdup(page))
  renderfile(name, 'index.html', {contents = creationcontents})
end

local listcontents = render('list.html', {pagelist = pagelist})
renderfile('playful', 'index.html', {contents = listcontents})
