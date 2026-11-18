{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ./modules/nix-settings.nix
    ./modules/boot.nix
    ./modules/locale.nix
    ./modules/user.nix
    ./modules/secrets.nix
    ./modules/impermanence.nix
    ./modules/storage.nix
    ./modules/networking.nix
    ./modules/mullvad.nix
    ./modules/bluetooth.nix
    ./modules/audio.nix
    ./modules/printing.nix
    ./modules/browser.nix
    ./modules/desktop-common.nix
    ./modules/niri.nix
    ./modules/noctalia.nix
    ./modules/terminals.nix
    ./modules/dashboard.nix
    ./modules/git-backup.nix
    ./modules/gaming.nix
    ./modules/olympus.nix
    ./modules/shell.nix
    ./modules/cli-tools.nix
    ./modules/apps.nix
    ./modules/benchmarking.nix
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "26.05";
  home-manager.users.${config.my.username}.home.stateVersion = "26.05";
}
