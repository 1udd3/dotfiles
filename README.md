# Dotfiles

Public Fedora 44+ and Arch desktop configuration managed by Ansible.

## Install

```bash
git clone "$DOTFILES_REPOSITORY" ~/.dotfiles
~/.dotfiles/bootstrap
```

`DOTFILES_REPOSITORY` is this repository's public HTTPS URL. Cloning it requires no login. The tiny Bash bootstrap installs Ansible Core; Ansible rejects Fedora releases below 44 before installing packages.

## Update

```bash
git -C ~/.dotfiles pull --ff-only
~/.dotfiles/bootstrap
```

Preview changes with:

```bash
~/.dotfiles/bootstrap --check --diff
```

## Local state

Ansible never manages `~/.config/current_wallpaper`. Edit `~/.config/niri/hardware.kdl` for monitor names, positions, and scale. Run `niri msg outputs` to discover connector names. The playbook creates the hardware file from a tracked example only when absent.

Set Git identity locally on each machine; no identity is committed here:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

This public repository contains no SSH keys, tokens, passwords, or personal Git identity. Firefox is not installed.
