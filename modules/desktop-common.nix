# Compositor-neutral desktop pieces. The compositor module (niri.nix) sets the
# greetd session command.
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
          leftmeta = "overload(meta, f1)";
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

    # eww widgets, plus the mode indicator fed by wlr-which-key
    xdg.configFile."eww/eww.yuck".source = ./desktop-common/eww.yuck;
    xdg.configFile."eww/eww.scss".source = ./desktop-common/eww.scss;
    home.file."bin/eww-mode-watcher.sh" = {
      source = ./desktop-common/eww-mode-watcher.sh;
      executable = true;
    };

    systemd.user.services.eww-mode-watcher = {
      Unit = {
        Description = "wlr-which-key mode indicator watcher";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" "eww-daemon.service" ];
      };
      Service = {
        ExecStart = "/home/willisk/bin/eww-mode-watcher.sh";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

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
