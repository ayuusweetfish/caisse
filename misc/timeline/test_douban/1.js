import { DOMParser } from 'https://deno.land/x/deno_dom@v0.1.36-alpha/deno-dom-wasm.ts'

const doc = new DOMParser().parseFromString(await Deno.readTextFile('douban1.html'), 'text/html')
const els = doc.querySelectorAll('.stream-items > .new-status')
console.log(els.length)

const recurseMod = (el) => {
  if (!el.classList) return

  // Prefix classes
  const modClassList = []
  for (const kl of el.classList) modClassList.push('douban--' + kl)
  el.setAttribute('class', modClassList.join(' '))

  // Remove unused attributes
  const attrsToRemove = []
  for (const { name } of el.attributes)
    if (name.startsWith('on') || name.startsWith('data-'))
      attrsToRemove.push(name)
  for (const attr of attrsToRemove) el.removeAttribute(attr)

  // Recurse
  for (const ch of el.childNodes) {
    recurseMod(ch)
    if (el.tagName === 'STYLE') el.remove()
  }
}

const imagesToDownload = []

for (const wrapper of els) {
  const sid = +wrapper.getAttribute('data-sid')
  recurseMod(wrapper)

  let html = wrapper.outerHTML
  html = html.replace(/https?:\/\/img(.+)\.doubanio\.com([A-Za-z0-9-_%\/.@]+)/g,
    (s) => {
      let hash1 = 0, hash2 = 0
      const hashStr =
        hash1.toString(16).padStart(8, '0') +
        hash2.toString(16).padStart(8, '0')
      imagesToDownload.push([s, hashStr])
      const ext = s.match(/\.([^.]+)$/)[1]
      return `/img-douban/${hashStr}.${ext}`
    })

  console.log(html)

/*
  const isReshared = !!wrapper.querySelector('.reshared_by')
  const elItem = wrapper.querySelector('.status-item')
  const sid = +elItem.getAttribute('data-sid')

  const kind = +elItem.getAttribute('data-object-kind')
  const action = +elItem.getAttribute('data-action')
  const target = elItem.getAttribute('data-target-type')

  kind, (target/action)
  * = 推测，未确认
  1000
    (sns/5) 关注成员
  1001
    (book/1) 想读
    (book/2) 在读
    (doulist/0) 收藏图书到豆列 *
    (doulist/1) 收藏图书到书单
  1002
    (movie/1) 在看
    (movie/2) 想看
    (movie/3) 看过
    (doulist/0) 收藏电影到豆列
    (doulist/1) 收藏电影到片单
  1003
    (music/1) 在听
    (music/2) 想听
    (music/3) 听过 *
  1012
    (doulist/0) 收藏评论到豆列
  1013
    (rec/0) 分享小组讨论
    (doulist/0) 收藏小组讨论到豆列
  1015
    (rec/0) 转发日记
  1018
    (/0) 转发
    (sns/1) 说（纯文字）
    (sns/2) 说（有图片）
  1019
    (sns/8) 加入小组
    (sns/9) 加入Club
  1020
    (sns/1) 关注豆列
    (sns/2) 关注片单
  1022
    (rec/0) 分享网页
  2554
    (sns/0) 关注榜单
  3118
    (subscribed_gallery_topic/1) 关注话题
  5xxx 来自豆瓣阅读
  NOTE: 对于直接转发的内容，会显示为 .reshared_by + 原内容。
    因此 1018 & action = 0 出现于两种情况：
     - 转发他人的转发；
     - 转发时加入了自己的文字内容。
    另外，转发的小组讨论包含 data-atype = "group/topic" 等额外参数，但并不含 data-object-kind 等。
*/
}
