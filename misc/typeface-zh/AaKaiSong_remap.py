# fontforge -lang=py -script AaKaiSong_remap.py
import fontforge
f = fontforge.open('AaKaiSong2WanZi2.ttf')

def copy(cp_from, cp_to):
  f.selection.select(cp_from)
  f.copy()
  f.selection.select(cp_to)
  f.paste()

copy(0x2022, 0xB7)    # Middle dot
copy(0x3007, 0x25EF)  # Circle

f.generate('AaKaiSong2WanZi2_remapped.ttf')
f.close()
