{ pkgs, inputs, ... }:
{
  home.stateVersion = "26.05";
  home.username = "willisk";
  home.homeDirectory = "/home/willisk";
  programs.home-manager.enable = true;

  home.file."bin/wlr-which-key-toggle.sh" = {
    source = ./wlr-which-key-toggle.sh;
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

  programs.fish = {
    enable = true;
    loginShellInit = ''
      if test (tty) = "/dev/tty1"; and not set -q DISPLAY; and not set -q WAYLAND_DISPLAY
        exec niri-session
      end
    '';
  };
  
  home.packages = with pkgs; [
    claude-code
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
    htop
    bat
    eza
    jq
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;
  xdg.configFile."niri/noctalia.kdl".source = ./noctalia.kdl;
  xdg.configFile."wlr-which-key/modal.yaml".source = ./wlr-which-key-modal.yaml;
}

