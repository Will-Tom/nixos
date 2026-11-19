{ config, ... }:
{
  home-manager.users.${config.my.username} = {
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
        # Soft glow around text (shaders/glow.pipeline)
        custom_shaders glow
      '';
    };
    xdg.configFile."kitty/shaders/glow.pipeline".source = ./terminals/glow.pipeline;

    programs.ghostty = {
      enable = true;
      settings = {
        confirm-close-surface = false;
        gtk-single-instance = false;
      };
    };
  };
}
