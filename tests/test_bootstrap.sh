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
grep -q '^dnf install -y ansible-core$' "$BOOTSTRAP_TEST_LOG"
grep -q '^ansible-playbook .*ansible/inventory.ini .*ansible/site.yml --check --diff$' "$BOOTSTRAP_TEST_LOG"

: > "$BOOTSTRAP_TEST_LOG"
DOTFILES_OS_RELEASE="$TMP/arch-release" "$ROOT/bootstrap"
grep -q '^pacman -S --needed --noconfirm ansible-core$' "$BOOTSTRAP_TEST_LOG"
grep -q '^ansible-playbook .*ansible/inventory.ini .*ansible/site.yml$' "$BOOTSTRAP_TEST_LOG"

if DOTFILES_OS_RELEASE="$TMP/other-release" "$ROOT/bootstrap" 2>/dev/null; then
    printf '%s\n' 'unsupported distro unexpectedly succeeded'
    exit 1
fi
