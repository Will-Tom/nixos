# Compositor-neutral desktop pieces. The compositor module (umbriel.nix) sets
# the greetd session command.
{ config, pkgs, ... }:
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

    # eww widgets (the wlr-which-key mode watcher lives in niri.nix)
    xdg.configFile."eww/eww.yuck".source = ./desktop-common/eww.yuck;
    xdg.configFile."eww/eww.scss".source = ./desktop-common/eww.scss;

    systemd.user.services.eww-daemon = {
      Unit = {
        Description = "eww widget daemon";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.eww}/bin/eww daemon --no-daemonize";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.packages = with pkgs; [
      seahorse
      wl-screenrec
      eww
      fuzzel
      brightnessctl
      slurp
    ];
  };
}
