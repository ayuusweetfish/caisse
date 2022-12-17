import { readAll } from 'https://deno.land/std@0.168.0/streams/read_all.ts'

const log = (msg) => console.log(`${(new Date()).toISOString()} ${msg}`)

const port = +Deno.env.get('PORT') || 1123
const server = Deno.listen({ port })
log(`Running at http://localhost:${port}/`)

const mime = (s) => {
  if (s.endsWith('.html')) return 'text/html; charset=UTF-8'
  if (s.endsWith('.css')) return 'text/css; charset=UTF-8'
  if (s.endsWith('.svg')) return 'image/svg+xml'
  if (s.endsWith('.mp4')) return 'media/mp4'
  return 'application/octet-stream'
}

const setCookie = (headers, key, value) => {
  headers.append('Set-Cookie', `${encodeURIComponent(key)}=${encodeURIComponent(value)}; SameSite=Strict; Max-Age=2592000`)
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

const staticFile = async (req, opts, headers, path) => {
  headers.set('Server', 'Caisse-Deno')
  headers.set('Accept-Ranges', 'bytes')
  headers.set('Date', new Date().toUTCString())

  let status = 200

  let file
  let fileInfo
  try {
    file = await Deno.open(path)
    fileInfo = await file.stat()
    if (fileInfo.isDirectory) {
      path += '/index.html'
      file = await Deno.open(path)
      fileInfo = await file.stat()
    }
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) {
      return new Response('', { status: 404, headers })
    } else {
      throw e;
    }
  }

  const rangeHeader = req.headers.get('Range')
  const result = /bytes=(\d+)-(\d+)?/g.exec(rangeHeader)
  const byteStart = (result && result[1]) ? +result[1] : 0
  const byteEnd = (result && result[2]) ? +result[2] : fileInfo.size - 1;
  if (result) {
    headers.set('Content-Range', `bytes ${byteStart}-${byteEnd}/${fileInfo.size}`)
    file.seek(byteStart, Deno.SeekMode.Start);
    status = 206
  }
  headers.set('Content-Length', (byteEnd - byteStart + 1).toString())
  headers.set('Content-Type', mime(path))

  if (path.endsWith('.html')) {
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
    return new Response(file.readable, { status, headers })
  }
}

const serveReq = async (req) => {
  const url = new URL(req.url)
  if (req.method === 'GET') {
    const opts = {}
    const headers = new Headers()
    // Parse cookies
    const cookies = {}
    const cookiesStr = req.headers.get('Cookie')
    const regexp = /([A-Za-z0-9-_]+)=(.+?)(?:(?=;)|$)/g
    let result
    while ((result = regexp.exec(cookiesStr)) !== null) {
      const [_, key, value] = result
      cookies[decodeURIComponent(key)] = decodeURIComponent(value)
    }
    opts.isDark = (cookies['dark'] === '1')
    // Query string
    if (url.search !== '') {
      const map = {}
      const regexp = /([A-Za-z0-9-_]+)=(.+?)(?:(?=&)|$)/g
      let result
      while ((result = regexp.exec(url.search)) !== null) {
        const [_, key, value] = result
        map[decodeURIComponent(key)] = decodeURIComponent(value)
      }
      if (map['dark'] !== undefined) {
        const isDarkNew = (map['dark'] === '1')
        setCookie(headers, 'dark', isDarkNew ? '1' : '0')
        opts.isDark = isDarkNew
      }
    }
    // Routes
    if (url.pathname === '/') {
      return await staticFile(req, opts, headers, '../build/index/index.html')
    }
    return await staticFile(req, opts, headers, '../build' + url.pathname);  // XXX: Don't do this
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
