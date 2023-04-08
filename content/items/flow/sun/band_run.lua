-- wav: +10.240s
local timeline = {
  {  166, {M1=1, M2=1, X=1, V=1}},
  {  685, {M1=1, M2=1}},
  { 9053, {M1=1, M2=1, X=1}},
  {15025, {M2=1, X=1, V=1}},
  {17957, {X=1, V=1}},
  {18205, {X=1, V=1, M1=1, M2=1}},
  {18537, {X=1, V=1}},
  {18726, {X=1, V=1, M1=1, M2=1}},
  {18964, {X=1, V=1}},
  {19204, {X=1, V=1, M1=1, M2=1}},
  {19431, {X=1, V=1}},
  {19662, {X=1, V=1, M1=1, M2=1}},
  {19876, {X=1, V=1}},
  {20144, {X=1, V=1, M1=1, M2=1}},
  {20382, {X=1, V=1}},
  {20629, {X=1, V=1, M1=1, M2=1}},
  {20895, {X=1, V=1}},
  {21106, {X=1, V=1, M1=1, M2=1}},  -- 3
  {21816, {X=1, V=1}},
  {22050, {X=1, V=1, M1=1, M2=1}},  -- 3
  {22764, {X=1, V=1}},
  {22993, {X=1, V=1, M1=1, M2=1}},  -- 3
  {41384, {X=1, V=1}},
  {42269, {X=1, V=1, M1=1, M2=1}},
  {44370, {X=1, V=1}},
  {44910, {X=1, V=1, M1=1, M2=1}},
  {46425, {X=1, V=1, M1=1}},
  {47088, {X=1, V=1, M1=1, M2=1}},
  {48164, {M1=1, M2=1}},
  {49658, {M1=1, M2=1, X=1, V=1}},
  {55477, {M1=1, M2=1}},
  {55966, {M1=1, M2=1, X=1, V=1}},
}

local instlist = {'X', 'V', 'M1', 'M2'}
local instplayerimg = {
  X = {'xyl-p1.png', 'xyl-p2.png'},
  V = {'vib-p1.png', 'vib-p2.png'},
  M1 = {'mrm1-p1.png', 'mrm1-p2.png'},
  M2 = {'mrm2-p1.png', 'mrm2-p2.png'},
}
local insttextimg = {
  X = 'text-xyl.png',
  V = 'text-vib.png',
  M1 = 'text-mrm1.png',
  M2 = 'text-mrm2.png',
}
local framedur = 6
local flipatendthr = 4
local leaddur = 2000

local function execute(cmd)
  local _, s = os.execute(cmd)
  if s == 'signal' then os.exit() end
end

execute('rm -rf frames')
execute('mkdir frames')

local imgcache = {}
local imgcacheid = 0
local function imgcomposite(list)
  local cachekey = table.concat(list, '/')
  if imgcache[cachekey] then return imgcache[cachekey] end

  imgcacheid = imgcacheid + 1
  local outputname = string.format('frames/uniq-%02d.png', imgcacheid)
  imgcache[cachekey] = outputname

  local cmd = {'convert', '-background', '"#fffefe"'}
  for i = 1, #list do
    cmd[#cmd + 1] = list[i]
  end
  cmd[#cmd + 1] = '-flatten'
  cmd[#cmd + 1] = outputname
  local cmdstr = table.concat(cmd, ' ')
  print(cmdstr)
  execute(cmdstr)
  return outputname
end

local timelineptr = 1
local insttimer = {}
local instframe = {}
for _, inst in ipairs(instlist) do
  insttimer[inst] = -1
  instframe[inst] = 1
end

for i = 0, (leaddur/1000 + 68.175)*30 do
  local ms = math.floor(i * 1000 / 30) - leaddur
  if timelineptr <= #timeline and ms > timeline[timelineptr][1] then
    local present = timeline[timelineptr][2]
    timelineptr = timelineptr + 1

    for _, inst in ipairs(instlist) do
      -- Start?
      if present[inst] and insttimer[inst] == -1 then
        instframe[inst] = instframe[inst] % #instplayerimg[inst] + 1
        insttimer[inst] = 0
      -- Stop?
      elseif not present[inst] and insttimer[inst] ~= -1 then
        if instframe[inst] >= flipatendthr then
          instframe[inst] = instframe[inst] % #instplayerimg[inst] + 1
        end
        insttimer[inst] = -1
      end
    end
  end

  local list = {'inst.png'}
  for _, inst in ipairs(instlist) do
    list[#list + 1] = instplayerimg[inst][instframe[inst]]
    if insttimer[inst] ~= -1 then
      list[#list + 1] = insttextimg[inst]
    end
  end
  if ms < 0 then
    list[#list + 1] = 'text-all.png'
  end
  local img = imgcomposite(list)
  print(img)
  local cmdstr = string.format('ln %s frames/%05d.png', img, i + 1)
  print(cmdstr)
  execute(cmdstr)

  -- Tick
  for _, inst in ipairs(instlist) do
    if insttimer[inst] ~= -1 then
      insttimer[inst] = insttimer[inst] + 1
      if insttimer[inst] == framedur then
        instframe[inst] = instframe[inst] % #instplayerimg[inst] + 1
        insttimer[inst] = 0
      end
    end
  end
end

local finalcmd = [[
ffmpeg -r 30 -f image2 -i frames/%05d.png \
  -i Band.wav -filter_complex '[1]adelay=2000|2000' \
  -vf 'scale=600:320' \
  -vcodec libx264 -crf 29 -pix_fmt yuv420p \
  Band.mp4
]]
print(finalcmd)
execute(finalcmd)
