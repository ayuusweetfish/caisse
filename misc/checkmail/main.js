// IMAP: RFC 3501 https://www.rfc-editor.org/rfc/rfc3501
// Headers: RFC 2822 https://www.rfc-editor.org/rfc/rfc2822

const hostname = Deno.env.get('HOST')
const port = Deno.env.get('PORT') || 993
const userid = Deno.env.get('USER')
const pwd = Deno.env.get('PWD')

const conn = await Deno.connectTls({ hostname, port })

const writeAll = async (w, buf) => {
  const n = buf.length
  let nw = 0
  while (nw < n) nw += await w.write(buf.subarray(nw))
}

const CHAR_BR_OPEN = '{'.charCodeAt(0)
const CHAR_BR_CLOSE = '}'.charCodeAt(0)
const CHAR_DQUOTE = '"'.charCodeAt(0)
const CHAR_0 = '0'.charCodeAt(0)
const CHAR_CR = '\r'.charCodeAt(0)
const CHAR_LF = '\n'.charCodeAt(0)

const MARK_STR_BOUNDARY = 255

const createParser = function* () {
  const respBuf = []
  let c = yield
  while (true) {
    if (c === CHAR_CR) {
      c = yield   // Assume LF
      const str = (new TextDecoder().decode(new Uint8Array(respBuf)))
      const spacePos = str.indexOf(' ')
      const tag = str.substring(0, spacePos)
      const content = str.substring(spacePos + 1)
      c = yield { tag, content }
      respBuf.splice(0)
    } else if (c === CHAR_DQUOTE) {
      respBuf.push(MARK_STR_BOUNDARY)
      while ((c = yield) !== CHAR_DQUOTE) respBuf.push(c)
      respBuf.push(MARK_STR_BOUNDARY)
      c = yield
    } else if (c === CHAR_BR_OPEN) {
      let num = 0
      while ((c = yield) != CHAR_BR_CLOSE)
        num = num * 10 + (c - CHAR_0)
      c = yield   // Assume CR
      c = yield   // Assume LF
      respBuf.push(MARK_STR_BOUNDARY)
      for (let i = 0; i < num; i++) respBuf.push(c = yield)
      respBuf.push(MARK_STR_BOUNDARY)
      c = yield
    } else {
      respBuf.push(c)
      c = yield
    }
  }
}
const parser = createParser()
parser.next()

const read = async () => {
  const bufr = new Uint8Array(1)
  while (true) {
    const n = await conn.read(bufr)
    for (let i = 0; i < n; i++) {
      const status = parser.next(bufr[i])
      if (status.value !== undefined) return status.value
    }
  }
}

let id = 0
const cmd = async (text, descOnErr) => {
  const tag = 'A' + (id++).toString().padStart(4, '0')
  const bufw = new TextEncoder().encode(`${tag} ${text}\r\n`)
  await writeAll(conn, bufw)
  const resps = []
  let resp
  while (true) {
    resps.push(resp = await read())
    if (resp.tag === tag) break
  }
  if (!resps[resps.length - 1].content.startsWith('OK ')) {
    console.log(descOnErr)
    Deno.exit()
  }
  return resps
}

const extractResps = (resps, regexp) => {
  const results = []
  for (const resp of resps) if (resp.tag === '*') {
    const result = resp.content.match(regexp)
    if (result) results.push(result.slice(1))
  }
  return results
}

const parseHeaders = (s) => {
  const result = []
  for (const line of s.split('\r\n')) {
    result.push(line)
  }
  return result
}

console.log('Logging in')
await cmd(`LOGIN "${userid}" "${pwd}"`, 'Invalid credentials')
console.log('Examining inbox')
// const nexists = +extractResps(await cmd(`EXAMINE INBOX`, 'Examine inbox'), /^([0-9]+) EXISTS$/)[0][0]
// console.log(nexists)
await cmd(`EXAMINE INBOX`, 'Examine inbox')

console.log('Searching inbox')
const list = extractResps(await cmd(`SEARCH TO claire@ayu.land`), /^SEARCH([0-9 ]+)$/)[0][0]
  .trim().split(' ').map((w) => +w)
list.sort()

console.log(`Fetching ${list.slice(-5).join(',')}`)
const headersMatched = extractResps(
  await cmd(`FETCH ${list.slice(-5).join(',')} (BODY[HEADER])`, 'Fetch message headers'),
  /^([0-9]+) FETCH \(BODY\[HEADER\] .(.+).\)$/s
)
for (const [nStr, headersStr] of headersMatched) {
  const n = +nStr
  const headers = parseHeaders(headersStr)
  console.log(n, headers)
}
