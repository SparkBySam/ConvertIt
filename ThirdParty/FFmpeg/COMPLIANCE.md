# FFmpeg LGPL distribution checklist (ConvertIt)

ConvertIt bundles an **FFmpeg command-line binary** (subprocess), not linked
libraries. Many FFmpeg checklist items still apply because you **redistribute**
the binary. Items marked **(app)** are implemented in code; **(you)** need to
complete before shipping.

## Build (developer)

- [ ] Run `./Scripts/build-ffmpeg-lgpl.sh` once per release (pins FFmpeg n7.1).
- [ ] Confirm `ffmpeg -version` shows **no** `--enable-gpl` or `--enable-nonfree`.
- [ ] Confirm H.264 conversions use `h264_videotoolbox`, not `libx264` **(app)**.
- [ ] Upload `ThirdParty/FFmpeg/dist/convertit-ffmpeg-<version>-src.tar.gz` to your
      download server **(you)**.

The build script writes:

| Artifact | Purpose |
|----------|---------|
| `Convert It/Resources/ffmpeg` | Binary bundled in the app |
| `Convert It/Resources/ffmpeg-build-info.txt` | Version + source URL in app bundle |
| `ThirdParty/FFmpeg/dist/*.tar.gz` | Source to host for users |
| `COMPILE.txt` inside source tree | Configure line for reproducibility |
| `changes.diff` | Patches (empty if unmodified) |

**Do not** use evermeet.cx or Homebrew GPL snapshots as the bundled binary.

## App / About box **(app)**

- [x] About panel states: *"This software uses libraries from the FFmpeg project under the LGPLv2.1."*
- [x] Link to FFmpeg source download URL.
- [x] Link to LGPLv2.1 text.
- [x] `FFmpeg-NOTICE.txt` in app bundle.

Update the source URL constant in `FFmpegCompliance.swift` if your hosting path
differs from `https://convertitapp.com/legal/ffmpeg-source`.

## Website **(you)**

Copy is ready in **`WEBSITE-COPY.md`** (download notice, footer, legal pages).
Publish **`ffmpeg-source-page.html`** and upload the source tarball to the same domain.

Minimum notice on every download page:

> This software uses code of [FFmpeg](https://ffmpeg.org) licensed under the
> [LGPLv2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html) and its
> source can be downloaded [here](https://convertitapp.com/legal/ffmpeg-source).

Spell **FFmpeg** correctly (two capitals F, lowercase mpeg).

Host source on the **same webserver** as the app binary.

## EULA **(you)**

Ready-to-paste clauses in **`EULA-CLAUSES.md`** (FFmpeg, ownership, reverse engineering).

## LGPL dependencies inside FFmpeg

If you keep the default build script (LAME, libvorbis, libopus, libvpx), offer
matching source for those libraries in the same tarball or linked archives.

## Quick verify before release

```bash
./Convert\ It/Resources/ffmpeg -version | grep configuration
# Must NOT contain: --enable-gpl --enable-nonfree --enable-libx264
```

```bash
strings ./Convert\ It/Resources/ffmpeg | grep -i libx264
# Should be empty or unused at runtime
```
