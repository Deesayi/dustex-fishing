# DUSTEX Creator Studio

A guitar tab builder (full-page layout: staff, LED meters, fretboard and mixer all on one screen) that runs as an installable app in Microsoft Edge or Google Chrome.

**Open it:** https://deesayi.github.io/dustex-fishing/tab/

**Install guide (PDF, step by step):** https://deesayi.github.io/dustex-fishing/tab/DUSTEX-Tab-Install-Guide.pdf

To install it, open the link in Edge or Chrome and click the **Install** icon at the right end of the address bar. It then opens from the Start menu like any program, works offline, and updates itself.

Features:
- Write tab by clicking the fretboard, or by playing your guitar (single notes, or chords and notes).
- Playback, a looper with count-in and overdub, rock and blues drum beats, and a click.
- A mixer with room reverb, plate, tempo delay and tape echo, and an LED meter bridge for every channel.
- Save, print or make a PDF of your tabs.

## iPad link (control the PC studio from an iPad)

The desktop widget (`desktop/TabWidget.ps1`) includes a small web server for your home network. The iPad shows the running
studio live and your touches play it, while the sound, the guitar input and the listening all stay on the PC.

1. On the PC, run `desktop/Set up iPad Link.cmd` once (it allows port 8790 on private networks only).
2. On the iPad, open Safari at `http://<pc-name>.local:8790` (right-click the widget > **iPad link...** shows the address)
   and type the 6-digit code once. Share > **Add to Home Screen** keeps it as an app.

The PC widget stays in its dock (or full screen) and the iPad mirrors it. One finger works like the mouse (tap, drag knobs and faders, double-tap), two fingers pinch to zoom and move the picture, ⤢ fits it again, and the keyboard button types.
`remote.html` is the iPad page; it is served by the PC, not by this site.

Chord and note detection uses Spotify's open-source Basic Pitch model (Apache-2.0 licence, see `vendor/LICENSE-basic-pitch.txt`).

The "Creator Studio" lettering uses the Great Vibes font (SIL Open Font License, see `fonts/LICENSE-great-vibes.txt`).
