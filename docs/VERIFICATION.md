# Verification

## v0.2.1

Verified locally on 2026-10-27 (Asia/Seoul):

- All 18 XCTest cases passed (seven recovery, five localization, six core).
- Release build, ad-hoc signature verification, and DMG verification passed.
- Read-only hardware probe on LG HDR 4K returned volume 10/100 and brightness
  100/100. No hardware values were changed during this verification.

- Added seven simulated-device regression tests covering failed readback without
  losing keyboard/mute controls, reopening the service without replaying writes,
  partial startup discovery, delayed wake, disconnect/reconnect, newer input
  arriving during recovery, sleep during recovery, and capped retry backoff.
- Recovery reads only missing/failed controls and preserves healthy controls.
- Actual cable removal and sleep/wake on the installed release still require
  real-world validation; simulated tests do not establish hardware reliability.

## v0.2.0

- Eleven XCTest cases passed locally: six control/protocol tests and five
  localization/preferences tests.
- Standard mode reaches 100 in 16 presses and traverses the same rounded stops
  in reverse; both modes progress from off-grid values and handle small ranges.
- Seven translation columns have matching placeholder tokens. Regional system
  language resolution and English fallback are tested.
- Language and per-control modes persist without resetting keyboard preferences
  or display selection. Legacy step settings migrate to the appropriate mode.
- Existing feedback changes language immediately; literal arguments are not
  interpreted as format tokens.
- Korean and German settings and English dark-mode panels were rendered and
  visually inspected. Quit is now an outlined button with a power icon.
- Homebrew Cask Ruby syntax and `brew style` passed.

## v0.1.0 hardware baseline

Verified locally on 2026-10-24 (Asia/Seoul):

- Swift build and four XCTest cases passed.
- Tests cover exact one-unit stepping across 16/100/255 ranges, clamping,
  custom step sizes, DDC request framing, checksum corruption, wrong control,
  unsupported replies, truncated replies, and out-of-range replies.
- Connected LG HDR 4K detected through the DCP service.
- Hardware values read successfully: volume 7/100, brightness 100/100.
- Explicit volume write/readback/restore diagnostic passed:
  `before=7, requested=8, readback=8, restored=7`.
- Release executable packaged into an ad-hoc signed `.app`, ZIP and DMG.
- `codesign --verify --deep --strict` and `hdiutil verify` passed.
- Actual SwiftUI/AppKit panel rendered and visually inspected. The screenshot
  uses preview data (21/100 volume, 65/100 brightness), not hardware state.

Requires testing after installation and user-granted Accessibility permission:

- Physical keyboard volume up/down and mute, including long press.
- Physical brightness keys after enabling that setting.
- Disconnect/reconnect and sleep/wake with this installed build.
- Login launch registration, multiple monitors, other cable/dock combinations.

MonitorControl must be quit for Monitor to handle media keys. The first preview
does not claim end-to-end keyboard verification before that permission is granted.
