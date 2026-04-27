
⏺ I can enable Full Keyboard Access via a defaults write command — no UI needed.

⏺ Bash(defaults write NSGlobalDomain AppleKeyboardUIMode -int 3)
  ⎿  (No output)
  ⎿  Allowed by PermissionRequest hook

⏺ Done. Full Keyboard Access is now enabled system-wide.

  In the macOS permission popup, you can now use:
  - Tab to move between buttons (Deny / Allow Once / Allow Forever)
  - Space to press the focused button
  - Return to press the default button ("Allow Once")
