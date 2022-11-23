local caisse = require('caisse/caisse')
local render = caisse.render

local sitepath = 'build/'
os.execute('rm -rf ' .. sitepath)
os.execute('mkdir ' .. sitepath)

local function writefile(file, s) io.open(file, 'w'):write(s) end
local function renderfile(savepath, templatepath, locals)
  writefile(sitepath .. savepath, render(templatepath, locals))
end

renderfile('1.html', 'index.html', {contents = render('content/list.html')})
