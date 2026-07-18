{ config, pkgs, lib, inputs, ... }:
{
  imports =
    [ ./hardware-configuration.nix
      inputs.helium-flake.nixosModules.default
    ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };
  
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/persist".neededForBoot = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
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

  boot.initrd.systemd.enable = true;

  #sops.defaultSopsFile = ./secrets.yaml;
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";

  sops.secrets."nixos_backup_key" = {
      sopsFile = ./secrets/nixos_backup_key.enc;
      format = "binary";
      owner = "root";
      mode = "0400";
      path = "/root/.ssh/nixos_backup_key";
    };


  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/sops-nix"
      "/var/lib/systemd/timers"
      "/etc/nixos"
      "/root/.cache/nix"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    users.willisk.directories = [
      "Downloads" "Documents" "Projects" "Videos" "Pictures" ".config" ".local/share"
      ".ssh" ".local/state"
    ];
  };

  services.journald.storage = "persistent";
  
  # Remove system.activationScripts.gitBackup entirely, replace with:
  systemd.services.gitBackup = {
    description = "Auto-backup /etc/nixos to GitHub";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "30s";
    };
    script = ''
    set -euo pipefail
    export HOME=/root
    ${pkgs.git}/bin/git config --global --add safe.directory /etc/nixos
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${config.sops.secrets."nixos_backup_key".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

    if [ ! -f /etc/nixos/flake.nix ]; then
      echo "No flake found in /etc/nixos — cloning from GitHub..."
      rm -rf /etc/nixos
      ${pkgs.git}/bin/git clone git@github.com:Will-Tom/nixos.git /etc/nixos
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
      ${pkgs.git}/bin/git pull --rebase origin main || true
      ${pkgs.git}/bin/git push origin main || true
    fi
  '';
    wantedBy = [ "multi-user.target" ];
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
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  programs.fish.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = "willisk";
      };
      default_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = "willisk";
      };
    };
  };
  
  systemd.user.services.niri.enableDefaultPath = false;

  
  users.users."willisk" = {
    isNormalUser = true;
    description = "Will Thompson";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGm8b8/LQKQRi8Zw33danKnB4p1ICA1x1lDLb9+jxZNm"
    ];
  };
  
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [ git nodejs_22 sops ssh-to-age];
  system.stateVersion = "26.05";
}



