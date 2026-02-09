# Dev setup (MVP)

## Prereqs

- macOS
- Xcode (recommended) or at least Apple Swift toolchain

## Running core logic

The repo currently includes:

- `DotPhraseCore` (SwiftPM library): phrase JSON loading + search ranking
- `dotphrase` (SwiftPM CLI): exercise search from the terminal

Example:

```bash
swift run dotphrase g
```

## Next step: menu bar app prototype

Recommended approach:

1) Create an Xcode project (Swift + AppKit/SwiftUI) for a menu bar app
2) Add this repo as a Swift Package dependency and import `DotPhraseCore`

MVP app responsibilities:
- capture global key events (Event Tap)
- detect `.` + >=1 letter
- show dropdown of matches
- on Enter: delete the trigger and paste phrase body

## Permissions (important)

The MVP will likely require **Accessibility** permission for:
- key monitoring
- synthetic key events (Cmd+V)
- deleting typed trigger

See `docs/PERMISSIONS.md`.
