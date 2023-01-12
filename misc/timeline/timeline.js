const methods_test = {
  get: async function* (args) {
    const N = args.N
    for (let i = 0; i < N; i++) {
      yield {
        my_id: N - i,
        text: `text ${N - i}`,
      }
    }
  },
  desc: (item) => item.text,
  stop: (item, first) => item.my_id <= first.my_id,
}

const getJson = async (url, cookie) => {
  for (let i = 0; i < 5; i++) {
    try {
      const text = await (await fetch(
        url,
        { headers: { 'Cookie': cookie } },
      )).text()
      return JSON.parse(text)
    } catch (e) {
      console.log(`Retrying ${url}`)
    }
  }
  throw new Error(`Cannot fetch JSON from ${url}`)
}

const downloadWeiboPics = async (ids, cookie) => {
  for (const [i, id] of Object.entries(ids)) {
    const resp = (await fetch(
      `https://weibo.com/ajax/common/download?pid=${id}`,
      { headers: { 'Cookie': cookie } },
    ))
    try {
      await Deno.mkdir('weibo_pics')
    } catch (e) {
      if (!(e instanceof Deno.errors.AlreadyExists)) throw e
    }
    const fileName = resp.headers.get('Content-Disposition').match(/filename=(.+)/)[1]
    const f = await Deno.open(`weibo_pics/${fileName}`, {create: true, write: true})
    await resp.body.pipeTo(f.writable)
    ids[i] = fileName
  }
}

const methods_weibo = {
  async* get(args) {
    const cookie = (await Deno.readTextFile('cookie.txt')).trim()
    for (let i = 1; ; i++) {
      console.log(`==== page ${i} ====`)
      const respObj = await getJson(
        `https://weibo.com/ajax/statuses/mymblog?uid=${args.uid}&page=${i}`,
        cookie,
      )
      if (respObj.data.list.length === 0) break
      for (const item of respObj.data.list) if (item.visible.type === 0) {
        // Full text
        const respObjDetail = await getJson(
          `https://weibo.com/ajax/statuses/longtext?id=${item.mblogid}`,
          cookie,
        )
        const itemObj = {
          id: item.id,
          created_at: new Date(item.created_at),
          text: respObjDetail.data.longTextContent || item.text_raw,
          pic_ids: item.pic_ids || [],
        }
        if (itemObj.pic_ids.length === 0) delete itemObj.pic_ids
        else downloadWeiboPics(itemObj.pic_ids, cookie)

        // Repost?
        if (item.retweeted_status) {
          const respObjRepostDetail = await getJson(
            `https://weibo.com/ajax/statuses/longtext?id=${item.retweeted_status.mblogid}`,
            cookie,
          )
          itemObj.repost = {
            id: item.retweeted_status.id,
            created_at: new Date(item.retweeted_status.created_at),
            user: {
              id: item.retweeted_status.user ? item.retweeted_status.user.id : 0,
              name: item.retweeted_status.user ? item.retweeted_status.user.screen_name : '',
            },
            text: (respObjRepostDetail.data && respObjRepostDetail.data.longTextContent)
              || item.retweeted_status.text_raw,
            pic_ids: item.retweeted_status.pic_ids || [],
          }
          if (itemObj.repost.pic_ids.length === 0) delete itemObj.repost.pic_ids
          else downloadWeiboPics(itemObj.repost.pic_ids, cookie)
        }

        // Quick repost?
        if (item.user.id !== args.uid) {
          itemObj.repost = {
            id: itemObj.id,
            created_at: itemObj.created_at,
            user: {
              id: item.user.id,
              name: item.user.screen_name,
            },
            text: itemObj.text,
            pic_ids: itemObj.pic_ids,
          }
          itemObj.text = ''
          itemObj.pic_ids = undefined
        }

        // Comments?
        if (item.comments_count > 0) {
          const respObjComments = await getJson(
            `https://weibo.com/ajax/statuses/buildComments?is_reload=1&id=${item.id}&is_show_bulletin=2&is_mix=0&count=20&type=feed`,
            cookie,
          )
          itemObj.comments = []
          const addComment = (itemComment) => {
            if (itemComment.user.id === args.uid) {
              itemObj.comments.push({
                id: itemComment.id,
                root_id: itemComment.rootid,
                created_at: new Date(itemComment.created_at),
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
    return `${item.created_at} ${item.text.substring(0, 40).replace(/\n/g, ' ')}`
  },
  stop(item, first) {
    return item.id < first.id
  },
}

const run = async (methods, args, existing) => {
  const itr = methods.get(args)
  const newList = []
  for await (const item of itr) {
    if (existing.length > 0 && methods.stop(item, existing[0])) {
      break
    } else {
      if (methods.desc) console.log(methods.desc(item))
      newList.push(item)
    }
  }
  return newList.concat(existing)
}

const savePath = Deno.args[0]
const existing = await (async () => {
  try {
    return JSON.parse(await Deno.readTextFile(savePath))
  } catch (e) {
    return []
  }
})()

const newList = await run(methods_weibo, {uid: +Deno.env.get('uid')}, existing)
await Deno.writeTextFile(savePath, JSON.stringify(newList))
