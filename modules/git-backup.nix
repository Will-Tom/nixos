# Dotfiles auto-backup to GitHub
{ config, pkgs, lib, ... }:
{
  sops.secrets."nixos_backup_key" = {
    sopsFile = ../secrets/nixos_backup_key.enc;
    format = "binary";
    owner = "root";
    group = "users";
    mode = "0440";
    path = "/etc/secrets/nixos_backup_key";
  };

  systemd.services = {
    gitBackup = {
      description = "Auto-backup /etc/nixos to GitHub";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "willisk";
        TimeoutStartSec = "30s";
      };
      script = ''
        set -euo pipefail
        export HOME=/home/willisk
        ${pkgs.git}/bin/git config --global --add safe.directory /etc/nixos
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${config.sops.secrets."nixos_backup_key".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
        if [ ! -f /etc/nixos/flake.nix ]; then
          echo "No flake found in /etc/nixos — cloning from GitHub..."
          rm -rf /etc/nixos
          ${pkgs.git}/bin/git clone git@github.com:Will-Tom/nixos.git /etc/nixos
        fi
        cd /etc/nixos
        
        ${pkgs.git}/bin/git config user.email "willthompson696@gmail.com"
        ${pkgs.git}/bin/git config user.name "Will Thompson"
        if [ ! -d .git ]; then
          ${pkgs.git}/bin/git init
          ${pkgs.git}/bin/git branch -M main
          ${pkgs.git}/bin/git remote add origin git@github.com:Will-Tom/nixos.git
        fi
        ${pkgs.git}/bin/git add -A
        if ! ${pkgs.git}/bin/git diff --cached --quiet; then
          ${pkgs.git}/bin/git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        # Back up whichever branch is checked out (work often happens on a
        # branch, e.g. umbriel). Only main is synced from GitHub first; other
        # branches are just pushed under their own name.
        branch=$(${pkgs.git}/bin/git branch --show-current)
        if [ "$branch" = main ]; then
          ${pkgs.git}/bin/git pull --rebase origin main || true
        fi
        if [ -n "$branch" ]; then
          ${pkgs.git}/bin/git push origin "$branch" || true
        fi
      '';
      wantedBy = [ "multi-user.target" ];
    };
  } // (let
    repos = {
      "ObsidianBackup" = "git@github.com:Will-Tom/ObsidianBackup.git";
      "GalaxySlayer" = "git@github.com:Will-Tom/GalaxySlayer.git";
    };
  in lib.mapAttrs' (name: url: lib.nameValuePair "gitBackup-${name}" {
    description = "Auto-sync ${name} with GitHub";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "willisk";
      TimeoutStartSec = "30s";
    };
    script = ''
      set -euo pipefail
      export HOME=/home/willisk
      REPO_DIR=/home/willisk/Projects/${name}
      export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${config.sops.secrets."nixos_backup_key".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
      ${pkgs.git}/bin/git config --global --add safe.directory "$REPO_DIR"
      if [ ! -d "$REPO_DIR/.git" ]; then
        mkdir -p /home/willisk/Projects
        ${pkgs.git}/bin/git clone ${url} "$REPO_DIR"
      fi
      cd "$REPO_DIR"
      ${pkgs.git}/bin/git config user.email "willthompson696@gmail.com"
      ${pkgs.git}/bin/git config user.name "Will Thompson"
      ${pkgs.git}/bin/git add -A
      if ! ${pkgs.git}/bin/git diff --cached --quiet; then
        ${pkgs.git}/bin/git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"
      fi
      ${pkgs.git}/bin/git pull --rebase origin main || true
      ${pkgs.git}/bin/git push origin main || true
    '';
  }) repos);
  systemd.timers.gitBackup-ObsidianBackup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
    };
  };

  systemd.timers.gitBackup-GalaxySlayer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
    };
  };
}
