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
        # Rebuild: build with nix-output-monitor's progress tree, show what
        # differs from the running system (nix-diff), then switch to it
        nrs = ''
          git -C /etc/nixos add -A
          set -l out $XDG_RUNTIME_DIR/nrs-result
          nom build "/etc/nixos#nixosConfigurations.$(hostname).config.system.build.toplevel" -o $out
          or return 1
          if test (readlink -f /run/current-system) = (readlink -f $out)
              echo "No changes from the running system"
          else
              nix-diff /run/current-system $out
          end
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
