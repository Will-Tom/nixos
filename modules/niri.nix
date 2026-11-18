{ config, pkgs, ... }:
let
  username = config.my.username;
  script = path: { source = path; executable = true; };
in
{
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = username;
      };
      default_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = username;
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  services.gnome.gnome-keyring.enable = true;

  programs.niri.enable = true;
  systemd.user.services.niri.enableDefaultPath =  false;

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

    xdg.configFile."niri/config.kdl".source = ./niri/niri-config.kdl;
    xdg.configFile."wlr-which-key/modal.yaml".source = ./niri/wlr-which-key-modal.yaml;
    xdg.configFile."eww/eww.yuck".source = ./niri/eww.yuck;
    xdg.configFile."eww/eww.scss".source = ./niri/eww.scss;

    home.file."bin/wlr-which-key-warp.sh"   = script ./niri/wlr-which-key-warp.sh;
    home.file."bin/wlr-which-key-toggle.sh" = script ./niri/wlr-which-key-toggle.sh;
    home.file."bin/wlr-which-key-home.sh"   = script ./niri/wlr-which-key-home.sh;
    home.file."bin/niri-fullscreen-toggle.sh" = script ./niri/niri-fullscreen-toggle.sh;
    home.file."bin/niri-mark-set.sh"        = script ./niri/niri-mark-set.sh;
    home.file."bin/niri-mark-jump.sh"       = script ./niri/niri-mark-jump.sh;
    home.file."bin/float-to-region.sh"      = script ./niri/float-to-region.sh;
    home.file."bin/eww-mode-watcher.sh"     = script ./niri/eww-mode-watcher.sh;

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
      wlr-which-key
      fuzzel
      brightnessctl
      xwayland-satellite
      slurp
    ];
  };
}
