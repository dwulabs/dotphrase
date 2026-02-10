# Permissions (macOS)

The dotphrase MVP will likely require **Accessibility** *and/or* **Input Monitoring** permissions (macOS can vary by version and event tap type).

Why:
- capturing global key events (Event Tap)
- sending synthetic key events (backspace + Cmd+V)

## How to grant

System Settings → Privacy & Security → Accessibility

Enable the dotphrase app.

Also check:
System Settings → Privacy & Security → Input Monitoring

Enable the dotphrase app (or the `dotphrase-menubar` binary if it appears separately).

## UX note

We should:
- detect missing permission
- show a clear prompt / button that opens the System Settings pane
