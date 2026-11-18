# NixOS config

Flake-based NixOS config. niri + Noctalia, home-manager as a NixOS module,
impermanence (tmpfs root, state under /persist), sops-nix, disko.

## Layout
- `flake.nix`: inputs; `mkHost` builds each `nixosConfigurations.<host>`
  and sets its hostname. Current hosts: `nixos` (desktop, `hosts/desktop/`).
- `hosts/<host>/`: hardware config, disko, graphics/firmware, stateVersions,
  and modules only that host uses (e.g. olympus, benchmarking).
- `roles/`: group feature modules. `base` (every machine, incl. impermanence
  and secrets), `workstation` (graphical machines), `gaming` (Steam).
- `modules/`: one file per feature. NixOS settings at the top level, the
  home-manager part under `home-manager.users.${config.my.username}`
  (`my.username` is defined in `modules/user.nix`).
  - Compositor-neutral desktop parts (keyd, portal, keyring, eww, fuzzel)
    are in `desktop-common.nix`; niri-only parts are in `niri.nix`.
  - Native config files (kdl, yaml, yuck, scss, scripts) sit next to their
    module and are deployed with `xdg.configFile` / `home.file`.
  - Each module declares its own `/persist` paths and its own sops secrets.

## Adding things
- New feature: add a module, then import it from the role that fits, or from
  the host if only one machine wants it. Don't put feature settings in
  `hosts/` or in the roles themselves.
- Prefer extending an existing module (`apps.nix`, `cli-tools.nix`, etc.)
  over creating a tiny new one.

## Rules
- `git add` new files before building; flakes ignore untracked files.
- Verify with `nixos-rebuild build --flake /etc/nixos#nixos`, then
  `nvd diff /run/current-system ./result`. Never run `sudo nixos-rebuild
  switch`; I apply changes myself.
- Never run disko. Never edit `secrets/` or `.sops.yaml`.
- Keep app configs in their native format; don't convert them to Nix.
- Commit after each working step. A git-backup service commits and pushes
  the tree at boot, so use a branch for larger changes and don't leave
  broken work uncommitted on main.
