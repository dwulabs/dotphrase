# dotphrase

macOS-only, popup-first dotphrase/smartphrase text expansion (Epic-style), usable across apps.

## MVP behavior

- User types `.` followed immediately by letters (e.g., `.ros`, `.avsd`).
- A small popup appears near the caret with fuzzy search over saved phrases.
- User hits **Enter** to insert the selected phrase into the current app.

## Implementation sketch

- Global key event tap (CGEventTap) to detect trigger sequences.
- Popup UI (SwiftUI/AppKit) listing matches.
- Insert via pasteboard + synthetic Cmd+V (or Accessibility insert).
- Local storage (JSON/SQLite) for phrases; cloud sync later.

## Dev quickstart

- Smoke check (build + basic CLI search):

```bash
./scripts/smoke.sh
```

- CLI usage (search is the text after the leading dot):

```bash
swift run dotphrase <query>
# example: finds ".gmail" in resources/phrases.sample.json
swift run dotphrase gm
```

## Status

- Core module: `DotPhraseCore` (loads local JSON + ranks matches).
- CLI: `swift run dotphrase <query>` to test search against `resources/phrases.sample.json`.

Next: menu bar app (event tap + dropdown + insertion).

