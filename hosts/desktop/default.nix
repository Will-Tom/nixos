# AMD desktop (hostname "nixos")
{ config, ... }:
{
  imports = [
    ../../hardware-configuration.nix

    ../../roles/base.nix
    ../../roles/workstation.nix
    ../../roles/gaming.nix

    ../../modules/olympus.nix
    ../../modules/benchmarking.nix
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
