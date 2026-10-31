# MD3Music: three selectable visual systems

This branch integrates three UI styles into the original Flutter source tree:
Material 3, Material 3 Expressive, and MIUIX with translucent/glass surfaces.
It is a real fork of `zzyoxml/md3Music` (branch `rust-local-force`), not a patch-only archive.

## Implemented
- Persistent visual style selection under **Settings → Theme & colors**.
- Shared visual tokens consumed by UI components without altering playback state.
- Theming across global buttons, cards, form fields, dialogs, sheets, chips,
  navigation and input controls.
- Layout improvements for the four-method login screen.
- Styling for search, collections, discovery, FM, library, profile, queue,
  navigation indicators, transport buttons and segmented controls.
- Existing dynamic colors, light/dark, user font, remote focus,
  song ownership and audio/QR authentication are retained.
- The MIUIX option uses the community-maintained `flutter_miuix` package.
  `MiuixSquircleBorder` is used for smooth corners and a real Gaussian
  backdrop blur is used in selected static panels. This is not a complete
  reimplementation of the proprietary HyperOS renderer.

## Validation
One workflow is permitted per review cycle. The new
`.github/workflows/three-style-validation.yml` runs on the first push to
`ui/three-style-overhaul`, or via deliberate manual dispatch. It installs
Flutter + Android SDK, formats a temporary checkout, analyzes and tests
Dart sources, then attempts one Android debug build. The workflow does
not edit the branch or auto-retry failures. **If it fails, request approval
before triggering it again.**

The original `rust-local-force` branch is unchanged. No release tag is
created and no production APK is published automatically.

## Next direction
After the single CI result, resolve reported compiler/test issues locally
before requesting permission to run CI a second time; then evaluate M3E and
MIUIX rendering on physical Android hardware, including 120 Hz and reduced
motion, and tune contrast and touch targets.
