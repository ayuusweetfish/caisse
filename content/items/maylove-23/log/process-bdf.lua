-- lua % < Tamzen7x14r.bdf
-- lua % < spleen-5x8.bdf
local s = io.read('a')

local allbitmap = {}

local w, h = s:match('FONTBOUNDINGBOX%s+([0-9]+)%s+([0-9]+)')
local npages = math.ceil(h / 8)

for encoding, bitmap in s:gmatch('STARTCHAR%s[^\n]-\nENCODING([^\n]+).-BITMAP.-([0-9A-Fa-f\n]+)ENDCHAR\n') do
  encoding = tonumber(encoding)
  if encoding >= 32 and encoding <= 126 then
    local a = {}
    for i in bitmap:gmatch('[0-9A-Fa-f]+') do
      a[#a + 1] = tonumber(i, 16)
    end
    while #a < npages * 8 do
      if #a % 2 == 0 then a[#a + 1] = 0
      else table.insert(a, 1, 0) end
    end
    allbitmap[encoding] = a
  end
end

for ch = 32, 126 do
  -- Column major format
  local s = {}
  for page = 0, npages - 1 do
    for col = 1, w do
      local byte = 0
      for row = 1, 8 do
        byte = byte | (((allbitmap[ch][row + page * 8] >> (8 - col)) & 1) << (row - 1))
      end
      s[#s + 1] = string.format('0x%02x', byte)
    end
  end
  print('  {' .. table.concat(s, ', ') .. '},')
end
