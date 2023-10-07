// IMAP: RFC 3501 https://www.rfc-editor.org/rfc/rfc3501
// Headers: RFC 2822 https://www.rfc-editor.org/rfc/rfc2822

const hostname = Deno.env.get('MAILHOST')
const port = +Deno.env.get('MAILPORT') || 993
const userid = Deno.env.get('USER')
const pwd = Deno.env.get('PWD')
const myAddrs = (Deno.env.get('ADDRS') ? Deno.env.get('ADDRS').split(',') : null)
const listSize = +Deno.env.get('LISTSIZE') || 5
const mailboxName = Deno.env.get('MAILBOX') || 'INBOX'

const log = (s) => Deno.stdout.writeSync(new TextEncoder().encode(`${new Date().toISOString()} ${s}\n`))

// ====================
const fetchMails = async (count, inboxCountLast) => {
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
  const CHAR_ESC = '\\'.charCodeAt(0)

  // All strings in the response are enclosed by the double quote character
  // with all occurrences of characters " and \ prefixed by a backward slash (\)
  const consumeStrOrAtom = (s) => {
    if (s[0] === '"') {
      const unesc = []
      for (let i = 1; i < s.length; i++) {
        if (s[i] === '"') return [unesc.join(''), s.substring(i + 1).trimStart()]
        if (s[i] === '\\') i++
        unesc.push(s[i])
      }
      return [unesc.join(''), '']
    } else {
      let i = s.indexOf(' ')
      if (i === -1) i = s.length
      return [s.substring(0, i), s.substring(i + 1)]
    }
  }

  const createParser = function* () {
    const respBuf = []
    let c = yield
    while (true) {
      if (c === CHAR_CR) {
        if ((c = yield) !== CHAR_LF) log('Malformed line ending (expecting CRLF)')
        const str = (new TextDecoder().decode(new Uint8Array(respBuf)))
        const spacePos = str.indexOf(' ')
        const tag = str.substring(0, spacePos)
        const content = str.substring(spacePos + 1)
        c = yield { tag, content }
        respBuf.splice(0)
      } else if (c === CHAR_DQUOTE) {
        respBuf.push(CHAR_DQUOTE)
        while ((c = yield) !== CHAR_DQUOTE) {
          if (c === CHAR_DQUOTE || c === CHAR_ESC) respBuf.push(CHAR_ESC)
          respBuf.push(c)
        }
        respBuf.push(CHAR_DQUOTE)
        c = yield
      } else if (c === CHAR_BR_OPEN) {
        let num = 0
        while ((c = yield) != CHAR_BR_CLOSE)
          num = num * 10 + (c - CHAR_0)
        if ((c = yield) !== CHAR_CR) log('Malformed literal string (expecting CRLF)')
        if ((c = yield) !== CHAR_LF) log('Malformed line ending (expecting CRLF)')
        respBuf.push(CHAR_DQUOTE)
        for (let i = 0; i < num; i++) {
          c = yield
          if (c === CHAR_DQUOTE || c === CHAR_ESC) respBuf.push(CHAR_ESC)
          respBuf.push(c)
        }
        respBuf.push(CHAR_DQUOTE)
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
      if (n === 0) throw new Error('Connection closed')
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
      if (typeof descOnErr === 'function') {
        descOnErr = descOnErr()
        if (descOnErr instanceof Promise) descOnErr = await descOnErr
      }
      throw new Error(`${descOnErr}. IMAP response: ${resps[resps.length - 1].content}`)
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
    const result = {}
    const curStr = []
    for (const line of s.split('\r\n')) {
      if (line.match(/^\s/)) {
        curStr.push(line.trim())
      } else {
        // Start a new line
        const fullLine = curStr.splice(0).join(' ')
        const colonPos = fullLine.indexOf(':')
        if (colonPos !== -1) {
          const key = fullLine.substring(0, colonPos)
            .toLowerCase().replaceAll(/(-|^)[a-z]/g, (s) => s.toUpperCase())
          const value = fullLine.substring(colonPos + 1).trimStart()
          if (result[key] !== undefined) {
            const list = (result[key + '.list'] || (result[key + '.list'] = [result[key]]))
            list.push(value)
          } else {
            result[key] = value
          }
        }
        curStr.push(line.trim())
      }
    }
    return result
  }

  const parseAddresses = (header) => {
    const addrs = []
    for (const entry of header.split(',')) {
      const entryTrimmed = entry.trim()
      const match = entryTrimmed.match(/^.+<([A-Za-z0-9.\-_]+@[A-Za-z0-9.\-_]+)>$/)
      addrs.push(match !== null ? match[1] : entryTrimmed)
    }
    return addrs
  }

  const arrayIntersection = (a, b) => {
    const set = new Set()
    for (const v of a) set.add(v)
    for (const v of b) if (set.has(v)) return v
    return null
  }

  log('Logging in')
  await cmd(`LOGIN "${userid}" "${pwd}"`, 'Invalid credentials')

  log('Examining inbox')
  const inboxCount = +extractResps(
    await cmd(`EXAMINE ${mailboxName}`, async () => {
      let mailboxesStr
      try {
        const mailboxes = extractResps(
          await cmd(`LIST "" *`, 'Cannot list'),
          /^LIST \(.+?\) (.+)$/
        ).map(([s]) => {
          let t
          ;[t, s] = consumeStrOrAtom(s)   // t = hierarchy delimiter (unused)
          ;[t, s] = consumeStrOrAtom(s)   // t = name
          return t
        })
        mailboxesStr = `List of mailboxes: "${mailboxes.join('", "')}"`
      } catch (e) {
        mailboxesStr = `Cannot fetch list of mailboxes (${e})`
      }
      return `Cannot select mailbox "${mailboxName}". ${mailboxesStr}`
    }),
    /^([0-9]+) EXISTS$/
  )[0][0]
  if (inboxCount === inboxCountLast) {
    await cmd('LOGOUT', 'Log out')
    return [inboxCount, null]
  }

  const mails = []

  for (let fromMe = 0; fromMe <= 1; fromMe++) {
    const queryWd = fromMe ? 'FROM' : 'TO'
    log(`Searching inbox (${queryWd})`)
    let resultList
    if (!myAddrs) {
      resultList = Array.from({length: inboxCount}, (_, i) => i + 1)
    } else {
      const query = myAddrs.map((addr, i) =>
        (i === myAddrs.length - 1 ? `${queryWd} ` : `OR ${queryWd} `) + addr).join(' ')
      resultList = extractResps(await cmd(`SEARCH ${query}`, 'Search'), /^SEARCH([0-9 ]*)$/)[0][0]
        .trim().split(' ').map((w) => w === '' ? undefined : +w)
      resultList.sort()
    }

    const correspCollected = {}
    while (Object.keys(correspCollected).length < count && resultList.length > 0) {
      const fetchList = resultList.splice(-Math.floor(count * 1.5)).join(',')
      if (fetchList.length > 0) {
        log(`Fetching ${fetchList}`)
        const headersMatched = extractResps(
          await cmd(`FETCH ${fetchList} (BODY[HEADER])`, 'Fetch message headers'),
          /^([0-9]+) FETCH \(BODY\[HEADER\] (.+)\)$/s
        )
        const headersSorted = []
        for (const [_seqStr, headersStrQuoted] of headersMatched) {
          const [headersStr, _] = consumeStrOrAtom(headersStrQuoted)
          const headers = parseHeaders(headersStr)
          const date = new Date(headers['Date'])
          const fromAddrs = parseAddresses(headers['From'])
          const toAddrs = parseAddresses(headers['To'])
          let from = fromAddrs[0]
          let to = toAddrs[0]
          if (myAddrs) {
            if (fromMe) from = arrayIntersection(fromAddrs, myAddrs)
            else to = arrayIntersection(toAddrs, myAddrs)
          }
          const corresp = (fromMe ? to : from)
          if ((!myAddrs || (fromMe ? from : to) !== null) &&
              (!correspCollected[corresp] || correspCollected[corresp].date < date)) {
            correspCollected[corresp] = { date, from, to }
          }
        }
      }
    }
    const collectedList = Object.values(correspCollected)
    collectedList.sort((a, b) => b.date - a.date)
    collectedList.splice(count)
    mails[fromMe] = collectedList
  }

  await cmd('LOGOUT', 'Log out')
  return [inboxCount, mails]
} // fetchMails
// ====================

let mailsText
let inboxCountLast
const updateMails = async () => {
  for (let retries = 0; retries < 3; retries++) {
      const [inboxCount, mails] = await fetchMails(listSize, inboxCountLast)
      if (inboxCount !== inboxCountLast) {
        inboxCountLast = inboxCount
        mailsText =
          mails[0].map(({ date, from, to }) => {
            const dateStr = date.toISOString()
            return `${dateStr.substring(2, 8)}~~ ${dateStr.substring(11, 13)}:~~\t` +
              `${from[0]}~~~~@~~~~~\n`
          }).join('')
          + '---\n' +
          mails[1].map(({ date, from, to }) => {
            const dateStr = date.toISOString()
            return `${dateStr.substring(2, 10)} ${dateStr.substring(11, 13)}:~~\t` +
              `~~~~${to.match(/.(?=@)/)}@~~${to.match(/@[^.]+?(.)(?=\.)/)[1]}.~\n`
          }).join('')
      }
      break
  }
}

await updateMails()
setInterval(() => updateMails(), 60000)

const serveReq = /*async*/ (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/') return new Response(mailsText)
  return new Response('Not found', { status: 404 })
}

const serverPort = +Deno.env.get('SERVEPORT') || 2339
const server = Deno.listen({ port: serverPort })
log(`Running at http://localhost:${serverPort}/`)

const handleConn = async (conn) => {
  const httpConn = Deno.serveHttp(conn)
  try {
    for await (const evt of httpConn) (async () => {
      const req = evt.request
      try {
        req.conn = conn
        await evt.respondWith(/*await*/ serveReq(req))
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
