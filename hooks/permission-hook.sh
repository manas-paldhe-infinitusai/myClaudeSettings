#!/usr/bin/env bash
# PermissionRequest hook: Allow Once / Allow Forever / Deny
# Uses a native macOS dialog (osascript) so it works even when Claude Code's TUI
# is capturing the terminal — /dev/tty interaction doesn't work in that context.

INPUT=$(cat)
SUGGESTIONS=$(echo "$INPUT" | jq -c '.permission_suggestions // []')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown tool"')
TOOL_DETAIL=$(echo "$INPUT" | jq -r '
  .tool_input
  | to_entries
  | map("  \(.key): \(.value | tostring | .[0:120])")
  | join("\n")
' 2>/dev/null || echo "")

DIALOG_MSG="Tool: $TOOL
$TOOL_DETAIL"

# Write message to a temp file — avoids bash→AppleScript quoting issues entirely
TMPFILE=$(mktemp)
echo "$DIALOG_MSG" > "$TMPFILE"

# Show native macOS dialog — works regardless of terminal state
RESULT=$(osascript 2>/dev/null \
  -e "set msg to (do shell script \"cat \" & quoted form of \"$TMPFILE\")" \
  -e 'set d to display dialog msg buttons {"Deny", "Allow Once", "Allow Forever"} default button "Allow Once" with title "Claude Code Permission" giving up after 60' \
  -e 'if gave up of d then' \
  -e '  return "Allow Once"' \
  -e 'end if' \
  -e 'return button returned of d')
rm -f "$TMPFILE"

# If osascript failed (e.g. no display), fall back to allow-once
RESULT="${RESULT:-Allow Once}"

case "$RESULT" in
  "Allow Forever")
    # Override destination to userSettings so rules are global (not project-local)
    UPDATED_PERMISSIONS=$(echo "$SUGGESTIONS" | jq '[.[] | .destination = "userSettings"]')

    # Belt-and-suspenders: write directly to settings.json in case Claude Code
    # doesn't process the updatedPermissions field from hook output
    SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
      NEW_RULES=$(echo "$UPDATED_PERMISSIONS" | jq '[.[].rule]')
      jq --argjson new "$NEW_RULES" \
        '.permissions.allow = ((.permissions.allow // []) + $new | unique)' \
        "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
    fi

    jq -n \
      --argjson perms "$UPDATED_PERMISSIONS" \
      '{
        hookSpecificOutput: {
          hookEventName: "PermissionRequest",
          decision: { behavior: "allow" },
          updatedPermissions: $perms
        }
      }'
    ;;

  "Deny")
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PermissionRequest",
        decision: { behavior: "deny" },
        reason: "Denied by user"
      }
    }'
    ;;

  *)
    # Allow Once (default for "Allow Once", timeout, or any error)
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PermissionRequest",
        decision: { behavior: "allow" }
      }
    }'
    ;;
esac
