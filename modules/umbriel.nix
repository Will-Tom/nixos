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
