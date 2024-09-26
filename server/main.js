import { readAll } from 'https://deno.land/std@0.168.0/streams/read_all.ts'

const log = (msg) => console.log(`${(new Date()).toISOString()} ${msg}`)

const persistEndpoint = Deno.env.get('PERS')
const persistLog = (line) => {
  log(line)
  if (persistEndpoint)
    fetch(persistEndpoint, {
      method: 'POST',
      body: `${(new Date()).toISOString()} ${line}`,
    })
}

const siteRootDir = Deno.cwd() + '/build'

const supportedLangs = ['en', 'zh']

const mime = (s) => {
  const ext = s.substring(s.lastIndexOf('.') + 1).toLowerCase()
  switch (ext) {
    case 'html': return 'text/html; charset=UTF-8'
    case 'css': return 'text/css; charset=UTF-8'
    case 'js': return 'application/javascript; charset=UTF-8'
    case 'woff2': return 'font/woff2'
    case 'woff': return 'font/woff'
    case 'svg': return 'image/svg+xml'
    case 'png': return 'image/png'
    case 'jpeg': case 'jpg': return 'image/jpeg'
    case 'ogg': return 'audio/ogg'
    case 'mp3': return 'audio/mp3'
    case 'mp4': return 'video/mp4'
    case 'pdf': return 'application/pdf'
    case 'txt': return 'text/plain; charset=UTF-8'
    case 'mid': return 'audio/midi'
    case 'wasm': return 'application/wasm'
    case 'xml': {
      if (s.match(/^\/rss\.[A-Za-z-]+\.xml$/)) return 'application/rss+xml; charset=UTF-8'
      if (s.match(/^\/atom\.[A-Za-z-]+\.xml$/)) return 'application/atom+xml; charset=UTF-8'
      return 'application/xml; charset=UTF-8'
    }
  }
  return 'application/octet-stream'
}

const etagReg = {}
const etagGet = async (path, file) => {
  if (etagReg[path]) return etagReg[path]
  const buf = new Uint8Array(1024 * 1024)
  let n = 0
  let hash = 0
  while ((n = await file.read(buf)) !== null) {
    for (let i = 0; i < n; i++) {
      hash = hash * 997 + buf[i] + 1
      hash = (hash / 4294967296) ^ hash
    }
  }
  if (hash < 0) hash += 4294967296
  file.seek(0, Deno.SeekMode.Start)
  const etag = `"${hash.toString(16).padStart(8, '0')}"`
  etagReg[path] = etag
  return etag
}
const etagMatch = (a, b) => {
  if (!a || !b) return false
  if (a.startsWith('W/')) a = a.substring(2)
  if (b.startsWith('W/')) b = b.substring(2)
  return a === b
}

const metaReg = {}
const metaRead = async (metaPath) => {
  if (metaReg[metaPath] !== undefined) return metaReg[metaPath]
  try {
    const text = await Deno.readTextFile(siteRootDir + metaPath)
    metaReg[metaPath] = JSON.parse(text)
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) metaReg[metaPath] = null
    else if (e instanceof SyntaxError) {
      log(`Syntax error in ${metaPath}: ${e}`)
      metaReg[metaPath] = null
    }
    else throw e
  }
  return metaReg[metaPath]
}
const metaGet = async (path, attr) => {
  // assert(path.startsWith('/'))
  let index = path.length
  while (index > 0) {
    index = path.lastIndexOf('/', index - 1)
    const metaPath = path.substring(0, index + 1) + '.caisse.json'
    const metaObj = await metaRead(metaPath)
    if (metaObj && metaObj[attr]) return metaObj[attr]
  }
  return undefined
}

;(async () => {
  const watcher = Deno.watchFs(siteRootDir)
  for await (const event of watcher) {
    if (event.kind === 'create' || event.kind === 'modify' || event.kind === 'delete') {
      for (const path of event.paths) {
        const relPath = path.substring(siteRootDir.length)
        delete etagReg[relPath]
        if (relPath.endsWith('/.caisse.json'))
          delete metaReg[relPath]
      }
    }
  }
})()

