{ pkgs, inputs, ... }:
let
  niriCmd = pkgs.writeShellScriptBin "niri-cmd" ''
    {
      echo "=== $(date) ==="
      echo "UID: $(id)"
      echo "XDG_RUNTIME_DIR was: $XDG_RUNTIME_DIR"
      export XDG_RUNTIME_DIR=/run/user/1000
      echo "Contents of /run/user/1000:"
      ls -la /run/user/1000 2>&1
      for f in /run/user/1000/niri.wayland-*.sock; do
        NIRI_SOCKET="$f"
        break
      done
      export NIRI_SOCKET
      echo "NIRI_SOCKET resolved to: $NIRI_SOCKET"
      echo "Attempting niri msg action $@"
      ${pkgs.niri}/bin/niri msg action "$@" 2>&1
      echo "Exit code: $?"
    } >> /tmp/niri-cmd-debug.log 2>&1
  '';
in
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
    niriCmd
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

