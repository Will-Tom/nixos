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
        # Soft glow around text; level set by ~/bin/kitty-glow (Super+PageUp/Down)
        include ${config.xdg.stateHome}/kitty-glow/glow.conf
      '';
    };
    xdg.configFile."kitty/glow.pipeline.in".source = ./terminals/glow.pipeline;
    home.file."bin/kitty-glow" = {
      source = ./terminals/kitty-glow.sh;
      executable = true;
    };
    # Write the default level on first activation so new kitties glow
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
