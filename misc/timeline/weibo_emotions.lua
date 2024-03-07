-- https://api.weibo.com/2/emotions.json
--[[
(() => {
  const s = window.emotions = {}
  setInterval(() => {
    for (const e of document.querySelectorAll('img[src^="https://face.t.sinajs.cn"]'))
      s[e.title.substring(1, e.title.length - 1)] = e.src
    console.log(Object.entries(s).length)
  }, 200)
})()

console.log(Object.entries(window.emotions).map(([k, v]) => `['${k}'] = '${v}',`).sort().join('\n'))
]]

local list = {
['2023'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/f0/2022_2023_org.png',
['666'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/6c/2022_666_org.png',
['二哈'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/22/2018new_erha_org.png',
['兔子'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/c6/2018new_tuzi_org.png',
['单身狗'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/20/2021_alongdog_org.png',
['可怜'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/96/2018new_kelian_org.png',
['吃瓜'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/01/2018new_chigua_org.png',
['哇'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/3d/2022_wow_org.png',
['哼'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/7c/2018new_heng_org.png',
['团圆兔'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/ca/2023_intimaterabbit_org.png',
['委屈'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/a5/2018new_weiqu_org.png',
['害羞'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/c1/2018new_haixiu_org.png',
['开学季'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/72/2021_kaixueji_org.png',
['彩虹屁'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/4b/2022_praise_org.png',
['思考'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/30/2018new_sikao_org.png',
['悲伤'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/ee/2018new_beishang_org.png',
['憧憬'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/c9/2018new_chongjing_org.png',
['打call'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/39/moren_dacall02_org.png',
['抱一抱'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/af/2020_hug_org.png',
['握手'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/e9/2018new_woshou_org.png',
['泪'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/6e/2018new_leimu_org.png',
['爱你'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/f6/2018new_aini_org.png',
['玉兔捣药'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/52/2022_rabbitmash_org.png',
['白眼'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/ef/2018new_landelini_org.png',
['睡'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/e2/2018new_shuijiao_thumb.png',
['老师好'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/0d/2022_Teacher_org.png',
['苦涩'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/7e/2021_bitter_org.png',
['虎爪比心'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/2b/2022_handheart_org.png',
['裂开'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/1b/202011_liekai_org.png',
['许愿星'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/a8/2022_WishingStar_org.png',
['赢牛奶'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/9c/2021_yingniunai_org.png',
['跪了'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/75/2018new_gui_org.png',
['送花花'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/cb/2022_Flowers_org.png',
['锦鲤附体'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/e3/2022_cometrue_org.png',
['鞭炮声声'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/7f/2023_firecrackers_org.png',
['抓狂'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/17/2018new_zhuakuang_org.png',
['浮云'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/61/2018new_yunduo_org.png',
['馋嘴'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/fa/2018new_chanzui_org.png',
['并不简单'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/aa/2018new_bingbujiandan_org.png',
['失望'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/aa/2018new_shiwang_org.png',
['生病'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/3b/2018new_shengbing_org.png',
['疑问'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/b8/2018new_ningwen_org.png',
['看书'] = 'https://face.t.sinajs.cn/t4/appstyle/expression/ext/normal/83/2023_read_org.png',
}

local download = select(1, ...) == 'download'
local savepath = 'weibo_emotions'
if download then os.execute('mkdir -p ' .. savepath) end

for k, url in pairs(list) do
  local basename = url:match('[^/]+$')
  if download then
    os.execute(string.format('curl %s -o %s/%s', url, savepath, basename))
  end
  list[k] = basename
end

return list
