# ConvertIt — website copy (FFmpeg / third-party)

Use this on **every page where users can download ConvertIt** (homepage, download page, release notes). Host the source archive on the **same domain** as the app download.

**URLs used below** (update if yours differ):

| Item | URL |
|------|-----|
| App download | https://convertitapp.com/download |
| FFmpeg source page | https://convertitapp.com/legal/ffmpeg-source |
| Full legal / licenses | https://convertitapp.com/legal |
| Support | help@convertitapp.com |

---

## 1. Download-page notice (required — paste near download button)

**Plain text**

```
This software uses code of FFmpeg (https://ffmpeg.org) licensed under the LGPLv2.1
(https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html). Corresponding source code
is available at https://convertitapp.com/legal/ffmpeg-source
```

**HTML**

```html
<p class="third-party-notice">
  This software uses code of
  <a href="https://ffmpeg.org" rel="noopener">FFmpeg</a>
  licensed under the
  <a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html" rel="noopener">LGPLv2.1</a>
  and its source can be downloaded
  <a href="https://convertitapp.com/legal/ffmpeg-source">here</a>.
</p>
```

**Markdown** (GitHub releases, README)

```markdown
This software uses code of [FFmpeg](https://ffmpeg.org) licensed under the [LGPLv2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html) and its source can be downloaded [here](https://convertitapp.com/legal/ffmpeg-source).
```

---

## 2. Site footer (optional but recommended)

```html
<p>
  ConvertIt uses
  <a href="https://ffmpeg.org">FFmpeg</a>
  under the
  <a href="https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html">LGPLv2.1</a>.
  <a href="https://convertitapp.com/legal/ffmpeg-source">Source code</a>
  ·
  <a href="https://convertitapp.com/legal">Legal</a>
</p>
```

---

## 3. Full page: `/legal/ffmpeg-source`

Host the tarball produced by `./Scripts/build-ffmpeg-lgpl.sh` at this path, e.g.:

`https://convertitapp.com/legal/ffmpeg-source/convertit-ffmpeg-7.1-src.tar.gz`

A ready-to-publish HTML template is in `ffmpeg-source-page.html` in this folder.

**Page body copy (Markdown / CMS)**

---

# FFmpeg source code (ConvertIt)

ConvertIt includes a command-line **FFmpeg** binary for certain video and audio conversions. ConvertIt does not link FFmpeg into the application; it runs FFmpeg as a separate process.

The FFmpeg code is licensed under the **GNU Lesser General Public License (LGPL) version 2.1**. ConvertIt’s bundled FFmpeg build is compiled **without** `--enable-gpl` and **without** `--enable-nonfree`.

## Download corresponding source

| File | Description |
|------|-------------|
| [convertit-ffmpeg-7.1-src.tar.gz](convertit-ffmpeg-7.1-src.tar.gz) | FFmpeg n7.1 source tree, `COMPILE.txt` (configure line), and `changes.diff` |

Replace the version in the filename when you ship a new FFmpeg pin.

## Build instructions

The archive includes `COMPILE.txt` with the exact `./configure` line used for the binary inside ConvertIt. To reproduce the build on macOS:

1. Install dependencies: `brew install nasm pkg-config lame libvorbis libopus libvpx`
2. Extract the tarball and follow `COMPILE.txt`, or run `./Scripts/build-ffmpeg-lgpl.sh` from the ConvertIt source repository.

## FFmpeg project

- Project: https://ffmpeg.org  
- License text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html  

## Other libraries in the bundled FFmpeg build

The default ConvertIt FFmpeg build may include these libraries (each under its own license; source is included in or linked from the tarball where applicable):

| Library | Use | Project |
|---------|-----|---------|
| LAME | MP3 encoding | https://lame.sourceforge.io/ |
| libvpx | WebM / VP9 | https://www.webmproject.org/ |
| libvorbis | Ogg Vorbis | https://xiph.org/vorbis/ |
| libopus | Opus audio | https://opus-codec.org/ |

Apple **VideoToolbox** and **AudioToolbox** are used via FFmpeg for H.264/AAC on macOS (system frameworks, not redistributed).

## Questions

Contact [help@convertitapp.com](mailto:help@convertitapp.com).

---

## 4. Full page: `/legal` (licenses overview)

Short section you can add to a general Legal / Licenses page:

---

### Third-party software

**FFmpeg.** ConvertIt uses libraries from the [FFmpeg](https://ffmpeg.org) project under the [LGPLv2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html). Source code corresponding to the bundled FFmpeg binary is available at [convertitapp.com/legal/ffmpeg-source](https://convertitapp.com/legal/ffmpeg-source).

**Exchange rates.** Currency conversion uses the [Frankfurter](https://frankfurter.dev) public API (European Central Bank reference rates). No account or personal data is sent.

**Apple frameworks.** ConvertIt uses Apple system frameworks (e.g. AVFoundation, VideoToolbox) under macOS’s standard terms.

---

## 5. Release notes snippet

```markdown
### Third-party licenses

This release includes FFmpeg under the LGPLv2.1. Source: https://convertitapp.com/legal/ffmpeg-source
```

---

## Checklist before going live

- [ ] Tarball uploaded and link works (same domain as `.dmg` / `.zip`)
- [ ] Notice visible on download page without scrolling past the fold (ideal)
- [ ] Spelling is **FFmpeg** (not FFMpeg, ffmpeg-only in URLs)
- [ ] Version in filename matches `ffmpeg-build-info.txt` in the shipped app
