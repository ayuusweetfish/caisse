local n = 0
local seq = {}
local order = {}
for line in io.open('freqs.tsv'):lines() do
  local p1 = line:find('\t')
  local p2 = line:find('\t', p1 + 1)
  seq[#seq + 1] = line:sub(p1 + 1, p2 - 1)
  order[utf8.codepoint(seq[#seq])] = #seq
end

local l = io.read('a')
local cps = {utf8.codepoint(l, 1, #l)}
local all = {}
for i = 1, #cps do
  if order[cps[i]] then
    all[#all + 1] = {utf8.char(cps[i]), order[cps[i]]}
  end
end
table.sort(all, function (a, b) return a[2] < b[2] end)
local occ = {}
for i = 1, #all do if i == 1 or all[i][1] ~= all[i - 1][1] then
  print(all[i][1], all[i][2])
  occ[all[i][2]] = true
end end

local occstr = {}
for i = 1, 3000 do
  occstr[i] = (occ[i] and seq[i] or '. ') ..
    (i % 50 == 0 and string.format(' %4d\n', i) or '')
end
print(table.concat(occstr))
