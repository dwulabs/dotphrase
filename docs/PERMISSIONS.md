# Permissions (macOS)

The dotphrase MVP will likely require **Accessibility** permissions.

Why:
- capturing global key events (Event Tap)
- sending synthetic key events (backspace + Cmd+V)

## How to grant

System Settings → Privacy & Security → Accessibility

Enable the dotphrase app.

## UX note

We should:
- detect missing permission
- show a clear prompt / button that opens the System Settings pane
