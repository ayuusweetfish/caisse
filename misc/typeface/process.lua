-- Files to be prepared:
--  AaKaiSong2WanZi2.charset.txt
--  common.txt
--  stray.txt
-- Then run without arguments or input: lua process.lua

local codepoints = {}
local ncodepoints = 0
for line in io.open('AaKaiSong2WanZi2.charset.txt'):lines() do
  codepoints[tonumber(line, 16)] = true
  ncodepoints = ncodepoints + 1
end
print('#codepoints', ncodepoints)

local css = io.open('AaKaiSong.css', 'w')

local nsubset = 0
function addsubset(subset, name, skipcss)
  if name == nil then
    nsubset = nsubset + 1
    name = string.format('%03d', nsubset)
  end
  table.sort(subset)
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
  print('Subset ' .. name .. ', size ' .. #subset)
  --print(table.concat(terms, ','))
  local succeeded = os.execute(string.format(
    'pyftsubset AaKaiSong2WanZi2.ttf --unicodes=%s --output-file=AaKaiSong.%s.ttf',
    table.concat(terms, ','), name))
  if not succeeded then os.exit() end
  if not skipcss then
    css:write(string.format([[
  @font-face {
    font-family: 'AaKaiSong';
    font-style: normal;
    font-weight: 400;
    font-display: swap;
    src: url(/bin/fonts/AaKaiSong.%s.woff2) format('woff2');
    unicode-range: %s;
  }
  ]],
    name, table.concat(terms, ',')))
  end
end

local function basehash(s)
  local h = 0
  for i = 1, #s do
    h = h * 997 + string.byte(s, i)
  end
  return string.format('%08x', (h >> 32) ~ (h & ((1 << 32) - 1)))
end

-- Page-curated subset
for line in io.open('stray.txt'):lines() do
  local tabpos = line:find('\t')
  local docpath = line:sub(1, tabpos - 1)
  local cps = {}
  for w in line:gmatch('[0-9a-f]+', tabpos + 1) do
    cps[#cps + 1] = tonumber(w, 16)
  end
  docpath = docpath:gsub('^.+build/(.+)/index.html$', '%1')
  print(docpath)
  addsubset(cps, 'stray-' .. basehash(docpath), true)
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
    addsubset(subset)
    subset = {}
  end
end

-- Punctuations
local punctsubset = {}
for _, range in ipairs({
  {0x2013, 0x2015},
  {0x2018, 0x201f},
  {0x3001, 0x301f},
}) do
  local a, b = table.unpack(range)
  local subset = {}
  for i = a, b do if codepoints[i] then
    codepoints[i] = nil
    punctsubset[#punctsubset + 1] = i
  end end
end
addsubset(punctsubset, 'punct')
