-- lua build.lua

local fontconfig = os.tmpname()
local f = io.open(fontconfig, 'w')
f:write([[
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir prefix="cwd">fonts</dir>
  <cachedir>/tmp/fc-cache</cachedir>
</fontconfig>
]])
f:close()

local rsvgconvert = os.getenv('RSVG_CONVERT') or 'FONTCONFIG_FILE=' .. fontconfig .. ' rsvg-convert'
local cwd = os.getenv('PWD') or io.popen('pwd'):read()
local svgo = os.getenv('SVGO') or 'deno run --ignore-env --allow-read=./node_modules/ --allow-write=./gen/ node_modules/svgo/bin/svgo.js'

local outdir = cwd .. '/gen'
os.execute('mkdir -p "' .. outdir .. '"')

local template1 =
[[
<?xml version="1.0" encoding="UTF-8" standalone="no"?>

<svg
   width="1000"
   height="1000"
   viewBox="0 0 1000 1000"
   version="1.1"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:svg="http://www.w3.org/2000/svg">
  <text
     xml:space="preserve"
     x="0"
     y="14"
  >]]
local template2 =
[[</text>
</svg>
]]

local fold32
local zero64
if jit then
  local bit = require('bit')
  fold32 = function (h) return bit.bxor(bit.rshift(h, 32), bit.band(h, 0xffffffff)) end
  zero64 = require('ffi').cast('uint64_t', 0)
else
  fold32 = load('return function (h) return (h >> 32) ~ (h & ((1 << 32) - 1)) end')()
  zero64 = 0
end

local function basehash(s)
  local h = zero64
  for i = 1, #s do
    h = h * 997 + string.byte(s, i) + 1
  end
  return string.format('%08x', fold32(h))
end

local overwrites = {}
for i = 1, #arg do
  overwrites[arg[i]] = true
  overwrites[basehash(arg[i])] = true
end

local htmlescapelookup = {
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['&'] = '&amp;',
}
local function htmlescape(s)
  return s:gsub('[%<%>%&]', htmlescapelookup)
end

local boundingbox = require('boundingbox')

local curline = {}
local tspans = {}
local debugcmds = {}
local lastdy = 0

local inputlist = io.open('kaomoji.txt', 'r')

local s = inputlist:read('l')
while true do
  if s == '' or s == nil then
    -- Output
    curline = table.concat(curline)
    tspans = table.concat(tspans)
    local hash = basehash(curline)
    print(hash, curline)
    -- Write an SVG with text
    local pathsvgfile = outdir .. '/' .. hash .. '.svg'
    if overwrites[curline] or overwrites[hash] or
        not os.rename(pathsvgfile, pathsvgfile) then
      print(pathsvgfile, curline)
      os.execute(table.concat(debugcmds, '; '))
      local textsvgfile = os.tmpname()
      local f = io.open(textsvgfile, 'w')
      local textelementid = 'moji-' .. hash
      f:write(template1)
      f:write(tspans)
      f:write(template2)
      f:close()
      -- Convert text to paths
      local p1 = io.popen(rsvgconvert .. ' -f svg "' .. textsvgfile .. '"', 'r')
      local pathssvg = p1:read('a')
      p1:close()
      -- Find bounding box
      local w, h = 0, 0
      for path in pathssvg:gmatch(' d="(.-)"') do
        local minx, miny, maxx, maxy = boundingbox(path)
        w = math.max(w, maxx + 1)
        h = math.max(h, maxy + 1)
      end
      -- Replace size
      pathssvg = pathssvg:gsub(
        'width="1000" height="1000" viewBox="0 0 1000 1000"',
        string.format('width="%g" height="%g" viewBox="0 0 %g %g"', w, h, w, h)
      )
      -- Optimize (minify)
      local p2 = io.popen(svgo .. ' --precision 2 - -o "' .. pathsvgfile .. '"', 'w')
      p2:write(pathssvg)
      p2:close()
      os.remove(textsvgfile)
    end
    -- Clear state
    curline = {}
    tspans = {}
    debugcmds = {}
    lastdy = 0
    if s == nil then break end
  else
    -- Append a text span
    curline[#curline + 1] = s
    local params = {
      ['font-style'] = 'normal',
      ['font-variant'] = 'normal',
      ['font-weight'] = 'normal',
      ['font-stretch'] = 'normal',
      ['font-size'] = '16px',
      ['dx'] = 0, ['dy'] = 0,
    }
    local paramsline = inputlist:read('l')
    -- Parse arguments
    local fontfamily = paramsline:gsub('; ([%w%-]+)=([^;]+)', function (k, v)
      params[k] = (k == 'dx' or k == 'dy') and tonumber(v) or v
      return ''
    end)
    params['font-family'] = '\'' .. fontfamily .. '\''
    local paramsbuild = {}
    for k, v in pairs(params) do
      if k ~= 'dx' and k ~= 'dy' then
        paramsbuild[#paramsbuild + 1] = k .. ':' .. v
      end
    end
    tspans[#tspans + 1] = string.format(
      '<tspan style="%s" dx="%g" dy="%g">%s</tspan>',
      table.concat(paramsbuild, ';'),
      params['dx'], params['dy'] - lastdy,
      htmlescape(s)
    )
    lastdy = params['dy']
    debugcmds[#debugcmds + 1] =
      string.format("bash fc_match.sh '%s' '%s'",
        s:gsub("'", [['\'']]), fontfamily)
  end
  s = inputlist:read('l')
end

os.remove(fontconfig)
