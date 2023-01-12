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
  stop: (item, existing) => {
    return item.my_id <= existing[0].my_id
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

const savePath = Deno.args[0]
const existing = await (async () => {
  try {
    return JSON.parse(await Deno.readTextFile(savePath))
  } catch (e) {
    return []
  }
})()

const newList = await run(methods_test, {N: 25}, existing)
await Deno.writeTextFile(savePath, JSON.stringify(newList))
