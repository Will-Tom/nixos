{ config, pkgs, ... }:
{
  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };

  environment.systemPackages = [ pkgs.mullvad-browser ];

  environment.persistence."/persist" = {
    directories = [
      "/etc/mullvad-vpn"
      "/var/cache/mullvad-vpn"
    ];
    users.${config.my.username}.directories = [ ".mullvad" ];
  };
}
