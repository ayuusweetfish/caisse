import fontforge
import psMat
import math

NotoEmojiSubset = sorted(set([
  # Seasons
  0x1f340, 0x1f338, 0x1f333, 0x2600, 0x1f33e, 0x1f343, 0x2744, 0x1f9ca,
  # Internationalization, dark mode
  0x1f310, 0x1f319, 0x26aa,
  # Categories
  0x1fab8, 0x1fa87, 0x1fa81, 0x1fab6, 0x2618, 0x1fae7, 0x1fabb,
  # External link, star
  0x1fa90, 0x1f31f,
  # File types
  0x1f4e6, 0x1f3a7, 0x1f3b6, 0x1f3bc, 0x1f5bc, 0x1f39e, 0x1f4c3, 0x1f47e,
  # Music track
  0x1f58c, 0x1f3a4, 0x1f4bf,
  # Web ring
  0x1f578, 0x1f48d,
]))
NotoEmoji = fontforge.open('NotoEmoji-Regular.ttf')
NotoEmoji.selection.select(*NotoEmojiSubset)
NotoEmoji.copy()

font = fontforge.font()
font.fullname = 'Ayuu Little Icons'
font.familyname = font.fullname
font.fontname = font.fullname.replace(' ', '')
font.copyright = '(C) Contributors'
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
# Backyard icon
tr(0x1fabb, r(7), s(1.05))

# Web feed icon
glyph = font.createChar(0x1f5de)
glyph.importOutlines('feed.svg')
glyph.transform(psMat.scale(0.9))
w = font.ascent + font.descent
glyph.transform(psMat.translate(w * 0.05, font.descent * 0.3))
glyph.width = w

# Creative Commons icon
glyph = font.createChar(0xa9)
glyph.importOutlines('cc.svg')
xmin, ymin, xmax, ymax = glyph.boundingBox()
glyph.transform(psMat.translate(-xmin, -ymin))
glyph.transform(psMat.scale(2.8))
xmin, ymin, xmax, ymax = glyph.boundingBox()
glyph.transform(psMat.translate(
  (w * 3 - (xmax - xmin)) / 2,
  -font.descent * 0.6
))
glyph.width = w * 3

# Friend links icon (1f517 "link symbol" + 1f495 "two hearts")
glyph = font.createChar(0x1f517)
glyph.importOutlines('friend-link.svg')
glyph.transform(psMat.translate(0, -font.ascent))
glyph.transform(psMat.scale(1.5))
w = font.ascent + font.descent
glyph.transform(psMat.translate(0, font.ascent - font.descent))
glyph.width = int(w * 1.5)

# XXIIVV Webring
glyph = font.createChar(0x2b55)
glyph.importOutlines('xxiivv-webring.svg')
glyph.transform(psMat.translate(0, -font.ascent))
w = font.ascent + font.descent
glyph.transform(psMat.scale(w / 300 * 1.2))
glyph.transform(psMat.translate(-w * 0.1, font.ascent * 1.2))
glyph.width = w

# Left and right arrows
w = font.ascent + font.descent
glyph = font.createChar(0x2192)
glyph.importOutlines('arrowright.svg')
glyph.transform(psMat.translate(w * 0.1, 0))
glyph.width = w * 1.2

glyph = font.createChar(0x2190)
glyph.importOutlines('arrowright.svg')
glyph.transform(psMat.scale(-1, 1))
glyph.transform(psMat.translate(w * 1.1, 0))
glyph.width = w * 1.2

# Travellings icon
w = font.ascent + font.descent
glyph = font.createChar(0x1f687)
glyph.importOutlines('travellings.svg')
glyph.transform(psMat.translate(0, -font.ascent))
glyph.transform(psMat.scale(w / 40))
glyph.transform(psMat.translate(0, font.ascent))
glyph.transform(psMat.translate(0, -font.ascent / 2))
glyph.transform(psMat.scale(1.4))
glyph.transform(psMat.translate(0, font.ascent / 2 + font.ascent * 0.06))
glyph.transform(psMat.translate(w * 1.2 * (1.25 - 1.4) / 2, 0))
glyph.width = w * 1.2 * 1.25

font.generate('little-icons.ttf')