const redirectResponse = (url, headers, isPerm, isNoCache) => {
  if (!headers) headers = new Headers()
  headers.set('Location', url)
  if (isNoCache) headers.set('Cache-Control', 'no-store')
  return new Response(
    `<html><body>Redirecting to <a href="${url}">${url}</a></body></html>`,
    { status: isPerm ? 301 : 303, headers }
  )
}

const randNext = ({seed, sum}) => {
  seed = (Math.imul(seed, 1664525) + 1013904223) & 0x7fffffff
  sum = (sum || 0) ^ seed
  return {seed, sum}
}
const nonRepeatRandom = (fn, seed, range) => {
  // Caveat: does not work when range is 2
  const x = fn(seed) % (range - 1)
  for (let i = 1; ; i++)
    if (fn(seed - i) % (range - 1) !== x) 
      return (i % 2 === 1) ? x : range - 1
}

const timeInMin = (timezoneOffsetMin) =>
  Math.floor(Date.now() / 60000) + timezoneOffsetMin
const timeOfDay = (timestampMinute) => {
  const minuteInDay = timestampMinute % 1440
  const day = (timestampMinute - minuteInDay) / 1440

  // Take the midpoint of the minute for period calculation
  // in order to avoid intricacies of rounding
  let period = Math.round((minuteInDay + 0.5) / 120) % 12
  let phase = ((minuteInDay - period * 120) + 60) % 120   // [0, 120)
  // Offset by 1/4 period and normalize
  if ((phase += 30) >= 120) {
    phase -= 120
    period = (period + 1) % 12
  }
  // [0, 1/2): Linearly ramped-up probability
  // [1/2, 1): Deterministic
  if (phase >= 60) {
    return period
  } else {
    // LCG
    const seed = timestampMinute & 0xffffffff   // Works for 8166 years
    let g = { seed }
    for (let i = 0; i < 5; i++) g = randNext(g)
    return (g.sum % 60 <= phase ? period : (period + 11) % 12)
  }
}

const editScore = (s, t) => {
  const ns = s.length
  const nt = t.length
  const a = new Array((ns + 1) * (nt + 1))
  const stride = nt + 1
  // Damerau–Levenshtein distance
  for (let i = 0; i <= ns; i++) a[i * stride + 0] = i
  for (let j = 1; j <= nt; j++) a[0 * stride + j] = j
  for (let i = 1; i <= ns; i++)
    for (let j = 1; j <= nt; j++)
      a[i * stride + j] = Math.min(
        a[(i - 1) * stride + j] + 1,
        a[i * stride + (j - 1)] + 1,
        a[(i - 1) * stride + (j - 1)] + (s[i - 1] === t[i - 1] ? 0 : 1),
        (i >= 2 && j >= 2 && s[i - 2] === t[i - 1] && s[i - 1] === t[i - 2])
          ? a[(i - 2) * stride + (j - 2)] + 1
          : ns + nt
      )
  const dist = a[ns * stride + nt]
  // Common subsequences
  for (let i = 0; i <= ns; i++) a[i * stride + 0] = 0
  for (let j = 1; j <= nt; j++) a[0 * stride + j] = 0
  for (let i = 1; i <= ns; i++)
    for (let j = 1; j <= nt; j++)
      a[i * stride + j] =
        a[(i - 1) * stride + j] +
        a[i * stride + (j - 1)] +
        (s[i - 1] === t[j - 1] ? 1 : -a[(i - 1) * stride + (j - 1)])
  const sub = a[ns * stride + nt]
  return dist * 5 - sub
}

const negotiateLang = (accept, supported) => {
  const list = accept.split(',').map((s) => {
    s = s.trim()
    let q = 1
    const pos = s.indexOf(';q=')
    if (pos !== -1) {
      const parsed = parseFloat(s.substring(pos + 3))
      if (isFinite(parsed)) q = parsed
      s = s.substring(0, pos).trim()
    }
    return { lang: s, q }
  })

  let bestScore = 0
  let bestLang = supported[0]
  for (const l of supported) {
    for (const { lang, q } of list) {
      if (lang.substring(0, 2) === l.substring(0, 2)) {
        const score = q + (lang === l ? 0.2 : 0)
        if (score > bestScore)
          [bestScore, bestLang] = [score, l]
      }
    }
  }
  return bestLang
}

