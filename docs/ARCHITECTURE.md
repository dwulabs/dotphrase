# Architecture (draft)

## Components

1) **Event monitor**
- CGEventTap captures keyDown events.
- Maintains a small rolling buffer of recent characters.
- Detects trigger pattern: `.` + `[a-zA-Z]{1,}`.

2) **Phrase store**
- Local-only for MVP.
- Data model: { trigger: string, body: string, description?: string, tags?: [] }.
- Start with a single JSON file under Application Support.

3) **Popup UI**
- Small floating panel near caret.
- Search-as-you-type; arrow keys to select.
- Enter inserts; Esc cancels.

4) **Insertion**
- Preferred MVP: pasteboard + synthesize Cmd+V.
- Replace the typed trigger (delete back N chars, including the leading dot) then paste. (MVP confirmed)

## Permissions

- Event tap may require Accessibility permissions.
- Insertion via Cmd+V also requires Accessibility.
