local A_beat = 60000 / (198 * 2)
local A_bar = A_beat * 12

local B_beat = 60000 / 76
local B_bar = B_beat * 3
local B = 99905 - B_bar * 51

local A2 = 271099 - A_bar * 121

local Lead = 3000
local sequence = {
  {0, 20, -1},
  {Lead / 3, -1, 0},
  Lead,
  Lead + A_bar * 7,
  Lead + A_bar * 14,
  Lead + A_bar * 21,
  Lead + A_bar * 26,
  Lead + A_bar * 32,
  Lead + A_bar * 39,
  Lead + A_bar * 45,
  Lead + B + B_bar * 51,
  Lead + B + B_bar * 65,
  Lead + B + B_bar * 78,
  Lead + 196885,
  Lead + 227311,
  Lead + 243575,
  Lead + 258945,
  Lead + A2 + A_bar * 121,
  Lead + A2 + A_bar * 128,
  Lead + A2 + A_bar * 135,
  {Lead + A2 + A_bar * 137, 18, 17},
  Lead + A2 + A_bar * 143,
  Lead + A2 + A_bar * (6 + 141),
  Lead + A2 + A_bar * (6 + 147),
  {Lead + A2 + A_bar * (6 + 153.2), 20, -1},
}

for i = 1, #sequence do
  if type(sequence[i]) == 'number' then
    sequence[i] = {sequence[i],
      sequence[i - 1][3], sequence[i - 1][3] + 1}
  end
end

local fps = 60
local frameTime = 1000 / fps
for i = 1, #sequence do sequence[i][1] = math.floor(sequence[i][1] / frameTime + 0.5) end
for i = 1, #sequence do print(table.unpack(sequence[i])) end

local img = function (from, to, frame)
  return string.format('~/Library/Application\\ Support/LOVE/Vividness/Vividness-%02d.%02d.%02d.png',
    from, to, frame)
end

local shell = io.popen('sh', 'w')
shell:write('rm -rf video\n')
shell:write('mkdir video\n')

local totalTime = Lead + 343144
local totalFrames = math.ceil(totalTime / frameTime)
local seqPtr = 1
for i = 0, totalFrames - 1 do
  local time, from, to, frame
  -- Check: next transition?
  if seqPtr < #sequence and i + 30 > sequence[seqPtr + 1][1] then
    time, from, to = table.unpack(sequence[seqPtr + 1])
    frame = 30 - (time - i)
    if frame == 30 then seqPtr = seqPtr + 1 end
  else
    time, from, to = table.unpack(sequence[seqPtr])
    frame = 30
  end
  local frameImg = img(from, to, frame)
  print(i, frameImg)
  shell:write(string.format('ln -s %s video/%05d.png\n', frameImg, i))
end

shell:close()
