# tmpfs root; anything not listed under /persist is wiped on boot.
# Feature modules add their own paths to environment.persistence."/persist".
{ ... }:
{
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"
      "/etc/nixos"
      # DynamicUser service state
      { directory = "/var/lib/private"; mode = "0700"; }
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  services.journald.settings.Journal.Storage = "persistent";
  services.journald.settings.Journal.SystemMaxUse = "500M";
}
