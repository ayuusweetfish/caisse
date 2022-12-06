-- find ../../content -type f | lua build.lua ../../content/

local filetypes = {
  -- Music and audio
  ogg = 'audio', mp3 = 'audio', wav = 'audio',
  mid = 'musicnotes', midi = 'musicnotes',
  mscz = 'score',
  -- Images
  png = 'image', jpg = 'image', jpeg = 'image', gif = 'image', webp = 'image',
  svg = 'image',
  -- Video
  mp4 = 'video', ogv = 'video', webm = 'video',
  -- Text, code, and documents
  txt = 'document', pdf = 'document',
  c = 'code', h = 'code', lua = 'code', js = 'code',
}

local infofn = {}

infofn.image = function (path)
  local p = io.popen('identify -format "%w %h" "' .. path .. '"')
  local w = p:read('n')
  local h = p:read('n')
  return w, h
end

local function ffprobe(path, stream, entries)
  local cmd = 'ffprobe' ..
    ' -v error -hide_banner -print_format flat -of default=noprint_wrappers=1' ..
    ' -select_streams ' .. stream .. ' -show_entries ' .. entries ..
    ' "' .. path .. '"'
  local results = {}
  for line in io.popen(cmd):lines() do
    local eqpos = line:find('=')
    if eqpos then
      results[line:sub(1, eqpos - 1)] = line:sub(eqpos + 1)
    end
  end
  return results
end
infofn.audio = function (path)
  local info = ffprobe(path, 'a:0', 'stream=duration')
  return math.floor(tonumber(info.duration))
end
infofn.video = function (path)
  local info = ffprobe(path, 'v:0', 'stream=width,height,duration')
  return math.floor(tonumber(info.duration)),
         math.floor(tonumber(info.width)),
         math.floor(tonumber(info.height))
end

infofn['.pdf'] = function (path)
  local npages
  local cmd = 'pdfinfo "' .. path .. '"'
  for line in io.popen(cmd):lines() do
    if line:find('^Pages:') then
      npages = tonumber(line:match('[0-9]+'))
      break
    end
  end
  return tostring(npages)
end

local function filesize(path)
  return io.popen('stat -f "%z" "' .. path .. '"'):read('n')
end

local prefix = arg[1] or ''

local existingfiles = {}
local inf = io.open('database.tsv', 'r')
if inf then
  for line in inf:lines() do
    local tabpos = line:find('\t')
    existingfiles[line:sub(1, tabpos - 1)] = true
  end
  inf:close()
end
local outf = io.open('database.tsv', 'a')
for path in io.lines() do
  local fullpath = path
  if path:sub(1, #prefix) == prefix then
    path = path:sub(#prefix + 1)
  end
  if not existingfiles[path] then
    existingfiles[path] = true
    local dotpos = path:find('.[^./]*$')
    local ext = (dotpos == nil and '' or path:sub(dotpos + 1))
    local filetype = filetypes[ext] or 'unknown'
    local fn = infofn[filetype] or infofn['.' ..ext]
    outf:write(path, '\t', tostring(filesize(fullpath)), '\t', filetype)
    if fn then
      for _, w in ipairs({fn(fullpath)}) do outf:write('\t', tostring(w)) end
    end
    outf:write('\n')
  end
end
outf:close()
