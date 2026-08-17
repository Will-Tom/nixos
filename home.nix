{ pkgs, inputs, ... }:
{
  home.stateVersion = "26.05";
  home.username = "willisk";
  home.homeDirectory = "/home/willisk";
  programs.home-manager.enable = true;

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.posy-cursors;
    name = "Posy_Cursor_Black";
    size = 32; 
  };

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };
  
  systemd.user.tmpfiles.rules = [
    "D %h/Downloads/tmp 0755 - - -"
    "D %h/Pictures/screenshots/tmp 0755 - - -"
  ];

  
  home.file."bin/wlr-which-key-warp.sh" = {
    source = ./wlr-which-key-warp.sh;
    executable = true;
  };  

  home.file."bin/niri-fullscreen-toggle.sh" = {
    source = ./niri-fullscreen-toggle.sh;
    executable = true;
  };
  
  home.file."bin/wlr-which-key-toggle.sh" = {
    source = ./wlr-which-key-toggle.sh;
    executable = true;
  };

  home.file."bin/eww-mode-watcher.sh" = {
    source = ./eww-mode-watcher.sh;
    executable = true;
  };
  
  home.file."bin/wlr-which-key-home.sh" = {
    source = ./wlr-which-key-home.sh;
    executable = true;
  };

  home.file."bin/niri-mark-set.sh" = {
    source = ./niri-mark-set.sh;
    executable = true;
  };

  home.file."bin/niri-mark-jump.sh" = {
    source = ./niri-mark-jump.sh;
    executable = true;
  };
  home.file."bin/float-to-region.sh" = {
    source = ./float-to-region.sh;
    executable = true;
  };

  home.file."bin/dash-updates.sh"     = { source = ./dash-updates.sh;    executable = true; };
  home.file."bin/dash-filesystem.sh"  = { source = ./dash-filesystem.sh; executable = true; };
  home.file."bin/dash-git.sh"         = { source = ./dash-git.sh;        executable = true; };
  home.file."bin/dash-syncthing.sh"   = { source = ./dash-syncthing.sh;  executable = true; };

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
  
  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 11;
      confirm_os_window_close = 0;
    };
  };

  programs.fish = {
    enable = true;
    functions = {
      nrs = ''
        git -C /etc/nixos add -A
        sudo nixos-rebuild switch --flake /etc/nixos $argv
      '';
      perdown = ''
        set -l dest $argv[1]
        if test -z "$dest"
            set dest ~/Downloads
        end
        mv ~/Downloads/tmp/* $dest 2>/dev/null
      '';
      perscreen = ''
        set -l dest $argv[1]
        if test -z "$dest"
            set dest ~/Pictures/screenshots
        end
        mv ~/Pictures/screenshots/tmp/* $dest 2>/dev/null
      '';
    };
    interactiveShellInit = builtins.readFile ./fish-config.fish;
  };

  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; 

    settings = {
      theme = {
        mode = "dark";
        source = "community";
        community_palette = "Rosey AMOLED";  
      };

      shell.launch_apps_as_systemd_services = true;
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      confirm-close-surface = false;
      gtk-single-instance = false;
    };
  };

  systemd.user.services.dashboard = {
    Unit = {
      Description = "Boot dashboard terminals";
      After = [ "graphical-session.target" "niri.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "launch-dashboard" ''
        ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false --title=dash-updates    -e /home/willisk/bin/dash-updates.sh &
        sleep 0.3
        ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false --title=dash-filesystem -e /home/willisk/bin/dash-filesystem.sh &
        sleep 0.3
        ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false --title=dash-git        -e /home/willisk/bin/dash-git.sh &
      ''}";
    };
  };
  
  home.packages = with pkgs; [
    nvd
    google-chrome
    wl-screenrec
    eww
    fastfetch
    bitwarden-cli
    uv
    wlr-which-key
    fuzzel
    playerctl
    brightnessctl
    wireplumber
    obsidian
    yazi
    localsend
    xwayland-satellite
    godot_4
    mission-center
    hardinfo2
    btop
    bat
    eza
    jq
    slurp
  ];
  xdg.configFile."helix/config.toml".source = ./helix-config.toml;
  xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;
  xdg.configFile."wlr-which-key/modal.yaml".source = ./wlr-which-key-modal.yaml;
  xdg.configFile."eww/eww.yuck".source = ./eww.yuck;
  xdg.configFile."eww/eww.scss".source = ./eww.scss;
}
