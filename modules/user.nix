{ config, lib, pkgs, ... }:
let
  username = config.my.username;
in
{
  options.my.username = lib.mkOption {
    type = lib.types.str;
    default = "willisk";
    description = "Primary user account; home-manager config is attached to this user.";
  };

  config = {
    users.users.${username} = {
      isNormalUser = true;
      description = "Will Thompson";
      extraGroups = [ "networkmanager" "wheel" "lp" ];
      shell = pkgs.fish;
      hashedPasswordFile = config.sops.secrets."willisk_password_hash".path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGm8b8/LQKQRi8Zw33danKnB4p1ICA1x1lDLb9+jxZNm"
      ];
    };

    sops.secrets."willisk_password_hash" = {
      sopsFile = ../secrets/user_password.yaml;
      neededForUsers = true;
    };

    environment.persistence."/persist".users.${username}.directories = [
      "Downloads" "Documents" "Projects" "Videos" "Pictures" ".config" ".local/share"
      ".ssh" ".local/state"
    ];

    home-manager.users.${username} = {
      home.username = username;
      home.homeDirectory = "/home/${username}";
      programs.home-manager.enable = true;

      # Staging folders for new downloads and screenshots (see perdown/perscreen in shell.nix)
      systemd.user.tmpfiles.rules = [
        "D %h/Downloads/tmp 0755 - - -"
        "D %h/Pictures/screenshots/tmp 0755 - - -"
      ];
    };
  };
}
