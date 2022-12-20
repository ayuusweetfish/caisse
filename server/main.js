import { readAll } from 'https://deno.land/std@0.168.0/streams/read_all.ts'

const log = (msg) => console.log(`${(new Date()).toISOString()} ${msg}`)

const port = +Deno.env.get('PORT') || 1123
const server = Deno.listen({ port })
log(`Running at http://localhost:${port}/`)

const supportedLangs = ['zh', 'en']

const mime = (s) => {
  if (s.endsWith('.html')) return 'text/html; charset=UTF-8'
  if (s.endsWith('.css')) return 'text/css; charset=UTF-8'
  if (s.endsWith('.svg')) return 'image/svg+xml'
  if (s.endsWith('.mp4')) return 'media/mp4'
  if (s.endsWith('.js')) return 'application/javascript'
  if (s.endsWith('.wasm')) return 'application/wasm'
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
      hash = hash * 997 + buf[i]
      hash = (hash / 4294967296) ^ hash
    }
  }
  if (hash < 0) hash += 4294967296
  file.seek(0, Deno.SeekMode.Start)
  const etag = hash.toString(16).padStart(8, '0')
  etagReg[path] = `"${etag}"`
  return etag
}

const redirectResponse = (url, headers, isPerm, isNoCache) => {
  if (!headers) headers = new Headers()
  headers.set('Location', url)
  if (isNoCache) headers.set('Cache-Control', 'no-store')
  return new Response(
    `<html><body>Redirecting to <a href="${url}">${url}</a></body></html>`,
    { status: isPerm ? 301 : 303, headers }
  )
}

const timeOfDay = () => {
  const timestampMinute = Math.floor(Date.now() + 3600000 * 8) / 60000
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
    let seed = timestampMinute & 0xffffffff   // Works for 8166 years
    let rand = 0
    for (let i = 0; i < 5; i++) {
      seed = (seed * 1664525 + 1013904223) & 0x7fffffff // Avoid negative values
      rand ^= seed
    }
    return (rand % 60 <= phase ? period : (period + 11) % 12)
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

const staticFile = async (req, opts, headers, path) => {
  headers.set('Server', 'Caisse-Deno')
  headers.set('Accept-Ranges', 'bytes')
  headers.set('Date', new Date().toUTCString())

  let status = 200

  const tryOpenFile = async (path) => {
    let file
    let fileInfo
    try {
      file = await Deno.open(path)
      fileInfo = await file.stat()
      if (fileInfo.isDirectory) return null
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

  const etag = await etagGet(realPath, file)

  const rangeHeader = req.headers.get('Range')
  const result = /bytes=(\d+)-(\d+)?/g.exec(rangeHeader)
  const byteStart = (result && result[1]) ? +result[1] : 0
  const byteEnd = (result && result[2]) ? +result[2] : fileSize - 1;
  if (result) {
    headers.set('Content-Range', `bytes ${byteStart}-${byteEnd}/${fileSize}`)
    file.seek(byteStart, Deno.SeekMode.Start)
    status = 206
  }
  headers.set('Content-Length', (byteEnd - byteStart + 1).toString())
  headers.set('Content-Type', mime(realPath))
  headers.set('Cross-Origin-Opener-Policy', 'same-origin')
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp')

  if (realPath.endsWith('.html')) {
    let text = new TextDecoder().decode(await readAll(file))
    const timeOfDayCur = timeOfDay()
    text = text.replace(/<!-- \((.+?)\)\s?(.+?)\s*-->/gs, (_, key, value) => {
      if (key === 'dark') {
        const spacePos = value.indexOf(' ')
        if (spacePos !== -1)
          return (opts.isDark ? value.substring(0, spacePos) : value.substring(spacePos + 1))
        else
          return (opts.isDark ? value : '')
      } else if (key == 'timeofday') {
        return value.split('\n')[timeOfDayCur].substring(3)
      }
    })
    return new Response(text, { status, headers })
  } else {
    headers.set('ETag', etag)
    headers.set('Cache-Control', 'public, max-age=10')
    return new Response(file.readable, { status, headers })
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
      headers.append('Set-Cookie', `${encodeURIComponent(key)}=${encodeURIComponent(value)}; SameSite=Strict; Max-Age=2592000`)
    // Redirect to remove query string
    if (optsUpdatedByQuery) {
      url.search = ''
      return redirectResponse(url, headers)
    }

    // Routes
    if (url.pathname === '/') {
      return await staticFile(req, opts, headers, '../build/index')
    }
    return await staticFile(req, opts, headers, '../build' +
      decodeURI(url.pathname))  // XXX: Don't do this
  }
  return new Response('hello')
}

const handleConn = async (conn) => {
  const httpConn = Deno.serveHttp(conn)
  try {
    for await (const evt of httpConn) {
      const req = evt.request
      try {
        await evt.respondWith(serveReq(req))
      } catch (e) {
        log(`Internal server error: ${e}`)
        await evt.respondWith(new Response('', { status: 500 }))
      }
    }
  } catch (e) {
    log(`Unhandled error: ${e}`)
  }
}
while (true) {
  const conn = await server.accept()
  handleConn(conn)
}
