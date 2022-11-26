local caisse = require('caisse/caisse')
caisse.markup = require('caisse/markup')
local inspect = require('caisse/deps/inspect')
caisse.envadditions.b = function (a, b)
  return '{b ' .. a .. ', ' .. b .. '}'
end
caisse.envadditions.image = function (link, alt, class)
  return '{image ' .. link .. ', ' .. alt .. ', ' .. class .. '}'
end
print(caisse.markup.render(caisse.render('content/bellflowers/page.txt').contents.zh, {
  b = function (s) return '{b ' .. s .. '}' end,
  link = function (s)
    local href, text = caisse.markup.args(s, 1)
    return '{link ' .. href .. '|' .. text .. '}'
  end,
  img = function (s)
    local src, alt, class = caisse.markup.args(s, 2)
    return '{img ' .. src .. '|' .. alt .. '|' .. class .. '}'
  end,
}))
