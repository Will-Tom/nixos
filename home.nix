{ pkgs, inputs, ... }:
  {
    home.stateVersion = "26.05";
    home.username = "willisk";
    home.homeDirectory = "/home/willisk";
    programs.home-manager.enable = true;
    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "onedark";
        editor.cursor-shape.insert = "bar";
      };
    };
    programs.kitty = {
      enable = true;
      settings = {
        font_family = "JetBrainsMono Nerd Font";
        font_size = 11;
        confirm_os_window_close = 0;
      };
    };
    home.packages = with pkgs; [
      wlr-which-key
      fuzzel
      playerctl
      brightnessctl
      wireplumber
      inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;
    xdg.configFile."niri/noctalia.kdl".source = ./noctalia.kdl;
    xdg.configFile."wlr-which-key/modal.yaml".source = ./wlr-which-key-modal.yaml;
  }
