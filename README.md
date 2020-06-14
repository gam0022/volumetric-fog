# webgl volumetric fog (UE76)

A WebGL 64KB Intro for [#S1C002](https://neort.io/tag/bqr6ous3p9f48fkis91g), [#Shader1weekCompo](https://neort.io/tag/br0go2s3p9f194rkgmj0)

Imspired by [Ray Marching Fog With Blue Noise](https://blog.demofox.org/2020/05/10/ray-marching-fog-with-blue-noise/) by @Atrix256

![volumetric-fog.jpg](volumetric-fog.jpg)

## Run

Run in browser on your PC! (only tested latest Chrome)

- [NEORT version](https://neort.io/art/br0go2k3p9f194rkgmgg)

## Links

- [:bird: Twitter](https://twitter.com/gam0022/status/1261967964955279360/)

## Development

### 0: Required

- [node.js v12.14.1](https://nodejs.org/ja/) or higher
- [ruby 2.x](https://www.ruby-lang.org/ja/downloads/) or higher

### 1: Get Started

```sh
git clone git@github.com:gam0022/volumetric-fog.git
cd volumetric-fog

# init
npm install

# Start Web server with hot-reload / UI for debug
npm run start

# Generate a dist\volumetric-fog.html
npm run build
```

## Chromatiq

A WebGL engine developed for PC 64K Intro aimed at minimizing the file size.

Originally made it for [resimulated](https://github.com/gam0022/resimulated).

Written in a single TypeScript, but it's still in development. ([source code](https://github.com/gam0022/resimulated/blob/master/src/chromatiq.ts))

### Features

It has only simple functions so that it does not depend on the work.

- Rendering multi-pass image shaders (as viewport square)
- Build-in bloom post-effect
- Interface to animate uniforms from a TypeScript
- GLSL Sound (Shadertoy compatible)
- Play an Audio file (mp3 / ogg)

### How to Capture Movie

1. `npm run start`
2. misc/saveImageSequence
3. misc/saveSound
4. `ffmpeg.exe -r 60 -i chromatiq%04d.png -i chromatiq.wav -c:v libx264 -preset slow -profile:v high -coder 1 -pix_fmt yuv420p -movflags +faststart -g 30 -bf 2 -c:a aac -b:a 384k -profile:a aac_low -b:v 68M chromatiq_68M.mp4`

#### Links

- [アップロードする動画におすすめのエンコード設定](https://support.google.com/youtube/answer/1722171?hl=ja)
    - 映像ビットレート 2160p（4k）53～68 Mbps
- [YouTube recommended encoding settings on ffmpeg (+ libx264)](https://gist.github.com/mikoim/27e4e0dc64e384adbcb91ff10a2d3678)
- [超有益情報 by sasaki_0222](https://twitter.com/sasaki_0222/status/1248910333835530241)

## Thanks

- [FMS-Cat/until](https://github.com/FMS-Cat/until)
- [gasman/pnginator.rb](https://gist.github.com/gasman/2560551)
- [VEDA 2.4: GLSLで音楽を演奏できるようになったぞ！！！ - マルシテイア by amagitakayosi](https://blog.amagi.dev/entry/veda-sound)
- [[webgl2]example for webgl2 (with glsl3) by bellbind](https://gist.github.com/bellbind/8c98bb86cfd064d944312b09b98af1b9)
- [How to Convert an AudioBuffer to an Audio File with JavaScript by Russell Good](https://www.russellgood.com/how-to-convert-audiobuffer-to-audio-file/)
- [wgld.org by h_doxas](https://wgld.org/)

## License

[MIT](LICENSE)
