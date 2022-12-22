import fontforge
import psMat
import math

NotoEmojiSubset = sorted(set([
  # Seasons
  0x1f340, 0x1f338, 0x1f333, 0x2600, 0x1f33e, 0x1f343, 0x2744, 0x1f9ca,
  # Internationalization, dark mode
  0x1f310, 0x1f319, 0x26aa,
  # Categories
  0x1fab8, 0x1fa87, 0x1fa81, 0x1fab6, 0x2618, 0x1fae7,
  # External link, star
  0x1fa90, 0x1f31f,
  # File types
  0x1f4e6, 0x1f3a7, 0x1f3b6, 0x1f3bc, 0x1f5bc, 0x1f39e, 0x1f4c3, 0x1f47e,
  # Music track
  0x1f58c, 0x1f3a4, 0x1f4bf,
]))
NotoEmoji = fontforge.open('NotoEmoji-Regular.ttf')
NotoEmoji.selection.select(*NotoEmojiSubset)
NotoEmoji.copy()

font = fontforge.font()
font.fullname = 'Ayuu Little Icons'
font.familyname = font.fullname
font.fontname = font.fullname.replace(' ', '')
font.copyright = '(C) 2022 Ayu'
font.encoding = 'UnicodeFull'

font.em = 2048
font.upos = NotoEmoji.upos
font.uwidth = NotoEmoji.uwidth
font.verticalBaseline = NotoEmoji.verticalBaseline

# Paste glyphs
glyphs = [font.createChar(uni) for uni in NotoEmojiSubset]
font.selection.select(*glyphs)
font.paste()

# Transforms
def tr(uni, *mats):
  c = font.createChar(uni)
  w0 = c.width
  font.selection.select(c)
  font.transform(psMat.translate(-w0 / 2, -(font.ascent + font.descent) / 2))
  for mat in mats[::-1]: font.transform(mat)
  font.transform(psMat.translate(w0 / 2, (font.ascent + font.descent) / 2))
  dx = (w0 - c.width) / 2
  font.transform(psMat.translate(dx, 0))
  c.width = w0
def r(degs): return psMat.rotate(degs * math.pi / 180)
def s(scale): return psMat.scale(scale)
# Star
tr(0x1f31f, r(8))
# Seasons
tr(0x1f340, r(21))
tr(0x1f338, r(-10))
tr(0x1f333, r(0))
tr(0x2600, r(0))
tr(0x1f33e, r(15), s(0.99))
tr(0x1f343, r(25), s(1.02))
tr(0x2744, r(-8), s(0.97))
tr(0x1f9ca, r(-5))

glyph = font.createChar(0x1f5de)
glyph.importOutlines('feed.svg')
glyph.transform(psMat.scale(0.9))
w = font.ascent + font.descent
glyph.transform(psMat.translate(w * 0.05, font.descent * 0.3))
glyph.width = w

font.generate('little-icons.ttf')
