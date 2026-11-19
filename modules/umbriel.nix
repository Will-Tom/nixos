# umbriel compositor: session and config. The modal keymap is a native umbriel
# submap (see umbriel/config.toml); the noctalia bar shows the active mode.
{ config, pkgs, ... }:
{
  programs.umbriel.enable = true;

  services.greetd.settings = {
    initial_session.command = "${config.programs.umbriel.package}/bin/start-umbriel";
    default_session.command = "${config.programs.umbriel.package}/bin/start-umbriel";
  };

  home-manager.users.${config.my.username} = {
    xdg.configFile."umbriel/config.toml".source = ./umbriel/config.toml;
    xdg.configFile."umbriel/effects".source = ./umbriel/effects;

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
    ];
  };
}
