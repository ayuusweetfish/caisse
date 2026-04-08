// deno run --allow-read=/tmp/caisse-katex-list.txt --allow-write=rendered.txt process.js
import katex from 'https://cdn.jsdelivr.net/npm/katex@0.16.28/dist/katex.mjs'
  // SHA256: b19a18ebd27191f66a60421dbf15bcb97486f46713ad51a2a4a6fd2aa37e96f3

const rendered = []
for (const line of (await Deno.readTextFile('/tmp/caisse-katex-list.txt')).split('\n')) {
  const [_, hash, isDisp, string] = /^(.+?)\t(.+?)\t(.+)$/g.exec(line)
  const s = katex.renderToString(string.replace(/\t/g, '\n'), {
    displayMode: isDisp === '1',
    throwOnError: false,
  }).replace(/\n/g, '\t')
  rendered.push([hash, s])
}

const outFile = await Deno.open('rendered.txt',
  { read: false, write: true, create: true, truncate: true })
const outWriter = outFile.writable.getWriter()
for (const [hash, s] of rendered.sort()) {
  await outWriter.write(new TextEncoder().encode(`${hash}\t${s}\n`))
}
await outWriter.close()
