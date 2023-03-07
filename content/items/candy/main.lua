-- convert -density 150 CandyGirl.pdf -channel rgba -alpha on CandyGirl.png
-- for i in CandyGirl-*.png; do convert $i -background black -alpha Remove $i -compose Copy_Opacity -composite $i; done
-- ~/Downloads/ffmpeg-5.0.1 -i ~/Downloads/BV1Y541177Rg.m4s -qscale:v 9 BV1Y541177Rg.ogv
-- ~/Downloads/ffmpeg-5.0.1 -i ~/Downloads/BV1Y541177Rg.audio.m4s BV1Y541177Rg.ogg

-- record=1 ~/Downloads/love-11.4.app/Contents/MacOS/love .
-- mv ~/Library/Application\ Support/LOVE/CandyGirl overlay
-- convert -define png:color-type=2 -size 1920x1200 xc:none overlay/CandyGirl-004655.png; for i in {4656..4829}; do ln -sf CandyGirl-004655.png overlay/CandyGirl-00$i.png; done

--[[
~/Downloads/ffmpeg-5.0.1 \
  -i ~/Downloads/BV1Y541177Rg.m4s \
  -r 24000/1001 -i "overlay/CandyGirl-%06d.png" \
  -filter_complex "[0]crop=1152:720:64:0,scale=960:600,tpad=stop=-1:stop_mode=clone[0a];[1]scale=960:600,tpad=stop=-1:stop_mode=clone[1a];[0a][1a]overlay[out]" \
  -i CandyGirl.wav \
  -filter_complex "aevalsrc=0:d=0.8[pad];[pad][2]concat=n=2:v=0:a=1[2a]" \
  -map [out] -map [2a] -shortest -crf 29 CandyGirl.mp4
]]

local scale = 2
local W = 960 * scale
local H = 600 * scale
love.window.setMode(
  W, H,
  { fullscreen = false, highdpi = false }
)

local record = (os.getenv('record') ~= nil)

local bgImg = love.graphics.newVideo('BV1Y541177Rg.ogv')
local bgW, bgH = bgImg:getDimensions()
local bgScale = math.max(W / bgW, H / bgH)

--local bgMus = love.audio.newSource('BV1Y541177Rg.ogg', 'static')
local bgMus = love.audio.newSource('CandyGirl.wav', 'static')
local bgDur = bgMus:getDuration()

local offs = 0.8
local beat = 60 / 126
local bar = beat * 4
local seq = {
  {-1, 0},
  {0, offs},
  {1, beat*30},
  {2, bar*6},
  {3, bar*6},
  {4, bar*4},
  {5, bar*8},
  {6, bar*5},
  {7, bar*4},
  {8, bar*5},
  {9, bar*5},
  {10, bar*6},
  {4, bar*5},
  {5, bar*8},
  {6, bar*5},
  {7, bar*4},
  {11, bar*4},
  {12, bar*4},
  {13, bar*4},
  {14, bar*4},
  {15, bar*4},
  {-1, bar*3},
}
for i = 1, #seq do
  seq[i][2] = (i == 1 and 0 or seq[i - 1][2]) + seq[i][2]
end

local imgs = {}
for i = 0, 15 do
  imgs[i] = love.graphics.newImage(
    string.format('CandyGirl-%d.png', i),
    { mipmaps = true })
end
local imgW, imgH = imgs[1]:getDimensions()
local imgScale = math.min(W / imgW, H / imgH)

