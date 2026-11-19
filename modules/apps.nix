# GUI applications
{ config, pkgs, ... }:
{
  home-manager.users.${config.my.username}.home.packages = with pkgs; [
    aseprite
    foliate
    super-productivity
    obsidian
    localsend
    godot_4
    mission-center
    hardinfo2
    discord
  ];
}
