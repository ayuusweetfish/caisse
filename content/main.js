(() => {
const langContainer = document.getElementById('lang-container')
const langList = document.getElementById('lang-list')
const tempEvents = [
  [document.body, 'mousedown', (e) => closeLangContainer(e)],
  [document.body, 'keydown', (e) => { if (e.keyCode === 27) closeLangContainer(e) }],
  [langContainer, 'mousedown', (e) => e.stopPropagation()],
]
const clearTempEvents = () => {
  for (const [el, key, fn] of tempEvents)
    el.removeEventListener(key, fn)
}
const closeLangContainer = (e) => {
  langContainer.open = false
  clearTempEvents()
  e.preventDefault()
}
langContainer.addEventListener('toggle', (e) => {
  if (langContainer.open) {
    for (const [el, key, fn] of tempEvents)
      el.addEventListener(key, fn)
  } else {
    clearTempEvents()
  }
})

const darkToggle = document.getElementById('dark-toggle')
darkToggle.addEventListener('click', (e) => {
  const isDark = !document.body.classList.contains('dark')
  document.body.classList.toggle('dark')
  document.cookie = 'dark=' + (isDark ? '1' : '0') + '; SameSite=Strict; Max-Age=2592000'
  darkToggle.href = darkToggle.href.substring(0, darkToggle.href.length - 1) + (isDark ? '0' : '1')
  e.preventDefault()
})

if (navigator.userAgent.indexOf('Chrome/') !== -1)
  document.body.classList.add('ua-inline-height')

const navList = document.querySelector('nav > ul')
const navListFirst = navList.children[0]
const navListLast = navList.children[navList.children.length - 1]
const ixobs = new IntersectionObserver((entries) => {
  entries.forEach((ent) => {
    const isFirst = (ent.target === navListFirst)
    const isVisible = (ent.intersectionRatio >= 0.6)
    if (isVisible)
      navList.classList.remove(isFirst ? 'scroll-shadow-start' : 'scroll-shadow-end')
    else
      navList.classList.add(isFirst ? 'scroll-shadow-start' : 'scroll-shadow-end')
  })
}, {
  root: navList,
  rootMargin: '0px',
  threshold: [0.6],
})
ixobs.observe(navListFirst)
ixobs.observe(navListLast)

document.body.classList.add('js')
})()
