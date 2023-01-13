const server = Deno.args[0]

const serverDomain = server.match(/(?:[A-Za-z0-9-]+\.)+[A-Za-z0-9-]+/g)[0]
const dir = 'emojis_' + serverDomain
console.log(`Save location: ${dir}`)
try {
  await Deno.mkdir(dir)
} catch (e) {
  if (!(e instanceof Deno.errors.AlreadyExists)) throw e
}

const token = Deno.env.get('TOKEN')
const authHeaders = token ? { 'Authorization': `Bearer ${token}` } : undefined
const resp = await (await fetch(
  `${server}/api/v1/custom_emojis`, { headers: authHeaders }
)).json()

const downloadFile = async (url, path, headers) => {
  const resp = await fetch(url, { headers })
  const f = await Deno.open(path, {write: true, create: true})
  await resp.body.pipeTo(f.writable)
  console.log(`Downloaded ${path}`)
}
for (const em of resp) {
  const ext = em.static_url.match(/\.([^.]+)$/)[1]
  downloadFile(em.static_url, `${dir}/${em.shortcode}.${ext}`, authHeaders)
}
