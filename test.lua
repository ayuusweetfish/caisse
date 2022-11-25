local caisse = require('caisse/caisse')
local inspect = require('caisse/deps/inspect')
caisse.envadditions.b = function (a, b)
  return '{' .. table.concat(a) .. ',' .. table.concat(b) .. '}'
end
print(inspect(caisse.render('content/bellflowers/page.txt')))
