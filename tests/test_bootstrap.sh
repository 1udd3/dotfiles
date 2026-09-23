#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export BOOTSTRAP_TEST_LOG="$TMP/bootstrap.log"
mkdir -p "$TMP/bin"

for command_name in dnf pacman sudo ansible-playbook; do
    cat > "$TMP/bin/$command_name" <<EOF
#!/usr/bin/env bash
printf '%s %s\\n' "$command_name" "\$*" >> "\$BOOTSTRAP_TEST_LOG"
EOF
    chmod +x "$TMP/bin/$command_name"
done

cat > "$TMP/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >> "$BOOTSTRAP_TEST_LOG"
if [[ "${1:-}" == "-v" ]]; then
    exit 0
fi
if [[ "${1:-}" == "-n" ]]; then
    shift
fi
exec "$@"
EOF
chmod +x "$TMP/bin/sudo"

cat > "$TMP/fedora-release" <<'EOF'
ID=fedora
EOF
cat > "$TMP/arch-release" <<'EOF'
ID=arch
EOF
cat > "$TMP/other-release" <<'EOF'
ID=debian
EOF

export PATH="$TMP/bin:$PATH"
DOTFILES_OS_RELEASE="$TMP/fedora-release" "$ROOT/bootstrap" --check --diff
test "$(grep -c '^sudo -v$' "$BOOTSTRAP_TEST_LOG")" -eq 2
grep -q '^sudo -n dnf install -y ansible$' "$BOOTSTRAP_TEST_LOG"
grep -q '^dnf install -y ansible$' "$BOOTSTRAP_TEST_LOG"
grep -q '^ansible-playbook --ask-become-pass .*ansible/inventory.ini .*ansible/site.yml --check --diff$' "$BOOTSTRAP_TEST_LOG"

: > "$BOOTSTRAP_TEST_LOG"
DOTFILES_OS_RELEASE="$TMP/arch-release" "$ROOT/bootstrap"
test "$(grep -c '^sudo -v$' "$BOOTSTRAP_TEST_LOG")" -eq 2
grep -q '^sudo -n pacman -S --needed --noconfirm ansible$' "$BOOTSTRAP_TEST_LOG"
grep -q '^pacman -S --needed --noconfirm ansible$' "$BOOTSTRAP_TEST_LOG"
grep -q '^ansible-playbook --ask-become-pass .*ansible/inventory.ini .*ansible/site.yml$' "$BOOTSTRAP_TEST_LOG"

if DOTFILES_OS_RELEASE="$TMP/other-release" "$ROOT/bootstrap" 2>/dev/null; then
    printf '%s\n' 'unsupported distro unexpectedly succeeded'
    exit 1
fi

! grep -Fq 'user_facts' "$ROOT/ansible/site.yml"
grep -Fq "dotfiles_home: \"{{ ansible_facts['user_dir'] }}\"" "$ROOT/ansible/site.yml"
grep -Fq "ansible_facts['distribution'] == 'Archlinux'" "$ROOT/ansible/site.yml"
grep -Fq "ansible_facts['distribution'] == 'Fedora'" "$ROOT/ansible/site.yml"
grep -Fq "ansible_facts['distribution'] == 'Archlinux' or ansible_facts['distribution_version'] | int >= 44" "$ROOT/ansible/site.yml"
! grep -Fq 'wlogout' "$ROOT/ansible/group_vars/all.yml"
! grep -Fq 'wlogout' "$ROOT/home/.config/niri/config.kdl"
grep -Fq '  - breeze-cursor-theme' "$ROOT/ansible/group_vars/all.yml"
grep -Fq '  - breeze-cursors' "$ROOT/ansible/group_vars/all.yml"
grep -Fq 'XCURSOR_THEME "breeze_cursors"' "$ROOT/home/.config/niri/config.kdl"
grep -Fq 'fastfetch --structure OS:Host:Kernel:Shell:CPU:Memory' "$ROOT/home/.bashrc"
# No AUR helpers or package-manager commands outside Bash's required dnf/pacman path.
helper_pattern='(^|[^[:alnum:]_])(aur|aurhelper|aurutils|yay|paru|pikaur|trizen|octopi|garud|makepkg|flatpak|snap|brew|zypper|apt|apk)([^[:alnum:]_]|$)'
! grep -Eiq "$helper_pattern" "$ROOT/bootstrap"
! grep -Eiq "$helper_pattern|dnf|pacman" "$ROOT/ansible/site.yml"
guard_line="$(grep -n 'name: Require Fedora 44' "$ROOT/ansible/site.yml" | cut -d: -f1)"
package_line="$(grep -n 'name: Install dotfile dependencies' "$ROOT/ansible/site.yml" | cut -d: -f1)"
test "$guard_line" -lt "$package_line"
