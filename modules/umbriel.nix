# umbriel compositor: session and config. The modal keymap is a native umbriel
# submap (see umbriel/config.toml); the noctalia bar shows the active mode.
{ config, lib, pkgs, ... }:
let
  # Bar glow levels 1-10 (Super+Shift+PgUp/PgDn, ~/bin/bar-glow): the
  # template with STRENGTH = level * 0.03.
  barGlowTemplate = builtins.readFile ./umbriel/bar-glow.glsl;
  barGlowDefault = "const float STRENGTH = 0.12;";
  barGlow = n:
    assert lib.hasInfix barGlowDefault barGlowTemplate;
    builtins.replaceStrings [ barGlowDefault ]
      [ "const float STRENGTH = 0.${lib.fixedWidthNumber 2 (n * 3)};" ]
      barGlowTemplate;
in
{
  programs.umbriel.enable = true;

  # Mice (not keyboards) readable by the seat's user, for ~/bin/modal-click.
  # A package so it lands before 73-seat-late.rules, which applies uaccess.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-mouse-uaccess.rules" ''
      SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", ENV{ID_INPUT_KEYBOARD}!="1", ENV{ID_INPUT_KEY}!="1", TAG+="uaccess"
    '')
  ];

  services.greetd.settings = {
    initial_session.command = "${config.programs.umbriel.package}/bin/start-umbriel";
    default_session.command = "${config.programs.umbriel.package}/bin/start-umbriel";
  };

  home-manager.users.${config.my.username} = {
    xdg.configFile = {
      "umbriel/config.toml".source = ./umbriel/config.toml;
      "umbriel/effects".source = ./umbriel/effects;
    } // lib.listToAttrs (map (n: lib.nameValuePair
      "umbriel/bar-glow/${toString n}.glsl" { text = barGlow n; })
      (lib.range 1 10));

    # Super+Shift+PgUp/PgDn: bar glow level 0-10
    home.file."bin/bar-glow" = {
      source = ./umbriel/bar-glow.sh;
      executable = true;
    };
    # Applies the saved level and turns the glow off on outputs that show a
    # fullscreen window or have no bar
    systemd.user.services.bar-glow = {
      Unit = {
        Description = "Bar glow: follow fullscreen and bar visibility";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        X-Restart-Triggers = [ "${./umbriel/bar-glow.sh}" ];
      };
      Service = {
        Environment = [ "PATH=/etc/profiles/per-user/${config.my.username}/bin:/run/current-system/sw/bin" ];
        ExecStart = "%h/bin/bar-glow watch";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Any mouse click leaves the modal submap
    home.file."bin/modal-click" = {
      source = ./umbriel/modal-click.sh;
      executable = true;
    };
    systemd.user.services.modal-click = {
      Unit = {
        Description = "Leave umbriel's modal mode on mouse click";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        X-Restart-Triggers = [ "${./umbriel/modal-click.sh}" ];
      };
      Service = {
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.evtest pkgs.systemd pkgs.util-linux pkgs.gnugrep pkgs.coreutils pkgs.bash ]}:/etc/profiles/per-user/${config.my.username}/bin:/run/current-system/sw/bin" ];
        ExecStart = "%h/bin/modal-click";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Fading "KEY - action" toast on the noctalia bar, called from keybinds
    home.file."bin/bar-toast" = {
      source = ./umbriel/bar-toast.sh;
      executable = true;
    };

    # Launch at a given width: Super+Shift+Space (launcher, 1/2), Super+Shift+T (terminal, 1/3)
    home.file."bin/launch-sized" = {
      source = ./umbriel/launch-sized.sh;
      executable = true;
    };

    # RESIZE ! @ #: set every tiled column on the workspace to full, 1/2, 1/3
    home.file."bin/resize-all" = {
      source = ./umbriel/resize-all.sh;
      executable = true;
    };

    # Super+Shift+S / modal S: close every window on the focused workspace
    home.file."bin/close-workspace" = {
      source = ./umbriel/close-workspace.sh;
      executable = true;
    };

    # Super+scroll screen zoom (steps the zoom_* cursor-effect presets)
    home.file."bin/zoom" = {
      source = ./umbriel/zoom.sh;
      executable = true;
    };

    # Modal V: float the focused window into a slurp-drawn region
    home.file."bin/float-to-region.sh" = {
      source = ./umbriel/float-to-region.sh;
      executable = true;
    };

    home.packages = with pkgs; [
      grim # screenshots (Mod+P / Mod+Shift+P)
      wl-clipboard # wl-copy: screenshots also go to the clipboard
    ];
  };
}
