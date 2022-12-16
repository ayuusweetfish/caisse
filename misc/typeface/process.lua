-- cat solve.txt | lua %

local codepoints = {}
local ncodepoints = 0
for line in io.open('AaKaiSong2WanZi2.charset.txt'):lines() do
  codepoints[tonumber(line, 16)] = true
  ncodepoints = ncodepoints + 1
end
print('#codepoints', ncodepoints)

local freqs = {}
for line in io.open('freqs.tsv'):lines() do
  local p1 = line:find('\t')
  local p2 = line:find('\t', p1 + 1)
  freqs[#freqs + 1] = utf8.codepoint(line:sub(p1 + 1, p2 - 1))
end
print('#freqs', #freqs)

local css = io.open('AaKaiSong.css', 'w')

local nsubset = 0
function addsubset(subset, name)
  if name == nil then
    nsubset = nsubset + 1
    name = string.format('%03d', nsubset)
  end
  table.sort(subset)
  -- for j = 1, n do print(string.format('%x', subset[j])) end
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

-- Precalculated subset
local seq = io.read('l')
local sep = io.read('l')
local cpseq = {utf8.codepoint(seq, 1, #seq)}
print('#recorded codepoints = ', #cpseq)
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

print('Frequency ordered')
-- Subset sizes
local breakpoints = {
}
local n = 0
while n < 4000 do
  if n < 1000 then n = n + 1000
  elseif n < 2000 then n = n + 500
  else n = n + 50 end
  breakpoints[#breakpoints + 1] = n
end
for i = 1, #breakpoints do
  local subset = {}
  for j = (breakpoints[i - 1] or 0) + 1, breakpoints[i] do
    if codepoints[freqs[j]] then
      subset[#subset + 1] = freqs[j]
      codepoints[freqs[j]] = nil
    end
  end
  addsubset(subset)
end

-- Remove unneeded glyphs
for i = 1, 256 do codepoints[i] = nil end

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

local remains = {}
for k, _ in pairs(codepoints) do remains[#remains + 1] = k end
table.sort(remains)
local remainssubsetsize = 100
for i = 1, #remains, remainssubsetsize do
  local subset = {}
  for j = i, math.min(#remains, i + remainssubsetsize - 1) do
    subset[#subset + 1] = remains[j]
  end
  addsubset(subset)
end

css:close()
