{ pkgs, inputs, ... }:
{
  home.stateVersion = "26.05";
  home.username = "willisk";
  home.homeDirectory = "/home/willisk";
  programs.home-manager.enable = true;

  systemd.user.tmpfiles.rules = [
    "D %h/Downloads/tmp 0755 - - -"
    "D %h/Pictures/screenshots/tmp 0755 - - -"
  ];
  
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
  home.file."bin/float-to-region.sh" = {
    source = ./float-to-region.sh;
    executable = true;
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
  
  home.packages = with pkgs; [
    fastfetch
    swaylock
    bitwarden-cli
    ghostty
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
  xdg.configFile."niri/noctalia.kdl".source = ./noctalia.kdl;
  xdg.configFile."wlr-which-key/modal.yaml".source = ./wlr-which-key-modal.yaml;
}