// <Uint8Array, Uint8Array>
class Truncate extends TransformStream {
  constructor(limit) {
    super({
      transform(chunk, controller) {
        if (chunk.length >= limit) {
          chunk = chunk.slice(0, limit)
          limit = 0
        } else {
          limit -= chunk.length
        }
        controller.enqueue(chunk)
      },
    })
  }
}

const notFoundPage = async (req, opts, headers, path) => {
  return staticFile(req, opts, headers, '/_/404')
}

const staticFile = async (req, opts, headers, path) => {
  headers.set('Server', 'Caisse-Deno')
  headers.set('Accept-Ranges', 'bytes')
  headers.set('Date', new Date().toUTCString())

  let status = 200

  const tryOpenFile = async (path) => {
    let file
    let fileInfo
    try {
      // XXX: Atomicity is sacrificed here, but as of December 2022
      // the Deno Deploy runtime does not support FsFile.stat()
      // and throws an exception (EISDIR) on Deno.open()'ing a directory
      fileInfo = await Deno.stat(siteRootDir + path)
      if (fileInfo.isDirectory) return null
      file = await Deno.open(siteRootDir + path)
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null
      throw e
    }
    return {
      path, file,
      fileSize: fileInfo.size,
    }
  }

  const { path: realPath, file, fileSize } =
    await tryOpenFile(path) ||
    (opts.isRaw ? (await tryOpenFile(path + `/raw`)) : null) ||
    await tryOpenFile(path + `/index.${opts.lang}.html`) ||
    await tryOpenFile(path + `/index.html`) ||
    {}
  if (realPath === undefined) {
    // In case the 404 page is not rendered
    if (path === '/_/404') return new Response('', { status: 404, headers })
    return notFoundPage(req, opts, headers, path)
  }

  headers.set('Content-Type', mime(realPath))
  if ((await metaGet(realPath, 'COOP')) === true) {
    headers.set('Cross-Origin-Opener-Policy', 'same-origin')
    headers.set('Cross-Origin-Embedder-Policy', 'require-corp')
  }

  if (realPath.endsWith('.html')) {
    persistLog([
      req.url + (path === '/_/404' ? ' *' : ''),
      JSON.stringify(opts),
      req.headers.get('User-Agent'),
      req.aux.remoteHost,
      req.headers.get('Referer'),
    ].map((s) => (s || '').replace(/\t/g, ' ')).join('\t'))
    if (path === '/_/404') status = 404
    // Templates
    let text = new TextDecoder().decode(await readAll(file))
    const timeInMinCur = timeInMin(opts.tz || 8 * 60)
    const timeOfDayCur = timeOfDay(timeInMinCur)
    const fetched = {}
    text = text.replace(/<!-- \((.+?)\)\s?(.*?)\s*-->/gs, (_, key, value) => {
      if (key === 'dark') {
        const spacePos = value.indexOf(' ')
        if (spacePos !== -1)
          return (opts.isDark ? value.substring(0, spacePos) : value.substring(spacePos + 1))
        else
          return (opts.isDark ? value : '')
      } else if (key === 'timeofday') {
        return value.split('\n')[timeOfDayCur].substring(3)
      } else if (key === 'shuffle') {
        const [_, seedBase, phase, content] =
          /^\s*(\d+)\s+([\d.]+)\s*((?:.|\n)*)$/.exec(value)
        const lineEnd = content.indexOf('\n')
        const sep = content.substring(0, lineEnd)
        if (sep === '') return ''
        const items = content.substring(lineEnd + 1).split(sep)
        const seed = (+seedBase) + Math.floor(timeInMinCur / 10 + (+phase))
        let g = { seed }
        for (let i = 0; i < 6; i++) g = randNext(g)
        for (let i = 1; i < items.length; i++) {
          g = randNext(g)
          const j = g.sum % (i + 1)
          const t = items[i]
          items[i] = items[j]
          items[j] = t
        }
        return items.join('\n')
      } else if (key === 'cataloguesearch') {
        const enteredPath = decodeURI((new URL(req.url)).pathname).substring(1)
        const best = []
        for (const [_, path, content] of value.matchAll(/(\S+) (.+)(?:\n|$)/g)) {
          const score = editScore(enteredPath, path)
          best.push({ score, content })
        }
        best.sort((a, b) => a.score - b.score)
        return best.slice(0, 5).map(x => x.content).join('')
      } else if (key === 'fetch') {
        const lines = value.split('\n', 1)
        fetched[lines[0]] = null
        return _
      } else if (key === 'query') {
        const s = (new URL(req.url)).search
        return s ? ('&' + s.substring(1)) : ''
      } else if (key === 'chocolate') {
        const lineEnd = value.indexOf('\n')
        const params = value.substring(0, lineEnd).split('\t')
        const delim = params[0]
        const contentEnd = value.indexOf(delim, lineEnd + 1)
        const contentTempl = value.substring(lineEnd + 1, contentEnd)
        const entries = value.substring(contentEnd + delim.length)
          .split('\n').filter((s) => s.length > 0)
        const timeSeed = Math.floor(timeInMin(8 * 60) / 10)
        const plainRandom = (seed) => {
          const addr = req.aux.remoteHost
          for (let i = 0; i < addr.length; i++) {
            seed = seed * 997 + addr.charCodeAt(i) + 1
            seed = (seed / 4294967296) ^ seed
          }
          let g = { seed }
          for (let i = 0; i < 7; i++) g = randNext(g)
          return (g.sum >> 8)
        }
        const queryIndex = (new URL(req.url)).searchParams.get('index')
        const entryIndex = (
          (queryIndex !== null && +queryIndex >= 1 && +queryIndex <= entries.length) ?
          +queryIndex - 1 :
          nonRepeatRandom(plainRandom, timeSeed, entries.length)
        )
        const entryContent = entries[entryIndex].split('\t').reduce(
          (s, t, i) => s.replaceAll(params[1 + i], t), contentTempl)
        return entryContent
      }
    })
    for (const url in fetched)
      fetched[url] = await (await fetch(url)).text()
    text = text.replace(/<!-- \((.+?)\)\s?(.+?)\s*-->/gs, (_, key, value) => {
      if (key === 'fetch') {
        const lines = value.split('\n')
        let text = fetched[lines[0]]
        if (!text.match(new RegExp('^' + lines[1]))) return lines[2]
        for (const replacement of lines.slice(3)) {
          const spacePos = replacement.indexOf(' ')
          if (spacePos !== -1)
            text = text.replace(
              new RegExp(replacement.substring(0, spacePos), 'g'),
              replacement.substring(spacePos + 1))
        }
        return text
      }
    })
    headers.set('Cache-Control', 'no-store')
    return new Response(text, { status, headers })
  } else {
    // Static file
    const etag = await etagGet(realPath, file)
    headers.set('ETag', etag)
    const rangeHeader = req.headers.get('Range')
    const result = /bytes=(\d+)-(\d+)?/g.exec(rangeHeader)
    const byteStart = (result && result[1]) ? +result[1] : 0
    const byteEnd = (result && result[2]) ? +result[2] : fileSize - 1;
    if (byteStart < 0 || byteEnd >= fileSize || byteStart > byteEnd) {
      status = 416
      return new Response(null, { status, headers })
    }
    if (result) {
      headers.set('Content-Range', `bytes ${byteStart}-${byteEnd}/${fileSize}`)
      file.seek(byteStart, Deno.SeekMode.Start)
      status = 206
    }
    headers.set('Content-Length', (byteEnd - byteStart + 1).toString())
    if (realPath.match(/\.[0-9a-f]{8}\.[a-zA-Z0-9-_]+$/)  // Versioned
      || realPath.match(/^\/bin\/vendor\//)   // Vendored
    ) {
      headers.set('Cache-Control', 'public, max-age=31536000')
    } else {
      headers.set('Cache-Control', 'public, no-cache, max-age=31536000')
    }
    // Check whether not modified
    if (etagMatch(etag, req.headers.get('If-None-Match'))) {
      status = 304
      return new Response(null, { status, headers })
    }
    return new Response(
      file.readable.pipeThrough(new Truncate(byteEnd - byteStart + 1)),
      { status, headers }
    )
  }
}

const serveReq = async (req, info) => {
  const url = new URL(req.url)

  if (req.method === 'GET') {
    if (url.pathname === '/malletwand') {
      persistLog([
        req.url,
        '',
        req.headers.get('User-Agent'),
        info.remoteAddr.hostname,
        req.headers.get('Referer'),
      ].map((s) => (s || '').replace(/\t/g, ' ')).join('\t'))
      return redirectResponse('https://github.com/ayuusweetfish/Malletwand', null, true, true)
    }

    if (url.pathname.endsWith('/') && url.pathname.length > 1) {
      url.pathname = url.pathname.match(/^(.+?)\/+$/)[1]
      return redirectResponse(url, null, true, true)
    }

    const opts = {}
    const aux = (req.aux = {})
    aux.remoteHost = info.remoteAddr.hostname

    const headers = new Headers()
    const newCookies = {}
    // Parse cookies
    const cookies = {}
    const cookiesStr = req.headers.get('Cookie')
    const regexp = /([A-Za-z0-9-_]+)=(.*?)(?:(?=;)|$)/g
    let result
    while ((result = regexp.exec(cookiesStr)) !== null) {
      const [_, key, value] = result
      cookies[decodeURIComponent(key)] = decodeURIComponent(value)
    }
    // Options
    opts.isDark = (cookies['dark'] === '1')
    if (cookies['lang'] && supportedLangs.indexOf(cookies['lang']) !== -1) {
      opts.lang = cookies['lang']
    } else {
      opts.lang = negotiateLang(req.headers.get('Accept-Language') || '', supportedLangs)
      newCookies.lang = opts.lang
    }
    opts.isRaw = (url.searchParams.get('raw') !== null)
    // Timezone
    if (isFinite(cookies['tz'])) {
      const tz = -cookies['tz']
      if (tz >= -13 * 60 && tz <= 13 * 60) opts.tz = tz
    }
    // Query string
    let optsUpdatedByQuery = false
    const queryDark = url.searchParams.get('dark')
    if (queryDark !== null) {
      const isDarkNew = (queryDark === '1')
      opts.isDark = isDarkNew
      newCookies.dark = isDarkNew ? '1' : '0'
      optsUpdatedByQuery = true
      url.searchParams.delete('dark')
    }
    const queryLang = url.searchParams.get('lang')
    if (queryLang !== null &&
        supportedLangs.indexOf(queryLang) !== -1) {
      opts.lang = queryLang
      newCookies.lang = queryLang
      optsUpdatedByQuery = true
      url.searchParams.delete('lang')
    }
    // Set cookies
    for (const [key, value] of Object.entries(newCookies))
      headers.append('Set-Cookie', `${encodeURIComponent(key)}=${encodeURIComponent(value)}; SameSite=Strict; Path=/; Secure; Max-Age=2592000`)
    // Redirect to remove query string
    if (optsUpdatedByQuery) {
      return redirectResponse(url, headers)
    }

    // Routes
    if (url.pathname === '/') {
      return await staticFile(req, opts, headers, '/index')
    }
    if (url.pathname === '/favicon.ico' || url.pathname === '/favicon.png') {
      return await staticFile(req, opts, headers, '/bin/favicon.png')
    }
    if (url.pathname === '/_' || url.pathname.startsWith('/_/')) {
      return notFoundPage(req, opts, headers, decodeURI(url.pathname))
    }
    return await staticFile(req, opts, headers, decodeURI(url.pathname))
  }
  return new Response('hello')
}

const port = +Deno.env.get('PORT') || 1123
const server = Deno.serve({ port }, async (req, info) => {
  try {
    return await serveReq(req, info)
  } catch (e) {
    log(`Internal server error: ${e}`)
    return new Response('Internal server error', { status: 500 })
  }
})
log(`Running at http://localhost:${port}/`)
