# Ansible-Managed Fedora 44+/Arch Dotfiles Design

## Status

Revised design approved in chat on 2026-09-23. Specification review required before implementation.

## Goal

Provide a public GitHub repository that can be cloned without authentication. A tiny Bash bootstrap installs Ansible, then an Ansible playbook performs all dotfile and package management for Fedora 44+ and Arch.

Fresh-machine flow:

```bash
git clone "$DOTFILES_REPOSITORY" ~/.dotfiles
~/.dotfiles/bootstrap
```

`DOTFILES_REPOSITORY` is the public HTTPS URL published in the repository README. Public cloning requires no login. Publishing and pushing still require the owner's GitHub credentials.

## Architecture

Bash has one job: detect Fedora or Arch, install `ansible` with the native package manager, and invoke `ansible-playbook`. Bash does not enforce Fedora versions; Ansible rejects Fedora releases below 44 before package tasks. No Bash code performs package selection, file copying, backups, or dotfile management. The `.bashrc` and `.bash_profile` files are configuration payload only. Ansible owns package installation, directory creation, file copying, backups, and local-file preservation.

The playbook uses two local plays:

1. A privileged play installs required packages with `ansible.builtin.package`.
2. An unprivileged play copies configuration into the invoking user's home directory.

The repository uses a single playbook and inventory instead of a role or collection. This keeps first version small while following Ansible's declarative model.

## Included configuration

- Bash startup files, excluding personal Git identity
- Compact Fastfetch startup output without a logo
- Niri
- Waybar
- Matugen templates and theme pipeline
- btop
- Neovim/LazyVim
- Alacritty
- Fuzzel
- Cava
- xpad autostart entry
- Local `set-theme` and `autostart-wallpaper` scripts

Niri's shared configuration includes a local `hardware.kdl`. The playbook creates that file from a tracked example only when absent; it never overwrites an existing hardware file.

## Excluded items

- Emacs
- SSH keys, tokens, passwords, and other secrets
- Wallpaper images and `current_wallpaper`
- Firefox installation
- Caches, logs, history, and application state
- Full operating-system provisioning
- Custom Ansible collections beyond Ansible built-ins

## Repository layout

```text
bootstrap
ansible/
  inventory.ini
  site.yml
  group_vars/
    all.yml
home/
  .bashrc
  .bash_profile
  .config/
    alacritty/
    autostart/
    btop/
    cava/
    fuzzel/
    matugen/
    niri/
    nvim/
    waybar/
  .local/bin/
    autostart-wallpaper
    set-theme
README.md
.gitignore
tests/
  test_bootstrap.sh
```

The `home/` tree is the single source of truth for managed files. The playbook copies it to the target user's home without deleting unmanaged files.

## Bootstrap behavior

1. Require Bash, `git`, and a readable `/etc/os-release`.
2. Detect Fedora or Arch and leave Fedora version enforcement to Ansible; fail clearly on other distributions.
3. Install `ansible` using `dnf install -y` or `pacman -S --needed --noconfirm`.
4. When not root, validate the sudo credential cache with `sudo -v`, use `sudo -n` for package installation, then refresh `sudo -v` immediately before Ansible.
5. Run `ansible-playbook --ask-become-pass -i ansible/inventory.ini ansible/site.yml`, forwarding arguments such as `--check` and `--diff`; the become prompt works even when sudo timestamp caching is disabled.
6. Do not install dotfile packages, copy files, or manage secrets in Bash.

## Playbook behavior

- Assert that the target is Fedora 44+ or Arch before package changes.
- Install required package lists selected from `ansible/group_vars/all.yml` using `ansible.builtin.package`.
- Create required home and state directories with `ansible.builtin.file`.
- Copy the tracked `home/` tree with `ansible.builtin.copy`, `backup: yes`, and source modes preserved.
- Copy executable helper scripts with mode `0755`.
- Use `ansible.builtin.stat` plus a `force: no` copy for a missing `~/.config/niri/hardware.kdl`.
- Never copy, delete, or overwrite `~/.config/current_wallpaper`.
- Preserve machine-local files not present in the source tree.
- Print next steps for Git identity, Niri hardware, and wallpaper selection.

The playbook runs locally through `ansible_connection=local`. Package tasks use `become: true`; file tasks run as the invoking user so `~` and ownership remain correct.

## Dependencies

The package map covers:

- Bash, Git, and fastfetch
- Niri, Waybar, Alacritty, Fuzzel, Cava, btop, and Matugen
- Swaybg, Swaylock, Playerctl, Brightnessctl, Pavucontrol
- Fedora: PipeWire, `pipewire-alsa`, `pipewire-pulseaudio`, and WirePlumber
- Arch: PipeWire, `pipewire-alsa`, `pipewire-pulse`, and WirePlumber
- Neovim, xpad, and Orca
- Fedora: JetBrains Mono fonts plus Cascadia patched Nerd Font fallback
- Arch: JetBrains Mono Nerd Font plus Cascadia patched Nerd Font fallback
- Papirus icon theme and Breeze cursor theme (Fedora `breeze-cursor-theme`, Arch `breeze-cursors`)

Matugen is packaged for Fedora 44+. Wlogout is not automatically installed because it is AUR-only on Arch.

Firefox is intentionally not installed.

## Safety and privacy

The public repository contains no secrets, private keys, tokens, personal Git identity, machine-specific usernames, or wallpaper paths. Git identity remains local. Before publishing, scan all tracked files for private-key markers, token-like strings, and paths under the configured `SOURCE_HOME`.

Ansible's `backup: yes` protects managed files that change. `set-theme` separately backs up an existing `current_wallpaper` before replacing it because the user-invoked theme selector must update that state.

## Verification

- `bash -n bootstrap tests/test_bootstrap.sh`
- `ansible-playbook --syntax-check -i ansible/inventory.ini ansible/site.yml`
- `ansible-inventory -i ansible/inventory.ini --list`
- Run bootstrap tests with fake `dnf`, `pacman`, `sudo`, and `ansible-playbook` commands.
- Run a local Ansible check/diff pass without applying package or file changes.
- Scan the Git index before publishing for secrets and machine-specific paths.
- Confirm a fresh public HTTPS clone can run `bootstrap` without authentication, using a test environment before real package installation.

## Intentionally deferred

- Encrypted secret management
- Automatic AUR helper setup
- Multiple hardware profiles beyond one local Niri override
- Full desktop or browser provisioning
- Custom roles or collections