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
      respBuf.push(c)
      while ((c = yield) !== CHAR_DQUOTE) respBuf.push(c)
      respBuf.push(c)
      c = yield
    //} else if (c === CHAR_BR_OPEN) {
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
const cmd = async (text) => {
  const tag = 'A' + (id++).toString().padStart(4, '0')
  const bufw = new TextEncoder().encode(`${tag} ${text}\r\n`)
  await writeAll(conn, bufw)
  const resps = []
  let resp
  while (true) {
    resps.push(resp = await read())
    if (resp.tag === tag) break
  }
  return resps
}

console.log(await cmd(`LOGIN "${userid}" "${pwd}"`))
console.log(await cmd(`EXAMINE INBOX`))
