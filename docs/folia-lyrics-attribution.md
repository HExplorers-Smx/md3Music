# Folia-inspired native lyric stages

The implementation in `lib/modules/player/stage_lyrics_view.dart` is
a native Flutter adaptation, not a bundled copy of Folia's React,
Canvas, PixiJS or Electron renderer. It does not claim pixel-perfect parity.

## Implemented and exposed in MD3 lyric settings

- Original scrolling lyrics: unchanged default
- 流光: source-timed word highlights, soft glow, upcoming line
- 云阶: offset multi-row text layout, source-timed highlights

These are independent of Material 3, Material 3 Expressive and
MIUIX appearance themes. Only implemented choices appear in UI.
Untimed lyrics are grouped visually without inventing word timestamps.

## Credit, origin and license

Inspiration: Folia / Folia-major by chthollyphile and contributors.
https://github.com/chthollyphile/folia-major
Upstream license: GNU Affero General Public License v3 (AGPL-3.0).

Mobile implementation references:
https://github.com/maimai993/folia-sonnet
https://github.com/whycfawa/folia-android

Those Android implementations primarily run the Web-based renderer
inside a native container. This module instead uses native Flutter
rendering driven by md3Music's existing lyric and audio timeline.

md3Music is distributed under GNU AGPL v3; the repository's original
LICENSE is retained. No proprietary exception or additional
restriction is imposed. Media, lyrics and artwork have separate
rightsholders.

## Validation
This change was authored and source-reviewed without starting Actions.
The maintainer requires explicit permission before running another
Android CI job after the earlier failure on this branch.
