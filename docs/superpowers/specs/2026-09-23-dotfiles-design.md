# Portable Fedora/Arch Dotfiles Design

## Status

Design approved in chat on 2026-09-23. Specification review required before implementation.

## Goal

Provide a public GitHub repository that can be cloned without authentication. A small Bash installer copies portable configuration to a new Fedora or Arch machine and installs the tools needed by the selected configuration.

Fresh-machine flow:

```bash
git clone "$DOTFILES_REPOSITORY" ~/.dotfiles
~/.dotfiles/install
```

`DOTFILES_REPOSITORY` is the public HTTPS URL published in the repository README. Public cloning requires no login. Publishing and pushing still require the owner's GitHub credentials.

## Included configuration

- Bash and Git setup, excluding personal Git identity
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

The Niri configuration is shared, but monitor definitions live in an untracked per-machine `hardware.kdl` file. The installer creates that file from an example only when it is missing.

## Excluded items

- Emacs
- SSH keys, tokens, passwords, and other secrets
- Wallpaper images and `current_wallpaper`
- Firefox installation
- Caches, logs, history, and application state
- Full operating-system provisioning

## Repository layout

```text
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
bin/
  autostart-wallpaper
  set-theme
install
README.md
.gitignore
```

The repository stores current generated theme files as bootstrap defaults. Matugen may update those files locally when a wallpaper is selected. Wallpaper paths and images remain local.

## Installer behavior

1. Require Bash and a supported Fedora or Arch system.
2. Parse `/etc/os-release` and select the matching package manager.
3. Install required packages with `dnf` or `pacman`.
4. Warn about optional tools instead of failing when an optional tool is absent.
5. Copy only tracked files, preserving executable permissions.
6. Back up every changed destination under `~/.local/state/dotfiles/backups/$timestamp/` before replacement.
7. Never overwrite `~/.config/niri/hardware.kdl` or `~/.config/current_wallpaper`.
8. Normalize hard-coded `/home/ludvig` paths to `$HOME`-based paths.
9. Make the btop theme path portable.
10. Remove the unused ncspot Matugen target.
11. Support `--dry-run` without changing the system.
12. Print next steps and any missing optional commands.

The installer copies files rather than symlinking them. This keeps local generated files and per-machine files independent from the Git checkout. Re-running the installer after `git pull` updates managed files safely.

## Dependencies

Required package groups cover:

- Shell and Git: Bash, Git, fastfetch
- Desktop: Niri, Waybar, Alacritty, Fuzzel, Cava, btop, Matugen
- Session utilities: Swaybg, Swaylock, Wlogout
- Media and hardware utilities: Playerctl, Brightnessctl, Pavucontrol, PipeWire, WirePlumber
- Editors and accessories: Neovim, xpad, Orca
- Fonts and icons: JetBrainsMono Nerd Font, Papirus

Exact package names are kept in a Fedora/Arch mapping in `install`. A missing required package stops installation with a clear message. Firefox is intentionally not installed.

## Safety and privacy

The repository is public. It must contain no secrets, private keys, tokens, personal Git identity, machine-specific usernames, or private wallpaper paths. Before publishing, scan tracked files for private-key markers, token-like strings, and `/home/ludvig` paths.

Git identity remains local to each machine. The README provides per-machine identity setup rather than committing an identity file.

## Verification

- Run `bash -n install`.
- Exercise `install --dry-run` on Fedora and through a fake package-manager path for Arch.
- Test installation against a temporary HOME to verify copying, backups, permissions, and local override preservation.
- Scan the Git index before publishing for secrets and machine-specific paths.
- Confirm a fresh public HTTPS clone can run the installer without authentication.

## Intentionally deferred

- Encrypted secret management
- Automatic AUR helper setup
- Multiple hardware profiles beyond one local Niri override
- Full desktop or browser provisioning