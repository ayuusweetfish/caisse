local caisse = require('caisse/caisse')
caisse.rendermarkup = require('caisse/markup')
local inspect = require('caisse/deps/inspect')
caisse.envadditions.b = function (a, b)
  return '{b ' .. a .. ', ' .. b .. '}'
end
caisse.envadditions.image = function (link, alt, class)
  return '{image ' .. link .. ', ' .. alt .. ', ' .. class .. '}'
end
print(caisse.rendermarkup(caisse.render('content/bellflowers/page.txt').contents.zh, {
  ['-'] = function (s)
    if s == '' then return ''
    elseif s:sub(1, 1) == '!' then return s:sub(2) .. '\n'
    else return '{p ' .. s .. '}\n' end
  end,
  b = function (s) return '{b ' .. s .. '}' end,
  link = function (href, text)
    return '{link ' .. href .. '|' .. text .. '}'
  end,
  img = function (src, alt, class)
    return '{img ' .. src .. '|' .. alt .. '|' .. class .. '}'
  end,
  hr = function () return '{hr}' end,
  vararg = function (a, b, ...)
    return '{vararg a=' .. (a or 'nil') ..
      ', b=' .. (b or 'nil') .. ', #rest=' .. select('#', ...) .. '}'
  end,
}))
