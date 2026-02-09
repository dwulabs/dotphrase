# Planning (tonight)

## MVP goals

- Menu bar app starts at login (optional later)
- Global key monitor detects `.letters` sequence
- Popup panel shows top matches for `letters`
- Enter inserts phrase via pasteboard + Cmd+V
- Phrases loaded from local JSON

## Next concrete steps

1) Create Xcode project (Swift + SwiftUI) as menu bar app
2) Implement event tap / global monitor + rolling buffer
3) Implement minimal popup window (NSPanel) with list
4) Implement insertion: backspace N + paste
5) Add minimal phrase store + sample phrases
