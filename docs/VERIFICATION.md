# v0.1.0 verification

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
