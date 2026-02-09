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

## Status

Scaffolding only (repo created). Next: decide architecture + start a minimal event-tap + popup prototype.
