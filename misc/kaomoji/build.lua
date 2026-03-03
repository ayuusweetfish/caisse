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
local svgo = os.getenv('SVGO') or 'node_modules/svgo/bin/svgo.js'

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

local function basehash(s)
  local h = 0
  for i = 1, #s do
    h = h * 997 + string.byte(s, i) + 1
  end
  return string.format('%08x', (h >> 32) ~ (h & ((1 << 32) - 1)))
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
    local pathsvgfile = outdir .. '/moji-' .. hash .. '.svg'
    if not os.rename(pathsvgfile, pathsvgfile) then
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
      print(rsvgconvert .. ' -f svg "' .. textsvgfile .. '"')
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
    }
    local paramsline = inputlist:read('l')
    local fontfamily = paramsline   -- TODO: More parameters
    params['font-family'] = '\'' .. fontfamily .. '\''
    local paramsbuild = {}
    for k, v in pairs(params) do
      paramsbuild[#paramsbuild + 1] = k .. ':' .. v
    end
    tspans[#tspans + 1] = '<tspan style="' .. table.concat(paramsbuild, ';') ..
      '">' .. htmlescape(s) .. '</tspan>'
    debugcmds[#debugcmds + 1] =
      string.format("bash fc_match.sh '%s' '%s'",
        s:gsub("'", [['\'']]), fontfamily)
  end
  s = inputlist:read('l')
end

os.remove(fontconfig)
