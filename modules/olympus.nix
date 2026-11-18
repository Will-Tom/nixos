# Olympus: Celeste mod manager
{ config, pkgs, ... }:
{
  programs.nix-ld.enable = true; #needed for celeste modding

  home-manager.users.${config.my.username}.home.packages = [
    (pkgs.olympus.override { celesteWrapper = "steam-run"; })
  ];
}
