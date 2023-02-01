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

const port = +Deno.env.get('PORT') || 1123
const server = Deno.listen({ port })
log(`Running at http://localhost:${port}/`)

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
    await tryOpenFile(path + `/index.${opts.lang}.html`) ||
    await tryOpenFile(path + `/index.html`) ||
    {}
  if (realPath === undefined)
    return new Response('', { status: 404, headers })

  headers.set('Content-Type', mime(realPath))
  if ((await metaGet(realPath, 'COOP')) === true) {
    headers.set('Cross-Origin-Opener-Policy', 'same-origin')
    headers.set('Cross-Origin-Embedder-Policy', 'require-corp')
  }

  if (realPath.endsWith('.html')) {
    persistLog([
      req.url,
      JSON.stringify(opts),
      req.headers.get('User-Agent'),
      req.conn.remoteAddr.hostname,
      req.headers.get('Referer'),
    ].map((s) => (s || '').replace(/\t/g, ' ')).join('\t'))
    // Templates
    let text = new TextDecoder().decode(await readAll(file))
    const timeInMinCur = timeInMin(opts.tz || 8 * 60)
    const timeOfDayCur = timeOfDay(timeInMinCur)
    text = text.replace(/<!-- \((.+?)\)\s?(.+?)\s*-->/gs, (_, key, value) => {
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

const serveReq = async (req) => {
  const url = new URL(req.url)
  if (req.method === 'GET') {
    if (url.pathname.endsWith('/') && url.pathname.length > 1) {
      url.pathname = url.pathname.match(/^(.+?)\/+$/)[1]
      return redirectResponse(url, null, true, true)
    }

    const opts = {}
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
    }
    const queryLang = url.searchParams.get('lang')
    if (queryLang !== null &&
        supportedLangs.indexOf(queryLang) !== -1) {
      opts.lang = queryLang
      newCookies.lang = queryLang
      optsUpdatedByQuery = true
    }
    // Set cookies
    for (const [key, value] of Object.entries(newCookies))
      headers.append('Set-Cookie', `${encodeURIComponent(key)}=${encodeURIComponent(value)}; SameSite=Strict; Path=/; Secure; Max-Age=2592000`)
    // Redirect to remove query string
    if (optsUpdatedByQuery) {
      url.search = ''
      return redirectResponse(url, headers)
    }

    // Routes
    if (url.pathname === '/') {
      return await staticFile(req, opts, headers, '/index')
    }
    if (url.pathname === '/favicon.ico' || url.pathname === '/favicon.png') {
      return await staticFile(req, opts, headers, '/bin/favicon.png')
    }
    return await staticFile(req, opts, headers, decodeURI(url.pathname))
  }
  return new Response('hello')
}

const handleConn = async (conn) => {
  const httpConn = Deno.serveHttp(conn)
  try {
    for await (const evt of httpConn) (async () => {
      const req = evt.request
      try {
        req.conn = conn
        await evt.respondWith(await serveReq(req))
      } catch (e) {
        if (!(e instanceof Deno.errors.Http)) {
          log(`Internal server error: ${e}`)
          try {
            await evt.respondWith(new Response('', { status: 500 }))
          } catch (e) {
            log(`Error writing 500 response: ${e}`)
          }
        }
      }
    })()
  } catch (e) {
    if (!(e instanceof Deno.errors.Http)) {
      log(`Unhandled error: ${e}`)
    }
  }
}
while (true) {
  const conn = await server.accept()
  handleConn(conn)
}
