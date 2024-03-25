// LOG_PATH=log1.txt,log2.txt sh -c 'deno run --allow-env=LOG_PATH,PORT --allow-read=$LOG_PATH --allow-run=openssl,tail --allow-net log-digest.js'
// openssl dgst -sha3-512 log1.txt

import { encodeHex, decodeHex } from 'https://deno.land/std@0.220.1/encoding/hex.ts'

const logPaths = (Deno.env.get('LOG_PATH') || '').split(',')
if (logPaths.length === 0) {
  console.log('Please specify a path through environment variable LOG_PATH')
  Deno.exit(1)
}

const port = +Deno.env.get('PORT') || 11233

let digest, timestamp

const rehash = async (path) => {
  const p1 = (new Deno.Command('openssl', {
    args: ['dgst', '-sha3-512', '-hex', '-r', path],
    stdout: 'piped',
  })).spawn()
  const digest = (new TextDecoder()).decode((await p1.output()).stdout).match(/^[0-9a-fA-F]{128}/)[0]

  const p2 = (new Deno.Command('tail', {
    args: ['-n', '1', path],
    stdout: 'piped',
  })).spawn()
  const timestamp = (new TextDecoder()).decode((await p2.output()).stdout).match(/^.([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z)/)[1]

  return [decodeHex(digest), timestamp]
}
const update = async (paths) => {
  if (typeof paths === 'string') paths = [paths]
  try {
    const allDigest = new Uint8Array(64)
    let maxTimestamp
    for (const path of logPaths) {
      const [digest, timestamp] = await rehash(path)
      for (let i = 0; i < 64; i++)
        allDigest[i] ^= digest[i]
      if (maxTimestamp === undefined || timestamp > maxTimestamp)
        maxTimestamp = timestamp
    }
    [digest, timestamp] = [encodeHex(allDigest), maxTimestamp]
  } catch (e) {
    // console.log(`${(new Date()).toISOString()} Rehash failed`)
    [digest, timestamp] = [null, null]
  }
}
await update(logPaths)

const watcher = Deno.watchFs(logPaths)
;(async () => {
  for await (const event of watcher) {
    if (event.kind === 'modify') {
      for (const path of event.paths) await update(path)
    }
  }
})()

Deno.serve({
  port,
}, async (req, info) => {
  if (digest === null)
    return new Response('', { status: 500 })
  return new Response(digest + '\n' + timestamp + '\n')
})
