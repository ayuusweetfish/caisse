// deno run -A timeline.js <config.txt>
/* config format:
  <service name>
  <database.json>
  <service-specific arg>
  <service-specific arg>
  <...>
*/

const getJson = async (url, headers) => {
  for (let i = 0; i < 5; i++) {
    try {
      const text = await (await fetch(
        url,
        { headers },
      )).text()
      return JSON.parse(text)
    } catch (e) {
      console.log(`Retrying ${url}`)
    }
  }
  throw new Error(`Cannot fetch JSON from ${url}`)
}

const downloadFile = async (url, headers, dir, bannedType) => {
  try {
    await Deno.mkdir(dir)
  } catch (e) {
    if (!(e instanceof Deno.errors.AlreadyExists)) throw e
  }
  const resp = await fetch(url, { headers })
  if (bannedType && resp.headers.get('Content-Type').indexOf(bannedType) !== -1) {
    throw new Error(`File download returned unexpected type ${bannedType}. Please check cookies or tokens. Link: ${url}`)
  }
  let fileName = url.match(/\/([^\/]+)$/)[1]
  if (resp.headers.get('Content-Disposition')) {
    const fileNameInHeader = resp.headers.get('Content-Disposition').match(/filename=(.+)/)[1]
    if (fileNameInHeader) fileName = fileNameInHeader
  }
  console.log(`%cDownload file ${fileName} -- ${url}`, 'color: grey')
  let cached = false
  try {
    const f = await Deno.open(`${dir}/${fileName}`, {write: true, create: true, createNew: true})
    await resp.body.pipeTo(f.writable)
  } catch (e) {
    if (e instanceof Deno.errors.AlreadyExists) {
      cached = true
      await resp.body.cancel()
    }
    else throw e
  }
  console.log(`%cDownload file ${fileName} -- ` + (cached ? 'Cached, skipping' : 'Finished'), 'color: grey')
  return fileName
}

const methods_weibo = {
  async* get(args) {
    const cookie = args.cookie
    const downloadPics = (ids) => {
      for (const [i, id] of Object.entries(ids))
        ids[i] = downloadFile(
          `https://weibo.com/ajax/common/download?pid=${id}`,
          { 'Cookie': cookie },
          args.picsDir,
          'text/html',
        )
    }
    for (let i = 1; ; i++) {
      console.log(`==== page ${i} ====`)
      const respObj = await getJson(
        `https://weibo.com/ajax/statuses/mymblog?uid=${args.uid}&page=${i}`,
        { 'Cookie': cookie },
      )
      if (respObj.data.list.length === 0) break
      for (const item of respObj.data.list) if (item.visible.type === 0) {
        // Full text
        const respObjDetail = await getJson(
          `https://weibo.com/ajax/statuses/longtext?id=${item.mblogid}`,
          { 'Cookie': cookie },
        )
        const itemObj = {
          id: item.id,
          timestamp: new Date(item.created_at),
          text: respObjDetail.data.longTextContent || item.text_raw,
          pics: item.pic_ids || [],
        }
        if (itemObj.pics.length === 0) delete itemObj.pics
        else downloadPics(itemObj.pics)

        // Repost?
        if (item.retweeted_status) {
          const respObjRepostDetail = await getJson(
            `https://weibo.com/ajax/statuses/longtext?id=${item.retweeted_status.mblogid}`,
            { 'Cookie': cookie },
          )
          itemObj.repost = {
            id: item.retweeted_status.id,
            timestamp: new Date(item.retweeted_status.created_at),
            user: {
              id: item.retweeted_status.user ? item.retweeted_status.user.id : 0,
              name: item.retweeted_status.user ? item.retweeted_status.user.screen_name : '',
            },
            text: (respObjRepostDetail.data && respObjRepostDetail.data.longTextContent)
              || item.retweeted_status.text_raw,
            pics: item.retweeted_status.pic_ids || [],
          }
          if (itemObj.repost.pics.length === 0) delete itemObj.repost.pics
          else downloadPics(itemObj.repost.pics)
        }

        // Quick repost?
        if (item.user.id !== args.uid) {
          itemObj.repost = {
            id: itemObj.id,
            timestamp: itemObj.timestamp,
            user: {
              id: item.user.id,
              name: item.user.screen_name,
            },
            text: itemObj.text,
            pics: itemObj.pics,
          }
          itemObj.text = ''
          itemObj.pics = undefined
        }

        // Comments?
        if (item.comments_count > 0) {
          const respObjComments = await getJson(
            `https://weibo.com/ajax/statuses/buildComments?is_reload=1&id=${item.id}&is_show_bulletin=2&is_mix=0&count=20&type=feed`,
            { 'Cookie': cookie },
          )
          itemObj.comments = []
          const addComment = (itemComment) => {
            if (itemComment.user.id === args.uid) {
              itemObj.comments.push({
                id: itemComment.id,
                root_id: itemComment.rootid,
                timestamp: new Date(itemComment.created_at),
                text: itemComment.text_raw,
              })
            }
          }
          for (const itemComment of respObjComments.data) {
            addComment(itemComment)
            if (itemComment.comments)
              for (const itemCommentReply of itemComment.comments)
                addComment(itemCommentReply)
          }
          if (itemObj.comments.length === 0) delete itemObj.comments
        }

        yield itemObj
      }
    }
  },
  desc(item) {
    return `${item.timestamp.toISOString()} ${item.text.substring(0, 40).replace(/\n/g, ' ')}`
  },
  stop(item, existing) {
    return item.id <= existing[0].id // Short-circuit quickly
      && existing.filter((i) => i.id === item.id).length > 0
  },
}

