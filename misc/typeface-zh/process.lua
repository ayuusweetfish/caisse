--[[
Files to be prepared:
  AaKaiSong2WanZi2.charset.txt
  common.txt
  /tmp/caisse-typeface-zh-stray.txt
Then run without arguments or input:
  lua process.lua
To use the cache:
  mv ../../content/fonts-zh/AaKaiSong.*.woff2 .

Dependencies: pyftsubset (fonttools), woff2_compress (woff2)
]]

local codepoints = {}
local ncodepoints = 0
for line in io.open('AaKaiSong2WanZi2.charset.txt'):lines() do
  codepoints[tonumber(line, 16)] = true
  ncodepoints = ncodepoints + 1
end
print('#codepoints', ncodepoints)

local css = {}

local subsetsocc = {} -- Deduplication
local subsetinvocations = {}  -- {{codepoints, WOFF2 file name}, ...}
function addsubset(subset, name, writecss, comment)
  local terms = {}
  local j = 1
  while j <= #subset do
    local k = 1
    while subset[j + k] == subset[j] + k do k = k + 1 end
    if k == 1 then
      terms[#terms + 1] = string.format('U+%x', subset[j])
    else
      terms[#terms + 1] = string.format('U+%x-%x', subset[j], subset[j] + k - 1)
    end
    j = j + k
  end
  -- Hash
  local h = 0
  for i = 1, #subset do h = h * 100019 + subset[i] + 1 end
  h = string.format('%08x', (h >> 32) ~ (h & ((1 << 32) - 1)))
  --print(table.concat(terms, ','))
  -- Deduplication
  local woff2basename = string.format('AaKaiSong.%s.%s.woff2', name, h)
  local woff2pathcontent = '../../content/fonts-zh/' .. woff2basename
  -- Short-circuit if already processed
  if subsetsocc[woff2basename] then return end
  subsetsocc[woff2basename] = true
  -- Check if file exists
  local f = io.open(woff2pathcontent, 'r')
  local exists = (f ~= nil)
  print(string.format(
    'Subset %s, hash %s, size %d, comment %s%s',
    name, h, #subset, comment or '(none)', exists and ' (exists)' or ''))
  if exists then
    f:close()
  else
    subsetinvocations[#subsetinvocations + 1] = {table.concat(terms, ','), woff2pathcontent}
  end
  if writecss then
    css[#css + 1] = string.format([[
@font-face {
  font-family: 'AaKaiSong';
  font-style: normal;
  font-weight: 400;
  font-display: block;
  src: url(/bin/fonts-zh/AaKaiSong.%s.woff2) format('woff2');
  unicode-range: %s;
}
]],
    name .. '.' .. h, table.concat(terms, ','))
  end
end

local function basehash(s)
  local h = 0
  for i = 1, #s do
    h = h * 997 + string.byte(s, i) + 1
  end
  return string.format('%08x', (h >> 32) ~ (h & ((1 << 32) - 1)))
end

-- Page-curated subset
for line in io.open('/tmp/caisse-typeface-zh-stray.txt'):lines() do
  local tabpos = line:find('\t')
  local docid = line:sub(1, tabpos - 1)
  local cps = {}
  for w in line:gmatch('[0-9a-f]+', tabpos + 1) do
    cps[#cps + 1] = tonumber(w, 16)
  end
  addsubset(cps, 'stray', false, docid)
end

-- Precalculated subset
local fcommon = io.open('common.txt')
local seq = fcommon:read('l')
local sep = fcommon:read('l')
fcommon:close()
local cpseq = {utf8.codepoint(seq, 1, #seq)}
print('#codepoints in common set = ', #cpseq)
if #sep ~= #cpseq then
  print('#split sequence = ', #sep)
  print('Invalid, please check')
  return
end

print('Precalculated')
local subset = {}
local sepmarker = string.byte('>')
for i = 1, #cpseq do
  subset[#subset + 1] = cpseq[i]
  codepoints[cpseq[i]] = nil
  if sep:byte(i) == sepmarker then
    addsubset(subset, 'common', true)
    subset = {}
  end
end

if os.getenv('FONT_SUBSET_PARALLEL') then
  local pipe = io.popen([[
parallel --colsep '\t' '
  BASENAME="$(basename "{2}")"
  TTF_SCRATCH="$(mktemp --suffix .ttf)"
  WOFF2_SCRATCH="${TTF_SCRATCH%.ttf}.woff2"
  pyftsubset /tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.ttf --unicodes={1} --output-file="$TTF_SCRATCH" && \
    woff2_compress "$TTF_SCRATCH" && \
    mv "$WOFF2_SCRATCH" "{2}"
'
]], 'w')
  for i = 1, #subsetinvocations do
    local codepoints, woff2pathcontent = table.unpack(subsetinvocations[i])
    pipe:write(codepoints .. '\t' .. woff2pathcontent .. '\n')
  end
  pipe:close()
else
  for i = 1, #subsetinvocations do
    local codepoints, woff2pathcontent = table.unpack(subsetinvocations[i])
    local woff2basename = woff2pathcontent:match('/([^/]+)$')
    local woff2pathscratch = '/tmp/caisse-typeface-zh-' .. woff2basename
    local ttfpathscratch = woff2pathscratch:sub(1, -7) .. '.ttf'
    if not os.execute(
      string.format(
        'pyftsubset /tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.ttf --unicodes=%s --output-file=%s',
        codepoints, ttfpathscratch
      ) .. ' && ' .. string.format(
        'woff2_compress %s',
        ttfpathscratch
      ) .. ' && ' .. string.format(
        'mv "%s" "%s"',
        woff2pathscratch, woff2pathcontent
      )
    ) then os.exit(1) end
  end
end

io.open('/tmp/caisse-typeface-zh-AaKaiSong.css', 'w'):write(table.concat(css))
