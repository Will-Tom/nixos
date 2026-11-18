# Every machine: nix, boot, user, secrets, impermanence, networking, shell.
{ ... }:
{
  imports = [
    ../modules/nix-settings.nix
    ../modules/boot.nix
    ../modules/locale.nix
    ../modules/user.nix
    ../modules/secrets.nix
    ../modules/impermanence.nix
    ../modules/storage.nix
    ../modules/networking.nix
    ../modules/shell.nix
    ../modules/cli-tools.nix
  ];
}
