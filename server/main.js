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

const staticFile = async (req, path) => {
  const headers = new Headers()
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

  return new Response(file.readable, {
    status,
    headers,
  })
}

const serveReq = async (req) => {
  const url = new URL(req.url)
  if (req.method === 'GET') {
    if (url.pathname === '/') {
      return await staticFile(req, '../build/index/index.html')
    }
    return await staticFile(req, '../build' + url.pathname);  // XXX: Don't do this
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
