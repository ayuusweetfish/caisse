import katex from './katex.mjs'

const rendered = {}
for (const line of (await Deno.readTextFile('list.txt')).split('\n')) {
  const [_, hash, isDisp, string] = /^(.+?)\t(.+?)\t(.+)$/g.exec(line)
  if (rendered[hash]) continue
  const s = katex.renderToString(string.replace(/\t/g, '\n'), {
    displayMode: isDisp === '1',
    throwOnError: false,
  }).replace(/\n/g, '\t')
  rendered[hash] = s
}

const outFile = await Deno.open('rendered.txt',
  { read: false, write: true, create: true, truncate: true })
const outWriter = outFile.writable.getWriter()
for (const [hash, s] of Object.entries(rendered).sort()) {
  await outWriter.write(new TextEncoder().encode(`${hash}\t${s}\n`))
}
outFile.close()
