#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ORIGINAL_PATH="$PATH"
COMMAND_LOG="$TMP/commands.log"
BIN="$TMP/bin"
mkdir -p "$BIN"

cat > "$BIN/fuzzel" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
: "${FUZZEL_SELECT:?}"
: "${FUZZEL_INPUT_LOG:?}"
selected=0
while IFS= read -r path; do
    printf '%s\n' "$path" >> "$FUZZEL_INPUT_LOG"
    if [[ "$path" == "$FUZZEL_SELECT" ]]; then
        selected=1
    fi
done
(( selected == 1 ))
printf '%s\n' "$FUZZEL_SELECT"
EOF

for command_name in pkill swaybg matugen; do
    cat > "$BIN/$command_name" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s %s\\n' "$command_name" "\$*" >> "\$COMMAND_LOG"
EOF
    chmod +x "$BIN/$command_name"
done
chmod +x "$BIN/fuzzel"

make_home() {
    local home="$1"
    mkdir -p \
        "$home/.config" \
        "$home/Pictures/wallpapers/nested" \
        "$home/Pictures/wallpapers/other"
    : > "$home/Pictures/wallpapers/nested/shared.png"
    : > "$home/Pictures/wallpapers/other/shared.png"
}

run_theme() {
    local home="$1"
    local selection="$2"
    : > "$COMMAND_LOG"
    HOME="$home" \
        FUZZEL_SELECT="$selection" \
        FUZZEL_INPUT_LOG="$home/fuzzel-input.log" \
        COMMAND_LOG="$COMMAND_LOG" \
        PATH="$BIN:$ORIGINAL_PATH" \
        "$ROOT/home/.local/bin/set-theme"
}

# Normal selection keeps a nested full path, including duplicate basenames.
NORMAL_HOME="$TMP/normal"
make_home "$NORMAL_HOME"
NORMAL_WALLPAPER="$NORMAL_HOME/Pictures/wallpapers/nested/shared.png"
run_theme "$NORMAL_HOME" "$NORMAL_WALLPAPER"
test "$(cat "$NORMAL_HOME/.config/current_wallpaper")" = "$NORMAL_WALLPAPER"
grep -Fqx "$NORMAL_WALLPAPER" "$NORMAL_HOME/fuzzel-input.log"
grep -Fq "matugen image $NORMAL_WALLPAPER" "$COMMAND_LOG"
printf '%s\n' 'ok - nested wallpaper selection'

# Existing state is backed up before replacement.
BACKUP_HOME="$TMP/backup"
make_home "$BACKUP_HOME"
BACKUP_WALLPAPER="$BACKUP_HOME/Pictures/wallpapers/nested/shared.png"
OLD_WALLPAPER="$BACKUP_HOME/Pictures/wallpapers/old.png"
printf '%s\n' "$OLD_WALLPAPER" > "$BACKUP_HOME/.config/current_wallpaper"
run_theme "$BACKUP_HOME" "$BACKUP_WALLPAPER"
test "$(cat "$BACKUP_HOME/.config/current_wallpaper")" = "$BACKUP_WALLPAPER"
BACKUP_FILES=()
while IFS= read -r path; do
    BACKUP_FILES+=("$path")
done < <(find "$BACKUP_HOME/.local/state/dotfiles/backups" -type f -name 'current_wallpaper.*' -print)
test "${#BACKUP_FILES[@]}" -eq 1
test "$(cat "${BACKUP_FILES[0]}")" = "$OLD_WALLPAPER"
printf '%s\n' 'ok - existing state backup'

# State write failure must stop before wallpaper commands run.
FAIL_HOME="$TMP/fail"
make_home "$FAIL_HOME"
FAIL_WALLPAPER="$FAIL_HOME/Pictures/wallpapers/nested/shared.png"
ln -s /dev/full "$FAIL_HOME/.config/current_wallpaper"
FAIL_BIN="$TMP/fail-bin"
mkdir -p "$FAIL_BIN"
cat > "$FAIL_BIN/cp" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAIL_BIN/cp"
FAIL_ERROR="$TMP/fail-state-write.err"
: > "$COMMAND_LOG"
if HOME="$FAIL_HOME" \
    FUZZEL_SELECT="$FAIL_WALLPAPER" \
    FUZZEL_INPUT_LOG="$FAIL_HOME/fuzzel-input.log" \
    COMMAND_LOG="$COMMAND_LOG" \
    PATH="$FAIL_BIN:$BIN:$ORIGINAL_PATH" \
    "$ROOT/home/.local/bin/set-theme" 2>"$FAIL_ERROR"; then
    printf '%s\n' 'state write failure unexpectedly succeeded'
    exit 1
fi
grep -Fq 'Kunde inte skriva wallpaper-state.' "$FAIL_ERROR"
! grep -Fq 'pkill' "$COMMAND_LOG"
! grep -Fq 'swaybg' "$COMMAND_LOG"
! grep -Fq 'matugen' "$COMMAND_LOG"
printf '%s\n' 'ok - fail-closed state write'
