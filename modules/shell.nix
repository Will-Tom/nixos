{ config, ... }:
{
  programs.fish.enable = true;

  home-manager.users.${config.my.username} = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;
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
      interactiveShellInit = builtins.readFile ./shell/fish-config.fish;
    };
  };
}
