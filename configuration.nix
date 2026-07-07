{ config, pkgs, lib, inputs, ... }:
{
  imports =
    [ ./hardware-configuration.nix
      inputs.helium-flake.nixosModules.default
    ];

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  
  system.activationScripts.gitBackup = {
    text = ''
      export HOME=/root

      if [ ! -f /root/.ssh/nixos_backup_key ]; then
        mkdir -p /root/.ssh
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /root/.ssh/nixos_backup_key -N ""
        echo "=================================================="
        echo "New deploy key generated. Add this to GitHub"
        echo "(repo Settings -> Deploy keys -> Add, allow write):"
        cat /root/.ssh/nixos_backup_key.pub
        echo "=================================================="
      fi

      cd /etc/nixos

      if [ ! -d .git ]; then
        ${pkgs.git}/bin/git init
        ${pkgs.git}/bin/git config user.email "willthompson696@gmail.com"
        ${pkgs.git}/bin/git config user.name "Will Thompson"
        ${pkgs.git}/bin/git branch -M main
        ${pkgs.git}/bin/git remote add origin git@github.com:Will-Tom/nixos.git
      fi

      ${pkgs.git}/bin/git add -A
      if ! ${pkgs.git}/bin/git diff --cached --quiet; then
        ${pkgs.git}/bin/git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"
        GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /root/.ssh/nixos_backup_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" ${pkgs.git}/bin/git push origin main || true
      fi
    '';
  };

  system.autoUpgrade = {
    enable = true;
    flake = "path:/etc/nixos";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
      "-L"
    ];
    allowReboot = false;
  };

  systemd.timers.nixos-upgrade.timerConfig = {
    OnCalendar = lib.mkForce "";
    OnBootSec = "2min";
    Persistent = lib.mkForce false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.auto-optimise-store = true;
  
  nixpkgs.overlays = [ inputs.helium-flake.overlays.default ];
  programs.helium = {
    enable = true;
    flags = [ "--ozone-platform-hint=auto" ];
  };
  systemd.services.keyd.serviceConfig.ProtectHome = lib.mkForce false;
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main.capslock = "overload(leader, esc)";

        leader = {
          space = "command(fuzzel)";
          h = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-column-left)";
          j = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-window-down)";
          k = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-window-up)";
          l = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-column-right)";
          g = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-column-first)";
          semicolon = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-column-last)";
          u = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-workspace-up)";
          d = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-workspace-down)";
          left = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-monitor-left)";
          right = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-monitor-right)";
          up = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-monitor-up)";
          down = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-monitor-down)";
          t = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd toggle-window-floating)";
          b = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-window-previous)";
          o = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd toggle-overview)";
          q = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd close-window)";
          w = "layer(leader-w)";
          r = "layer(leader-r)";
          m = "layer(leader-m)";
        };

        "leader+shift" = {
          h = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-left)";
          j = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-window-down)";
          k = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-window-up)";
          l = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-right)";
          g = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-first)";
          semicolon = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-last)";
          u = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-workspace-up)";
          d = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-workspace-down)";
        };

        "leader-w" = {
          "1" = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-workspace 1)";
          "2" = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-workspace 2)";
          "3" = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd focus-workspace 3)";
          o = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd toggle-overview)";
        };

        "leader-r" = {
          "1" = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd maximize-column)";
          "2" = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd set-column-width 50%)";
          "3" = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd set-column-width 33%)";
          f = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd fullscreen-window)";
          h = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd set-column-width -10%)";
          l = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd set-column-width +10%)";
          j = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd set-window-height -10%)";
          k = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd set-window-height +10%)";
        };

        "leader-m" = {
          left = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-monitor-left)";
          right = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-monitor-right)";
          up = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-monitor-up)";
          down = "command(/nix/store/mkc42hm6s2cqb4yjbgly3a35ibri3ncf-niri-cmd/bin/niri-cmd move-column-to-monitor-down)";
        };
      };
    };
  };

  programs.helium.policies = {
    HomepageLocation = "http://localhost:8080/";
    HomepageIsNewTabPage = false;
    NewTabPageLocation = "http://localhost:8080/";
  };
  services.nginx = {
    enable = true;
    virtualHosts."startpage" = {
      listen = [ { addr = "127.0.0.1"; port = 8080; } ];
      root = ./startpage;
    };
  };
  programs.niri.enable = true;
  services.displayManager.ly.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  programs.fish.enable = true;
  users.users."willisk" = {
    isNormalUser = true;
    description = "Will Thompson";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [ git ];
  system.stateVersion = "26.05";
}