local function drawTransition(fromIdx, toIdx, progress,
  offsetY1, offsetY2,
  rota1, rota2
)
  local reversed = (toIdx ~= -1 and fromIdx > toIdx)
  local movt = 1 - math.exp(-3 * progress) * (1 - progress)
  local alphaA = (1 - movt) ^ 2
  local alphaB = movt ^ 2
  local MOVT = H / 60 * (reversed and -1 or 1)
  local coverAlpha = 1
  if fromIdx == -1 then coverAlpha = math.sqrt(math.sqrt(progress))
  elseif toIdx == -1 then coverAlpha = 1 - math.sqrt(progress) end
  love.graphics.setColor(1, 1, 0.994, 0.8 * coverAlpha)
  love.graphics.rectangle('fill', 0, H * 0.03, W, H * 0.94)
  love.graphics.setBlendMode('alpha', 'premultiplied')
  if fromIdx ~= -1 then
    love.graphics.setColor(alphaA, alphaA, alphaA, alphaA)
    love.graphics.draw(
      imgs[fromIdx], W / 2, H / 2 - movt * MOVT + offsetY1,
      rota1, imgScale, imgScale, imgW / 2, imgH / 2)
  end
  if toIdx ~= -1 then
    love.graphics.setColor(alphaB, alphaB, alphaB, alphaB)
    love.graphics.draw(
      imgs[toIdx], W / 2, H / 2 + (1 - movt) * MOVT + offsetY2,
      rota2, imgScale, imgScale, imgW / 2, imgH / 2)
  end
  if record then
    love.graphics.setBlendMode('screen', 'premultiplied')
  else
    love.graphics.setBlendMode('alpha')
  end
end

local cumtime = 0
local function update(dt)
  cumtime = cumtime + dt
  local delay = 2
  if not bgImg:isPlaying() and cumtime >= delay then
    bgImg:play()
  end
  if not bgMus:isPlaying() and cumtime >= delay + offs then
    bgMus:seek(cumtime - (delay + offs))
    bgMus:play()
  end
end

local function draw(frameNum)
  love.graphics.clear(0, 0, 0, 0)
  if record then
    love.graphics.setBlendMode('screen', 'premultiplied')
  else
    love.graphics.setBlendMode('alpha')
  end

  local T

  if record then
    T = frameNum * 1001 / 24000 -- 23.976024 FPS
    if T > bgDur + offs then love.event.quit() end
  else
    local t = bgImg:tell() - offs
    if not bgImg:isPlaying() then
      bgMus:pause()
    elseif t >= 0 and math.abs(bgMus:tell() - t) >= 0.1 then
      print(t, bgMus:tell())
      bgMus:seek(t)
    end
    T = bgImg:tell()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgImg, W / 2, H / 2, 0, bgScale, bgScale, bgW / 2, bgH / 2)
  end

  local trdur = 0.5
  for i = 1, #seq - 1 do
    if T >= seq[i][2] and T <= seq[i + 1][2] then
      drawTransition(seq[i][1], seq[i + 1][1], math.max(0, 1 - (seq[i + 1][2] - T) / trdur),
        math.sin((i * 0.1 + T * 0.1) * 2 * math.pi) * (H * 0.003) + H * 0.015,
        math.sin(((i + 1) * 0.1 + T * 0.1) * 2 * math.pi) * (H * 0.003) + H * 0.015,
        math.sin((i * 0.7 + T * 0.165) * 2 * math.pi) * 0.003,
        math.sin(((i + 1) * 0.7 + T * 0.165) * 2 * math.pi) * 0.003
      )
      break
    end
  end
end

if record then
  love.filesystem.setIdentity('CandyGirl')
  local canvas = love.graphics.newCanvas(W, H)
  local frame = 0
  love.draw = function ()
    love.graphics.setCanvas(canvas)
    draw(frame)
    love.graphics.setCanvas(nil)
    local name = string.format('CandyGirl-%06d.png', frame)
    -- love.graphics.captureScreenshot(name)
    local imageData = canvas:newImageData()
    imageData:encode('png', name)
    print(name)
    frame = frame + 1
  end
else
  local cumtime = 0
  love.update = update
  love.draw = function ()
    draw()
  end
  love.keypressed = function (key, scancode, isrepeat)
    if key == 'right' then
      bgImg:seek((bgMus:tell() + 5) % bgDur)
      bgMus:seek((bgMus:tell() + 5) % bgDur)
    elseif key == 'left' then
      bgImg:seek((bgMus:tell() - 5 + bgDur) % bgDur)
      bgMus:seek((bgMus:tell() - 5 + bgDur) % bgDur)
    end
  end
end
