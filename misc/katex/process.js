import katex from './katex.mjs'

const dedup = {}
const outFile = await Deno.open('rendered.txt',
  { read: false, write: true, create: true, truncate: true })
const outWriter = outFile.writable.getWriter()
const encoder = new TextEncoder()
for (const line of (await Deno.readTextFile('list.txt')).split('\n')) {
  const [_, hash, isDisp, string] = /^(.+?)\t(.+?)\t(.+)$/g.exec(line)
  if (dedup[hash]) continue
  dedup[hash] = true
  const s = katex.renderToString(string.replace(/\t/g, '\n'), {
    displayMode: isDisp === '1',
    throwOnError: false,
  }).replace(/\n/g, '\t')
  await outWriter.write(encoder.encode(`${hash}\t${s}\n`))
}
outFile.close()
