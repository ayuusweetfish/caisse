import fontforge
import psMat

NotoEmojiSubset = sorted(set([
  # Seasons
  0x1f340, 0x1f338, 0x1f333, 0x2600, 0x1f33e, 0x1f343, 0x2744, 0x1f9ca,
  # Internationalization, 0x dark mode
  0x1f310, 0x1f319, 0x26aa,
  # Categories
  0x1fab8, 0x1fa87, 0x1fa81, 0x1fab6, 0x2618, 0x1fae7,
  # External link, 0x star
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

font.em = 2048
font.upos = NotoEmoji.upos
font.uwidth = NotoEmoji.uwidth
font.verticalBaseline = NotoEmoji.verticalBaseline

glyphs = [font.createChar(uni) for uni in NotoEmojiSubset]
font.selection.select(*glyphs)
font.paste()

glyph = font.createChar(0x1f5de)
glyph.importOutlines('feed.svg')
glyph.transform(psMat.scale(0.9))
glyph.transform(psMat.translate(0, font.descent * 0.3))
glyph.width = font.ascent + font.descent
font.generate('little-icons.ttf')
