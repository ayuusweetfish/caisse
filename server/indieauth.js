const issuer = (origin) => `${origin}/indieauth`
const meRe = (host) => new RegExp(`^(?:https?://)?${host}/?$`)
const meUrl = (origin) => `${origin}`

// https://indieauth.spec.indieweb.org/
// Legacy, without PKCE: https://indieauth.spec.indieweb.org/20200125/

import * as base64 from 'https://deno.land/std@0.177.0/encoding/base64.ts'

const fail = (text) => new Response(`Invalid: ${text}\n`, { status: 400 })

const codes = {}

const authEndpointGet = async (req) => {
  const url = new URL(req.url)
  const arg = {}
  for (const key of [
    'response_type',
    'client_id', 'redirect_uri', 'state',
    'code_challenge', 'code_challenge_method',
    'me',
  ]) {
    arg[key] = url.searchParams.get(key)
  }
  // Validity checks
  if (arg.response_type && arg.response_type !== 'code' && arg.response_type !== 'id')
    return fail('response_type')
  const legacy = (arg.response_type === 'id')
  if (!legacy && arg.code_challenge_method !== 'S256') return fail('code_challenge_method')
  if (!arg.me.match(meRe(url.host))) return fail('me')
  // Check dynamic password
  // Parse cookies
  const cookies = {}
  const cookiesStr = req.headers.get('Cookie')
  const regexp = /([A-Za-z0-9-_]+)=(.*?)(?:(?=;)|$)/g
  let result
  while ((result = regexp.exec(cookiesStr)) !== null) {
    const [_, key, value] = result
    cookies[decodeURIComponent(key)] = decodeURIComponent(value)
  }
  let pwChecked = false
  const masterPw = Deno.env.get('INDIEAUTH_PW')
  const time = Math.floor(+new Date() / (30 * 1000))
  if (cookies.pw) {
    const cur = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-512',
      (new TextEncoder()).encode(`${masterPw}${time}${masterPw}`))))
      .map((b) => b.toString(16).padStart(2, '0')).join('')
    if (cookies.pw === cur) pwChecked = true
    if (!pwChecked) {
      const last = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-512',
        (new TextEncoder()).encode(`${masterPw}${time - 1}${masterPw}`))))
        .map((b) => b.toString(16).padStart(2, '0')).join('')
      if (cookies.pw === last) pwChecked = true
    }
  }
  if (pwChecked) {
    // Generate a new code
    const code = crypto.randomUUID()
    codes[code] = {
      legacy: legacy,
      client_id: arg.client_id,
      redirect_uri: arg.redirect_uri,
      code_challenge: arg.code_challenge,
    }
    setTimeout(() => delete codes[code], 30000)
    return new Response('', {
      status: 302,
      headers: {
        'Location': arg.redirect_uri +
          `?code=${code}&state=${arg.state}&iss=${encodeURIComponent(issuer(url.origin))}`,
      },
    })
  } else {
    // Client information discovery
    // XXX: Neither IndieWebRing not IndieLogin.com implemented the h-app Microformat
    const clientUrl = new URL(arg.client_id)
    // Check against loopback ranges
    let recordFound = false
    for (const ty of ['A', 'AAAA']) {
      try {
        const addrs = await Deno.resolveDns(clientUrl.hostname, ty)
        for (const addr of addrs)
          if ((ty === 'A' && (addr.startsWith('127.') || addr.startsWith('0.'))) ||
              (ty === 'AAAA' && addr.match(/^(?:0*\:)*?:?0*1$/)))
            return fail('DNS resolution of client_id')
        recordFound = true
      } catch (e) {
        if (!(e instanceof Deno.errors.NotFound)) throw e
      }
    }
    if (!recordFound) return fail('DNS resolution of client_id')
    // Fetch and parse
    if ((new URL(arg.redirect_uri)).hostname !== clientUrl.hostname) {
      const clientReq = await fetch(arg.client_id)
      const text = await clientReq.text()
      const redirects = []
      for (const [name, val] of clientReq.headers) if (name === 'Link') {
        for (const link of val.split(',')) {
          const result = link.match(/^\s*<(.+)>;(.*;)*\s*rel="?redirect_uri"?(?:$| |;)/)
          if (result) redirects.push(result[1])
        }
      }
      // Very crude matches
      for (const [el] of text.matchAll(/<link[^>]*?(?:(?<=["'\s])rel=["']?redirect_uri["']?).*?>/g)) {
        const match = el.match(/href=["']([^>]+)['"]/)
        if (match) redirects.push(match[1])
      }
      console.log(redirects)
      if (redirects.indexOf(arg.redirect_uri) === -1)
        return fail('redirect_uri')
    }
    return new Response(`Pending auth from ${arg.client_id}`)
  }
}

const authEndpointPost = async (req) => {
  const form = await req.formData()
  const arg = {}
  for (const key of [
    'grant_type',
    'code', 'client_id', 'redirect_uri', 'code_verifier',
  ]) {
    arg[key] = form.get(key)
  }
  // Validity checks
  if (arg.grant_type && arg.grant_type !== 'authorization_code') return fail('grant_type')
  const codeArg = codes[arg.code]
  if (!codeArg) return fail('code')
  if (arg.client_id !== codeArg.client_id) return fail('client_id')
  if (arg.redirect_uri !== codeArg.redirect_uri) return fail('redirect_uri')
  if (!codeArg.legacy) {
    const digest = await crypto.subtle.digest(
      'SHA-256', (new TextEncoder()).encode(arg.code_verifier))
    const digestBase64 = base64.encode(digest)
      .split('=')[0].replaceAll('+', '-').replaceAll('/', '_')
    if (codeArg.code_challenge !== digestBase64) return fail('code_verifier')
  }
  // Successful, invalidate authorisation code
  delete codes[arg.code]
  const url = new URL(req.url)
  return Response.json({
    me: meUrl(url.origin),
    scope: (codeArg.legacy ? 'read' : undefined),
  })
}

const indieAuth = async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/indieauth/metadata') {
    return Response.json({
      issuer: issuer(url.origin),
      authorization_endpoint: `${url.origin}/indieauth/auth`,
      code_challenge_methods_supported: ['S256'],
    })
  } else if (url.pathname === '/indieauth/auth') {
    if (req.method === 'GET') return await authEndpointGet(req)
    else if (req.method === 'POST') return await authEndpointPost(req)
  }
  return new Response('', { status: 404 })
}

export { indieAuth }

/*
curl -v 'http://localhost:1123/indieauth/auth?response_type=code&client_id=https://app.example.com/&redirect_uri=https://app.example.com/redirect&state=1234567890&code_challenge=OfYAxt8zU2dAPDWQxTAUIteRzMsoj9QBdMIVEDOErUo&code_challenge_method=S256&me=https://ayu.land'

curl -v 'http://localhost:1123/indieauth/auth?response_type=code&client_id=https://app.example.com/&redirect_uri=https://app.example.com/redirect&state=1234567890&code_challenge=OfYAxt8zU2dAPDWQxTAUIteRzMsoj9QBdMIVEDOErUo&code_challenge_method=S256&me=https://ayu.land' -H 'Cookie: pw=11'

curl -v 'http://localhost:1123/indieauth/auth' -d 'grant_type=authorization_code&client_id=https://app.example.com/&redirect_uri=https://app.example.com/redirect&code_verifier=a6128783714cfda1d388e2e98b6ae8221ac31aca31959e59512c59f5&code=...'
*/
