---
title: "Converting m4a to mp3"
date: 2024-03-12T07:52:00-04:00
draft: false
---
Install `ffmpeg`. Your mileage may vary, as every OS has a different way to install the package. However, it is universally available. You will also need libmp3lame, if you don't have have it. For me, I used `nix-shell`.

```
nix-shell -p ffmpeg
ffmpeg -i input.m4a -c:v copy -c:a libmp3lame -q:a 3 output.mp3
```

This is _copying_ the video, which is a NOP since there is no video, and converting the audio with libmp3lame.
The `-q:a 3` is a quality setting; the lower the number, the better the quality (three seems like a good value).
