local caisse = require('caisse/caisse')
local inspect = require('caisse/deps/inspect')
caisse.envadditions.b = function (a, b)
  a = 2 + nil
  return '{' .. table.concat(a) .. ',' .. table.concat(b) .. '}'
end
print(inspect(caisse.render('content/bellflowers/page.txt')))
