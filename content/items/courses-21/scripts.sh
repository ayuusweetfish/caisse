~/Downloads/ffmpeg-5.0.1 -i ~/Downloads/*-sd/*/*/*1222\ SD\ love\ theme.mov -c:a copy -vf "scale=iw/2:ih/2" Sound_Design_Love.mp4
# https://superuser.com/questions/851977/ffmpeg-merging-mp3-mp4-no-sound-with-copy-codec
~/Downloads/ffmpeg-5.0.1 -i ~/Downloads/*-sd/*/*/*/*声音设计与研创1013.mp3 -i ~/Downloads/RPReplay_Final1632913657\ 2.mov -vf "scale=iw/2:ih/2" -af "afade=out:st=59.75:d=4" -crf 28 -to 63.75 Sound_Design_Travel.mp4
~/Downloads/ffmpeg-5.0.1 -i ~/Downloads/*-sd/*/*/SD\ Theme\ 3\ 1228.mov -vf "scale=iw/2:ih/2" -c:a copy -crf 28 Sound_Design_Spy.mp4
~/Downloads/ffmpeg-5.0.1 -i ~/Downloads/Iron_Man/Iron_Man_0508*.mp4 -vf "scale=iw/2:266" -c:a copy -crf 28 Iron_Man.mp4
