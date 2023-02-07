const domain = 'ayu.land'
const issuer = `https://${domain}/indieauth`
const meRe = /^(https?:\/\/)?ayu.land\/?$/
const meUrl = `https://${domain}`

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
  if (arg.response_type !== 'code') return fail('response_type')
  if (arg.code_challenge_method !== 'S256') return fail('code_challenge_method')
  if (!arg.me.match(meRe)) return fail('me')
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
  if (cookies.pw === '11') {
    // Generate a new code
    const code = crypto.randomUUID()
    codes[code] = {
      client_id: arg.client_id,
      redirect_uri: arg.redirect_uri,
      code_challenge: arg.code_challenge,
    }
    setTimeout(() => delete codes[code], 30000)
    return new Response('', {
      status: 302,
      headers: {
        'Location': arg.redirect_uri +
          `?code=${code}&state=${arg.state}&iss=${encodeURIComponent(issuer)}`,
      },
    })
  } else {
    return new Response('waiting auth')
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
  if (arg.grant_type !== 'authorization_code') return fail('grant_type')
  const codeArg = codes[arg.code]
  if (!codeArg) return fail('code')
  if (arg.client_id !== codeArg.client_id) return fail('client_id')
  if (arg.redirect_uri !== codeArg.redirect_uri) return fail('redirect_uri')
  const digest = await crypto.subtle.digest(
    'SHA-256', (new TextEncoder()).encode(arg.code_verifier))
  const digestBase64 = base64.encode(digest).split('=')[0]
  if (codeArg.code_challenge !== digestBase64) return fail('code_verifier')
  // Successful, invalidate authorisation code
  delete codes[arg.code]
  return new Response(JSON.stringify({ me: meUrl }))
}

const indieAuth = async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/indieauth/metadata') {
    return new Response(JSON.stringify({
      issuer: issuer,
      authorization_endpoint: `https://${domain}/indieauth/auth`,
      code_challenge_methods_supported: ['S256'],
    }))
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
