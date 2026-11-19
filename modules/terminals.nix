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
        # Selection drawn as liquid glass by shaders/glass-*.slang: a
        # sentinel background it can find (must match SELECTION there), text
        # keeps its own colors. After the theme include so it wins.
        selection_foreground none
        selection_background #3d2a5c
        # Cursor position for the reading-glass lens (shaders/cursor-lens.slang):
        # the trail records every move (0-cell threshold) and decays instantly,
        # so it is never seen. No blinking, or the lens would blink with it.
        cursor_trail 1
        cursor_trail_decay 0.01 0.02
        cursor_trail_start_threshold 0
        cursor_blink_interval 0
        # Shader pipeline (glass selection + text glow); glow level set by
        # ~/bin/kitty-glow (Super+PageUp/Down)
        include ${config.xdg.stateHome}/kitty-glow/glow.conf
      '';
    };
    # Pipeline template (filled in by kitty-glow) and the shaders it uses
    xdg.configFile = {
      "kitty/glow.pipeline.in".source = ./terminals/glow.pipeline;
    } // lib.genAttrs
      (map (s: "kitty/shaders/${s}.slang")
        [ "term_cell" "cell-memory" "color-glow" "glass-mask" "glass-blur" "glass-selection" "cursor-find" "cursor-lens" ])
      (f: { source = ./terminals + "/${baseNameOf f}"; });
    home.file."bin/kitty-glow" = {
      source = ./terminals/kitty-glow.sh;
      executable = true;
    };
    # Regenerate the pipeline for the saved level (the template may have changed)
    home.activation.kittyGlow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ( PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnused pkgs.procps ]}:$PATH
        run ${pkgs.bash}/bin/bash $HOME/bin/kitty-glow init )
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
