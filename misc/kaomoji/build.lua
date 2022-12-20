-- lua % < kaomoji.txt

local inkscape = os.getenv('INKSCAPE') or 'inkscape'
local cwd = os.getenv('PWD') or io.popen('pwd'):read()
local svgo = os.getenv('SVGO') or 'node_modules/svgo/bin/svgo'

local outdir = cwd .. '/gen'
os.execute('mkdir "' .. outdir .. '"')

local template1 =
[[
<?xml version="1.0" encoding="UTF-8" standalone="no"?>

<svg
   width="1000"
   height="1000"
   viewBox="0 0 264.58333 264.58333"
   version="1.1"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:svg="http://www.w3.org/2000/svg">
  <defs
     id="defs2" />
  <g
     id="layer1">
    <text
       xml:space="preserve"
       x="0"
       y="0"
       id="]]
local template2 = [[">]]
local template3 =
[[</text>
  </g>
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

local curline = {}
local tspans = {}

local s = io.read('l')
while true do
  if s == '' or s == nil then
    -- Output
    curline = table.concat(curline)
    tspans = table.concat(tspans)
    local hash = basehash(curline)
    -- Write an SVG with text
    local textsvgfile = outdir .. '/moji-' .. hash .. '-text.svg'
    local pathsvgfile = outdir .. '/moji-' .. hash .. '.svg'
    if not os.rename(pathsvgfile, pathsvgfile) then
      print(pathsvgfile, curline)
      local f = io.open(textsvgfile, 'w')
      local textelementid = 'moji-' .. hash
      f:write(template1)
      f:write(textelementid)
      f:write(template2)
      f:write(tspans)
      f:write(template3)
      f:close()
      os.execute(inkscape .. ' -o "' .. pathsvgfile ..
        '" --export-id=' .. textelementid .. ' --export-id-only ' ..
        '--export-plain-svg --export-text-to-path "' .. textsvgfile .. '"')
      local content = io.popen(svgo .. ' --precision 2 "' .. pathsvgfile .. '" -o - | ' ..
        'gsed \'s/ \\(style\\|aria-label\\)="[^"]*"//g\''):read('a')
      io.open(pathsvgfile, 'w'):write(content):close()
      -- os.remove(textsvgfile)
    end
    -- Clear state
    curline = {}
    tspans = {}
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
    local paramsline = io.read('l')
    params['font-family'] = '\'' .. paramsline .. '\''  -- TODO: More parameters
    local paramsbuild = {}
    for k, v in pairs(params) do
      paramsbuild[#paramsbuild + 1] = k .. ':' .. v
    end
    tspans[#tspans + 1] = '<tspan style="' .. table.concat(paramsbuild, ';') ..
      '">' .. htmlescape(s) .. '</tspan>'
  end
  s = io.read('l')
end
