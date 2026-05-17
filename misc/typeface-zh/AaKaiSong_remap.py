# fontforge -lang=py -script AaKaiSong_remap.py
import fontforge
import psMat

f = fontforge.open('AaKaiSong2WanZi2.ttf')

def copy(cp_from, cp_to):
  f.selection.select(cp_from)
  f.copy()
  f.selection.select(cp_to)
  f.paste()

copy(0x2022, 0xB7)    # Middle dot
copy(0x3007, 0x25EF)  # Circle

f[0xff0f].transform(psMat.compose(psMat.skew(0.25), psMat.translate(-100, 0)))

def copy_across(f_from, cp_from, f_to, cp_to=None, tfm=None, scale=1, weight=0):
  cp_to = cp_to or cp_from
  f_from.selection.select(cp_from)
  f_from.copy()
  f_to.selection.select(cp_to)
  f_to.paste()
  w = f_to[cp_to].width
  if tfm is not None: f_to[cp_to].transform(tfm)
  if weight != 0: f_to.changeWeight(weight)
  f_to[cp_to].width = round(w * scale)

copy_across(f, 0xFF08, f, tfm=psMat.translate(0, 60))   # （
copy_across(f, 0xFF09, f, tfm=psMat.translate(0, 60))   # ）
copy_across(f, 0xFF3B, f, tfm=psMat.translate(0, 60))   # ［
copy_across(f, 0xFF3D, f, tfm=psMat.translate(0, 60))   # ］

# ba0a4e8d1ca0b02e9b506c04254ff8ca7d53330d  /usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf
# pyftsubset /usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf --unicodes=266d-266f --output-file=DejaVuSans.ttf
f1 = fontforge.open('DejaVuSans.ttf')
# Flat, natural, sharp
copy_across(f1, 0x266D, f, tfm=psMat.scale(0.5), scale=0.5, weight=8)
copy_across(f1, 0x266E, f, tfm=psMat.compose(psMat.compose(psMat.scale(0.5), (1, -0.1, 0, 1, 0, 0)), psMat.translate(0, 12)), scale=0.5, weight=8)
copy_across(f1, 0x266F, f, tfm=psMat.compose(psMat.compose(psMat.scale(0.5), (1, -0.2, 0, 1, 0, 0)), psMat.translate(0, 32)), scale=0.5, weight=8)

# 822a13649cfa7475343d52bfb2db9f0358a36822  /usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf
# pyftsubset /usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf --unicodes=2669-266a --output-file=LiberationSans.ttf
f2 = fontforge.open('LiberationSans.ttf')
# Crotchet, quaver
copy_across(f2, 0x2669, f, tfm=psMat.compose(psMat.scale(0.75), psMat.translate(0, -75)), scale=0.75/2, weight=-10)
copy_across(f2, 0x266A, f, tfm=psMat.compose(psMat.scale(0.75), psMat.translate(0, -75)), scale=0.75, weight=-10)

f.generate('/tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.ttf', flags=('no-FFTM-table'))
f.close()

# To temporarily use the remapped font:
# cp /tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.ttf ../../build/bin/AaKaiSong2WanZi2_remapped.ttf
# In the target page HTML:
# src: url(/bin/AaKaiSong2WanZi2_remapped.ttf);

# To build full WOFF2:
# woff2_compress /tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.ttf && mv /tmp/caisse-typeface-zh-AaKaiSong2WanZi2_remapped.woff2 ../../content/fonts-zh/AaKaiSong2-full.woff2
