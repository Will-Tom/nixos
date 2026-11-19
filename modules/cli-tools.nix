{ config, pkgs, ... }:
let
  username = config.my.username;
in
{
  environment.systemPackages = with pkgs; [ git nodejs_22 ];

  environment.persistence."/persist".users.${username} = {
    directories = [ ".claude" ];
    files = [ ".claude.json" ];
  };

  home-manager.users.${username} = {
    programs.helix = {
      enable = true;
      defaultEditor = true;
    };
    xdg.configFile."helix/config.toml".source = ./cli-tools/helix-config.toml;
    xdg.configFile."helix/themes/ao-glass.toml".source = ./cli-tools/helix-ao-glass.toml;

    home.packages = with pkgs; [
      claude-code
      nvd
      nix-output-monitor
      nix-diff
      fastfetch
      bitwarden-cli
      uv
      yazi
      btop
      bat
      eza
      jq
    ];
  };
}
