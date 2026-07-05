{ config, pkgs, inputs, ... }:
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
      cd /etc/nixos
      ${pkgs.git}/bin/git add -A
      if ! ${pkgs.git}/bin/git diff --cached --quiet; then
        ${pkgs.git}/bin/git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"
        GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /root/.ssh/nixos_backup_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" ${pkgs.git}/bin/git push origin main || true
      fi
    '';
  };
  nixpkgs.overlays = [ inputs.helium-flake.overlays.default ];
  programs.helium = {
    enable = true;
    flags = [ "--ozone-platform-hint=auto" ];
    policies = {
      ExtensionSettings = {
        "hfjbmagddngcpeloejdejnfgbamkjaeg" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
      };
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