const methods_mastodon = {
  async* get(args) {
    const account = await getJson(
      `${args.server}/api/v1/accounts/verify_credentials`,
      { 'Authorization': `Bearer ${args.token}` },
    )
    const uid = account.id
    let max_id = undefined
    while (true) {
      const list = await getJson(
        `${args.server}/api/v1/accounts/${uid}/statuses?limit=40&exclude_replies=true`
        + (max_id !== undefined ? `&max_id=${max_id}` : ''),
        { 'Authorization': `Bearer ${args.token}` },
      )
      if (list.length === 0) break
      for (const item of list) if (item.account.id === uid && args.acceptedVisibility.indexOf(item.visibility) !== -1) {
        let respObjDetail = await getJson(
          `${args.server}/api/v1/statuses/${item.id}`,
          { 'Authorization': `Bearer ${args.token}` },
        )
        if (respObjDetail.reblog) {
          if (respObjDetail.reblog.account.id !== uid) continue
          respObjDetail = respObjDetail.reblog
        }
        const itemObj = {
          id: item.id,
          timestamp: new Date(respObjDetail.created_at),
          spoiler_text: respObjDetail.spoiler_text !== '' ? respObjDetail.spoiler_text : undefined,
          content: respObjDetail.content,
        }

        // Media
        const processMediaList = async (media_attachments) => {
          const mediaFileList = []
          for (const m of media_attachments) {
            const fileName = await downloadFile(
              m.url,
              { 'Authorization': `Bearer ${args.token}` },
              args.mediaDir,
            )
            mediaFileList.push(fileName)
          }
          return mediaFileList.length === 0 ? undefined : mediaFileList
        }
        itemObj.media = await processMediaList(respObjDetail.media_attachments)

        // Replies (self only)
        itemObj.replies = []
        if (respObjDetail.replies_count > 0) {
          const respObjReplies = await getJson(
            `${args.server}/api/v1/statuses/${item.id}/context`,
            { 'Authorization': `Bearer ${args.token}` },
          )
          const addReplySubtree = async (postId) => {
            for (const reply of respObjReplies.descendants)
              if (reply.in_reply_to_id === postId && reply.account.id === uid) {
                const replyItem = {
                  id: reply.id,
                  timestamp: new Date(reply.created_at),
                  spoiler_text: reply.spoiler_text !== '' ? reply.spoiler_text : undefined,
                  content: reply.content,
                  media: await processMediaList(reply.media_attachments),
                }
                itemObj.replies.push(replyItem)
                await addReplySubtree(reply.id)
              }
          }
          await addReplySubtree(item.id)
        }
        if (itemObj.replies.length === 0) delete itemObj.replies

        yield itemObj
      }
      max_id = list[list.length - 1].id
    }
  },
  desc(item) {
    return `${item.timestamp.toISOString()} ${item.content.substring(0, 40)}`
  },
  stop(item, existing) {
    return item.id <= existing[0].id
  },
}

const run = async (methods, args, existing) => {
  const itr = methods.get(args)
  const newList = []
  for await (const item of itr) {
    if (existing.length > 0 && methods.stop(item, existing)) {
      break
    } else {
      if (methods.desc) console.log(methods.desc(item))
      newList.push(item)
    }
  }
  return newList.concat(existing)
}

const serviceCfg = Deno.args[0]
const serviceArgs = (await Deno.readTextFile(serviceCfg)).split('\n').filter((s) => s.length > 0)

const serviceName = serviceArgs[0]
const savePath = serviceArgs[1]
serviceArgs.splice(0, 2)
const existing = await (async () => {
  try {
    return JSON.parse(await Deno.readTextFile(savePath))
  } catch (e) {
    return []
  }
})()

let newList
if (serviceName === 'weibo') {
  newList = await run(methods_weibo, {
    picsDir: serviceArgs[0],
    uid: +serviceArgs[1],
    cookie: serviceArgs[2],
  }, existing)
} else if (serviceName === 'mastodon') {
  newList = await run(methods_mastodon, {
    mediaDir: serviceArgs[0],
    server: serviceArgs[1],
    acceptedVisibility: serviceArgs[2].split(',').map((s) => s.trim()),
    token: serviceArgs[3],
  }, existing)
} else {
  throw new Error(`Unknown service ${service}`)
}
await Deno.writeTextFile(savePath, '[\n' + newList.map((item) => JSON.stringify(item)).join(',\n') + '\n]\n')
