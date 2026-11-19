{ config, pkgs, ... }:
{
  home-manager.users.${config.my.username} = { config, lib, ... }: {
    programs.kitty = {
      enable = true;
      settings = {
        font_family = "JetBrainsMono Nerd Font";
        font_size = 11;
        confirm_os_window_close = 0;
        # Window management is umbriel's job: no kitty tabs/splits/shortcuts
        clear_all_shortcuts = "yes";
      };
      keybindings = {
        "ctrl+shift+c" = "copy_to_clipboard";
        "ctrl+shift+v" = "paste_from_clipboard";
      };
      # Colors from the noctalia palette (its kitty template writes this file
      # and reloads kitty when the theme changes; see noctalia.nix)
      extraConfig = ''
        include themes/noctalia.conf
        # Selection drawn as colored glass by shaders/glass-selection.slang: a
        # sentinel background it can find (must match SELECTION there), text
        # keeps its own colors. After the theme include so it wins.
        selection_foreground none
        selection_background #5a3f4e
        # Shader pipeline (glass selection + text glow); glow level set by
        # ~/bin/kitty-glow (Super+PageUp/Down)
        include ${config.xdg.stateHome}/kitty-glow/glow.conf
      '';
    };
    xdg.configFile."kitty/glow.pipeline.in".source = ./terminals/glow.pipeline;
    xdg.configFile."kitty/shaders/color-glow.slang".source = ./terminals/color-glow.slang;
    xdg.configFile."kitty/shaders/glass-selection.slang".source = ./terminals/glass-selection.slang;
    home.file."bin/kitty-glow" = {
      source = ./terminals/kitty-glow.sh;
      executable = true;
    };
    # Regenerate the pipeline for the saved level (the template may have changed)
    home.activation.kittyGlow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${pkgs.bash}/bin/bash $HOME/bin/kitty-glow init
    '';

    programs.ghostty = {
      enable = true;
      settings = {
        confirm-close-surface = false;
        gtk-single-instance = false;
      };
    };
  };
}
