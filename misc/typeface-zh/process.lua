--[[
Files to be prepared:
  AaKaiSong2WanZi2.charset.txt
  common.txt
  stray.txt
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

local css = io.open('AaKaiSong.css', 'w')

local subsetsocc = {} -- Deduplication
function addsubset(subset, name, skipcss, comment)
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
  local woff2path = string.format('AaKaiSong.%s.%s.woff2', name, h)
  -- Short-circuit if already processed
  if subsetsocc[woff2path] then return end
  subsetsocc[woff2path] = true
  -- Check if file exists
  local f = io.open(woff2path, 'r')
  local exists = (f ~= nil)
  print(string.format(
    'Subset %s, hash %s, size %d, comment %s%s',
    name, h, #subset, comment or '(none)', exists and ' (exists)' or ''))
  if exists then
    f:close()
  else
    local ttfpath = string.format('AaKaiSong.%s.%s.ttf', name, h)
    os.execute(string.format(
      'pyftsubset AaKaiSong2WanZi2.ttf --unicodes=%s --output-file=%s',
      table.concat(terms, ','), ttfpath))
    os.execute(string.format(
      'woff2_compress %s', ttfpath))
    os.remove(ttfpath)
  end
  os.rename(woff2path, '../../content/fonts-zh/' .. woff2path)
  if not skipcss then
    css:write(string.format([[
@font-face {
  font-family: 'AaKaiSong';
  font-style: normal;
  font-weight: 400;
  font-display: block;
  src: url(/bin/fonts-zh/AaKaiSong.%s.woff2) format('woff2');
  unicode-range: %s;
}
]],
    name .. '.' .. h, table.concat(terms, ',')))
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
for line in io.open('stray.txt'):lines() do
  local tabpos = line:find('\t')
  local docid = line:sub(1, tabpos - 1)
  local cps = {}
  for w in line:gmatch('[0-9a-f]+', tabpos + 1) do
    cps[#cps + 1] = tonumber(w, 16)
  end
  addsubset(cps, 'stray', true, docid)
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
    addsubset(subset, 'common')
    subset = {}
  end
end
