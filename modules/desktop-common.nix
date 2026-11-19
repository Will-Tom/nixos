# Compositor-neutral desktop pieces. The compositor module (umbriel.nix) sets
# the greetd session command.
{ config, lib, pkgs, ... }:
let
  username = config.my.username;
in
{
  services.greetd = {
    enable = true;
    settings = {
      initial_session.user = username;
      default_session.user = username;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  services.gnome.gnome-keyring.enable = true;

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          # Physical Esc → F1, the modal key. Caps Lock still becomes Escape
          # via xkb caps:escape (keyd runs below xkb).
          esc = "f1";
        };
      };
    };
  };

  # `keyd listen` (used by the noctalia mode widget to show SUPER while Super
  # is held) needs the keyd socket, which keyd opens to the `keyd` group.
  users.groups.keyd = { };
  users.users.${username}.extraGroups = [ "keyd" ];
  environment.systemPackages = [ config.services.keyd.package ];
  # Once the group exists keyd calls setgid("keyd") at startup; the NixOS unit's
  # sandbox blocks that (no CAP_SETGID, @setuid filtered by ~@privileged) and
  # keyd crashes. Allow it; mkAfter so @setuid comes after ~@privileged.
  systemd.services.keyd.serviceConfig = {
    CapabilityBoundingSet = [ "CAP_SETGID" ];
    SystemCallFilter = lib.mkAfter [ "@setuid" ];
  };

  services.upower.enable = true;

  home-manager.users.${username} = {
    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.posy-cursors;
      name = "Posy_Cursor_Black";
      size = 32;
    };

    home.packages = with pkgs; [
      seahorse
      wl-screenrec
      brightnessctl
      slurp
    ];
  };
}
