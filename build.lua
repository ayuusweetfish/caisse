local caisse = require('caisse/caisse')
local render = caisse.render

local pagemain = render('content/list.html')
local pageall = render('index.html', {contents = pagemain})
print(pageall)
