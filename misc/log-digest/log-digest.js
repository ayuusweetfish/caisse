// LOG_PATH=log1.txt sh -c 'deno run --allow-env=LOG_PATH,PORT --allow-read=$LOG_PATH --allow-run=openssl,tail --allow-net log-digest.js'

const log_path = Deno.env.get('LOG_PATH')
if (!log_path) {
  console.log('Please specify a path through environment variable LOG_PATH')
  Deno.exit(1)
}

const port = +Deno.env.get('PORT') || 11233

let digest, timestamp

const rehash = async () => {
  const p1 = (new Deno.Command('openssl', {
    args: ['dgst', '-sha3-512', '-hex', '-r', log_path],
    stdout: 'piped',
  })).spawn()
  const digest = (new TextDecoder()).decode((await p1.output()).stdout).match(/^[0-9a-fA-F]{128}/)[0]

  const p2 = (new Deno.Command('tail', {
    args: ['-n', '1', log_path],
    stdout: 'piped',
  })).spawn()
  const timestamp = (new TextDecoder()).decode((await p2.output()).stdout).match(/^.([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z)/)[1]

  return [digest, timestamp]
}
const update = async () => {
  try {
    [digest, timestamp] = await rehash()
  } catch (e) {
    // console.log(`${(new Date()).toISOString()} Rehash failed`)
    [digest, timestamp] = [null, null]
  }
}
await update()

const watcher = Deno.watchFs(log_path)
;(async () => {
  for await (const event of watcher) {
    if (event.kind === 'modify') {
      await update()
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
