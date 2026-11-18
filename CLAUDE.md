# NixOS config

Flake-based NixOS config. niri + Noctalia, home-manager as a NixOS module,
impermanence (tmpfs root, state under /persist), sops-nix, disko.

## Layout
- `flake.nix`: inputs; `mkHost` builds each `nixosConfigurations.<host>`
- `hosts/<host>/`: hardware config, disko, host-only settings and files
- `roles/`: modules that group feature modules (base, workstation, gaming)
- `modules/`: one file per feature. NixOS settings at the top level, the
  home-manager part nested under `home-manager.users.${config.my.username}`.
  Native config files (kdl, yaml, eww, scripts) sit in a folder next to their
  module and are deployed with `xdg.configFile` / `home.file`.
- Each module persists its own state via `environment.persistence."/persist"`.

## Rules
- `git add` new files before building; flakes ignore untracked files.
- Verify with `nixos-rebuild build --flake /etc/nixos#nixos`, then
  `nvd diff /run/current-system ./result`. Never run `sudo nixos-rebuild
  switch`; I apply changes myself.
- Never run disko. Never edit `secrets/` or `.sops.yaml`.
- Keep app configs in their native format; don't convert them to Nix.
- Commit after each working step.
