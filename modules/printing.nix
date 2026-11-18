{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint pkgs.cups-filters ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
