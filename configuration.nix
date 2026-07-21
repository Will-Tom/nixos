{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.helium-flake.nixosModules.default
  ];

  ############################################
  ## Nix / Flakes
  ############################################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
    auto-optimise-store = true;
    accept-flake-config = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
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

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ inputs.helium-flake.overlays.default ];

  ############################################
  ## Boot / Filesystem
  ############################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.systemd.enable = true;

  fileSystems."/persist".neededForBoot = true;


  ############################################
  ## System identity / Locale
  ############################################
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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

  system.stateVersion = "26.05";

  ############################################
  ## Secrets (sops-nix)
  ############################################
  # sops.defaultSopsFile = ./secrets.yaml;
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";

  sops.secrets."nixos_backup_key" = {
    sopsFile = ./secrets/nixos_backup_key.enc;
    format = "binary";
    owner = "root";
    group = "users";
    mode = "0440";
    path = "/etc/secrets/nixos_backup_key";
  };

  sops.secrets."willisk_password_hash" = {
    sopsFile = ./secrets/user_password.yaml;
    neededForUsers = true;
  };
  ############################################
  ## Impermanence
  ############################################
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
  services.journald.extraConfig = ''
    SystemMaxUse=500M
  '';
  ############################################
  ## Storage: TRIM / Swap / Snapshots
  ############################################
  services.fstrim.enable = true;

  systemd.tmpfiles.rules = [
    "d /persist/.snapshots 0750 root root -"
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.btrbk.instances."persist" = {
    onCalendar = "hourly";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "48h 14d 6m";
      volume."/persist" = {
        subvolume = ".";
        snapshot_dir = "/persist/.snapshots";
      };
    };
  };

 services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/nix" "/persist" ];
  };

  ############################################
  ## Users
  ############################################
  users.users."willisk" = {
    isNormalUser = true;
    description = "Will Thompson";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets."willisk_password_hash".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGm8b8/LQKQRi8Zw33danKnB4p1ICA1x1lDLb9+jxZNm"
    ];
  };

  ############################################
  ## Networking / Remote access
  ############################################
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  
  networking.networkmanager.dns = "none";
  networking.resolvconf.enable = false;
  networking.nameservers = ["1.1.1.1" "1.0.0.1"];
  environment.etc."resolv.conf".text = ''
    nameserver 1.1.1.1
    nameserver 1.0.0.1
    options edns0
    '';
  ############################################
  ## Desktop: display manager / compositor
  ############################################
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

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };
  
  security.pam.services.swaylock = {};
  services.gnome.gnome-keyring.enable = true;

  programs.niri.enable = true;
  systemd.user.services.niri.enableDefaultPath = false;

  ############################################
  ## Desktop: browser / startpage
  ############################################
  programs.helium = {
    enable = true;
    flags = [ "--ozone-platform-hint=auto" ];
  };

  programs.helium.policies = {
    HomepageLocation = "http://localhost:8080/";
    HomepageIsNewTabPage = false;
    NewTabPageLocation = "http://localhost:8080/";
    DownloadDirectory = "/home/willisk/Downloads/tmp";
  };

  services.nginx = {
    enable = true;
    virtualHosts."startpage" = {
      listen = [ { addr = "127.0.0.1"; port = 8080; } ];
      root = ./startpage;
    };
  };

  ############################################
  ## Audio / Graphics
  ############################################
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  ############################################
  ## Gaming
  ############################################
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  ############################################
  ## Shell
  ############################################
  programs.fish.enable = true;

  ############################################
  ## Dotfiles auto-backup to GitHub
  ############################################
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
        ${pkgs.git}/bin/git pull --rebase origin main || true
        ${pkgs.git}/bin/git push origin main || true
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
  ############################################
  ## System packages
  ############################################
  environment.systemPackages = with pkgs; [ git nodejs_22 sops ssh-to-age ];
}

