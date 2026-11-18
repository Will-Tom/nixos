# TRIM, swap, btrfs snapshots/scrub, removable media
{ config, ... }:
{
  services.fstrim.enable = true;

  systemd.tmpfiles.rules = [
    "d /persist/.snapshots 0755 root root -"
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

  services.udisks2.enable = true; #USB auto mount

  home-manager.users.${config.my.username}.services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };
}
