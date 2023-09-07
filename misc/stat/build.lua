-- find ../../content -type f | lua build.lua database.tsv ../../content/

local filetypes = {
  -- Music and audio
  ogg = 'audio', mp3 = 'audio', wav = 'audio',
  mid = 'musicnotes', midi = 'musicnotes',
  tracktionedit = 'musicnotes',
  mscz = 'score',
  -- Images
  png = 'image', jpg = 'image', jpeg = 'image', gif = 'image', webp = 'image',
  svg = 'image',
  -- Video
  mp4 = 'video', ogv = 'video', webm = 'video',
  -- Text, code, and documents
  txt = 'document', pdf = 'document',
  c = 'code', h = 'code', lua = 'code', js = 'code',
  cc = 'code',
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
  return io.popen('stat -f "%z" "' .. path .. '" 2>/dev/null'):read('n')
end

local databasetsv = arg[1] or 'database.tsv'
local prefix = arg[2] or ''

local existingfiles = {}
local lines = {}
local inf = io.open(databasetsv, 'r')
if inf then
  for line in inf:lines() do
    local tabpos1 = line:find('\t') or (#line + 1)
    local tabpos2 = line:find('\t', tabpos1 + 1) or (#line + 1)
    local path = line:sub(1, tabpos1 - 1)
    local recsize = tonumber(line:sub(tabpos1 + 1, tabpos2 - 1))
    local realsize = filesize(prefix .. path)
    if realsize == recsize then
      existingfiles[path] = true
      lines[#lines + 1] = line
    else
      if realsize == nil then print('Removing ' .. path) end
    end
  end
  inf:close()
end
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
    local fn = infofn[filetype] or infofn['.' ..ext] or function () end
    lines[#lines + 1] = table.concat({
      path, tostring(filesize(fullpath)), filetype,
      fn(fullpath)
    }, '\t')
    print(path)
  end
end
table.sort(lines)
local outf = io.open(databasetsv, 'w')
for i = 1, #lines do outf:write(lines[i], '\n') end
outf:close()
