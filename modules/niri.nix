# niri compositor: session, config, and the wlr-which-key modal keymap.
# Not imported anymore (umbriel.nix replaced it); kept for switching back.
{ config, pkgs, ... }:
let
  script = path: { source = path; executable = true; };
in
{
  programs.niri.enable = true;
  systemd.user.services.niri.enableDefaultPath =  false;

  services.greetd.settings = {
    initial_session.command = "${config.programs.niri.package}/bin/niri-session";
    default_session.command = "${config.programs.niri.package}/bin/niri-session";
  };

  home-manager.users.${config.my.username} = {
    xdg.configFile."niri/config.kdl".source = ./niri/niri-config.kdl;
    xdg.configFile."wlr-which-key/modal.yaml".source = ./niri/wlr-which-key-modal.yaml;

    home.file."bin/wlr-which-key-warp.sh"   = script ./niri/wlr-which-key-warp.sh;
    home.file."bin/wlr-which-key-toggle.sh" = script ./niri/wlr-which-key-toggle.sh;
    home.file."bin/wlr-which-key-home.sh"   = script ./niri/wlr-which-key-home.sh;
    home.file."bin/niri-fullscreen-toggle.sh" = script ./niri/niri-fullscreen-toggle.sh;
    home.file."bin/niri-mark-set.sh"        = script ./niri/niri-mark-set.sh;
    home.file."bin/niri-mark-jump.sh"       = script ./niri/niri-mark-jump.sh;
    home.file."bin/float-to-region.sh"      = script ./niri/float-to-region.sh;

    # MODAL badge + screen border while wlr-which-key is open
    home.file."bin/eww-mode-watcher.sh" = script ./niri/eww-mode-watcher.sh;
    systemd.user.services.eww-mode-watcher = {
      Unit = {
        Description = "wlr-which-key mode indicator watcher";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" "eww-daemon.service" ];
      };
      Service = {
        ExecStart = "/home/willisk/bin/eww-mode-watcher.sh";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.packages = with pkgs; [
      wlr-which-key
      xwayland-satellite
    ];
  };
}
