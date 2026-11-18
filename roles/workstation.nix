# Graphical desktop machine.
{ ... }:
{
  imports = [
    ../modules/mullvad.nix
    ../modules/bluetooth.nix
    ../modules/audio.nix
    ../modules/printing.nix
    ../modules/browser.nix
    ../modules/desktop-common.nix
    ../modules/niri.nix
    ../modules/noctalia.nix
    ../modules/terminals.nix
    ../modules/dashboard.nix
    ../modules/git-backup.nix
    ../modules/apps.nix
  ];
}
