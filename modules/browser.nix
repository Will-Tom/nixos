# Helium browser, degoog search, and the local nginx startpage
{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.helium-flake.nixosModules.default
    inputs.degoog.nixosModules.default
  ];

  nixpkgs.overlays = [ inputs.helium-flake.overlays.default ];

  programs.helium = {
    enable = true;
    flags = [
      "--ozone-platform-hint=auto"
      "--password-store=basic"
      "--enable-features=HardwareMediaKeyHandling" ];
  };

  programs.helium.policies = {
    HomepageLocation = "http://localhost:8080/";
    HomepageIsNewTabPage = false;
    NewTabPageLocation = "http://localhost:8080/";
    DownloadDirectory = "/home/${config.my.username}/Downloads/tmp";
  };

  sops.secrets."degoog_env" = {
    sopsFile = ../secrets/degoog.yaml;
  };

  services.degoog = {
    enable = true;
    environmentFile = config.sops.secrets."degoog_env".path;
    environment = {
      DEGOOG_BIND_ADDRESS = "127.0.0.1";  # default is 0.0.0.0, i.e. your whole LAN
      DEGOOG_PORT = 4444;
      DEGOOG_PUBLIC_INSTANCE = false;     # default is true
      DEGOOG_CURL_IMPERSONATE_LIB = "${pkgs.curl-impersonate}/lib/libcurl-impersonate.so";
    };
  };
  systemd.services.degoog.path = [ pkgs.curl-impersonate ];

  services.flaresolverr.enable = true;

  services.nginx = {
    enable = true;
    virtualHosts."startpage" = {
      listen = [ { addr = "127.0.0.1"; port = 8080; } ];
      root = ./browser/startpage;
    };
  };
}
