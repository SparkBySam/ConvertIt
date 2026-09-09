# ConvertIt — EULA / Terms of Use clauses (third-party & LGPL)

Paste the sections below into your End User License Agreement or Terms of Use. Adjust the company name, jurisdiction, and URLs if needed.

**Important:** Do **not** include language that prohibits reverse engineering of ConvertIt as a whole if that would block users from exercising LGPL rights on the FFmpeg component. The sample below scopes restrictions appropriately.

---

## Section: License grant (ConvertIt application)

```
LICENSE GRANT. Subject to these Terms, Sam Parker ("Licensor") grants you a personal,
non-exclusive, non-transferable, revocable license to install and use ConvertIt
("Software") on macOS devices you own or control, for personal or internal business use.
```

---

## Section: Ownership (ConvertIt vs third-party)

```
OWNERSHIP. ConvertIt, including its user interface, original code, and branding, is
owned by Sam Parker and is protected by copyright and other intellectual property laws.
This license does not transfer ownership of ConvertIt to you.

THIRD-PARTY COMPONENTS. ConvertIt includes or interacts with third-party software that
is not owned by Licensor and is licensed under separate terms, including FFmpeg (see
"FFmpeg" below). Your use of those components is governed by their respective licenses.
Licensor does not claim copyright in FFmpeg or other third-party open-source components
included with or used by the Software.
```

---

## Section: FFmpeg (LGPLv2.1) — required

```
FFMPEG. ConvertIt uses libraries from the FFmpeg project. FFmpeg is copyright its
respective authors and is licensed under the GNU Lesser General Public License,
version 2.1 ("LGPLv2.1"). Licensor does not own FFmpeg.

ConvertIt invokes FFmpeg as a separate command-line program for certain media
conversions. The FFmpeg binary included with or used by ConvertIt is built without
the GPL-only configuration options (--enable-gpl) and without non-free options
(--enable-nonfree), as described in the corresponding source package.

Corresponding source code for the FFmpeg binary distributed with ConvertIt, including
build instructions and any modifications, is available at:

  https://convertitapp.com/legal/ffmpeg-source

The full text of the LGPLv2.1 is available at:

  https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

The FFmpeg project home page is:

  https://ffmpeg.org

If you receive ConvertIt only as object code, you may obtain the complete
corresponding source code for the FFmpeg component from the URL above, or by
contacting help@convertitapp.com. You may modify and redistribute FFmpeg under
the terms of the LGPLv2.1; ConvertIt's own code remains subject to this Agreement.
```

---

## Section: Other third-party services

```
THIRD-PARTY SERVICES. Currency conversion features may retrieve exchange rates from
the Frankfurter service (frankfurter.dev), which publishes European Central Bank
reference data. That service is operated by third parties and is not controlled by
Licensor. No account credentials or personal identifiers are required for rate lookup.
```

---

## Section: Reverse engineering (LGPL-safe wording)

**Use this instead of a blanket "no reverse engineering" clause.**

```
REVERSE ENGINEERING. Except where prohibited by applicable law, you may not reverse
engineer, decompile, or disassemble ConvertIt's proprietary application code except
to the extent such activity is expressly permitted by applicable law.

Nothing in this Agreement limits your rights under the LGPLv2.1 with respect to
FFmpeg, including the right to reverse engineer FFmpeg to the extent required to
debug modifications or to comply with the LGPL. For FFmpeg source code and license
terms, see the "FFmpeg" section above.
```

---

## Section: Disclaimer of warranties (standard — keep separate from FFmpeg)

```
DISCLAIMER. THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. LICENSOR
DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE. FFMPEG AND OTHER THIRD-PARTY COMPONENTS ARE PROVIDED UNDER
THEIR OWN LICENSES AND WITHOUT WARRANTIES FROM LICENSOR BEYOND WHAT THOSE LICENSES
REQUIRE.
```

---

## Short in-app / installer acknowledgment (optional checkbox text)

```
ConvertIt uses FFmpeg (ffmpeg.org) under the LGPLv2.1. Source code is available at
convertitapp.com/legal/ffmpeg-source. By installing ConvertIt, you agree to the
ConvertIt Terms of Use [link].
```

---

## Translation note

If you publish the EULA in other languages, translate all sections above consistently.
Do not reintroduce a blanket reverse-engineering prohibition in translated versions.

---

## Minimal EULA (if you want a single paragraph only)

For a very lightweight distribution, this minimum satisfies the FFmpeg checklist items
for EULA + ownership + reverse engineering. A full EULA is still recommended for a
commercial product.

```
ConvertIt is © Sam Parker. By using ConvertIt you agree not to redistribute the app
except as allowed by this notice. ConvertIt uses libraries from the FFmpeg project
under the GNU Lesser General Public License v2.1 (LGPLv2.1). Licensor does not own
FFmpeg. Source code for the FFmpeg binary included with ConvertIt is available at
https://convertitapp.com/legal/ffmpeg-source. FFmpeg is © its respective authors;
see https://ffmpeg.org. Nothing in this notice restricts your LGPL rights to modify
and redistribute FFmpeg. You may reverse engineer FFmpeg as permitted by the LGPLv2.1.
```

---

## Files to publish alongside the EULA

| URL | Content |
|-----|---------|
| `/legal` or `/terms` | Full EULA including sections above |
| `/legal/ffmpeg-source` | Source tarball + `ffmpeg-source-page.html` |
| `/download` | Download button + HTML notice from `WEBSITE-COPY.md` |
