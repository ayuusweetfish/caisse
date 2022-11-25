local caisse = require('caisse/caisse')
local inspect = require('caisse/deps/inspect')
print(inspect(caisse.render('content/categories.txt')))
print(inspect(caisse.render('content/bellflowers/page.txt')))
