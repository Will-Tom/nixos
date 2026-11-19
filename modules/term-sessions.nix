# Persistent terminal sessions: every terminal is a kitty window on a shpool
# shell, grouped into named sessions. Shells keep running when their window
# closes, and after a reboot every window that was open comes back on its
# workspace with its directory and scrollback (programs are not rerun).
# Managed from umbriel's SESSIONS mode (modal T), the noctalia launcher
# (/ts, plugin noctalia/plugins/term-sessions) and the fish command `se`
# (also over ssh, where it works in the current terminal). State lives in
# ~/.local/state/term-sessions.
{ config, pkgs, ... }:
let
  script = { source = ./term-sessions/term-sessions.sh; executable = true; };
  path = "PATH=/etc/profiles/per-user/${config.my.username}/bin:/run/current-system/sw/bin";
in
{
  home-manager.users.${config.my.username} = {
    home.packages = [ pkgs.shpool ];
    xdg.configFile."shpool/config.toml".source = ./term-sessions/shpool.toml;

    # One script, three names: term (new terminal), term-attach (runs in
    # the kitty window), term-sessions (everything else)
    home.file."bin/term" = script;
    home.file."bin/term-attach" = script;
    home.file."bin/term-sessions" = script;

    # `se t`, `se c name`, ...: the SESSIONS actions from a shell
    xdg.configFile."fish/functions/se.fish".source = ./term-sessions/se.fish;

    # shpool daemon, socket-activated (from shpool's own units)
    systemd.user.sockets.shpool = {
      Unit.Description = "Shpool Shell Session Pooler";
      Socket = {
        ListenStream = "%t/shpool/shpool.socket";
        SocketMode = "0600";
      };
      Install.WantedBy = [ "sockets.target" ];
    };
    systemd.user.services.shpool = {
      Unit = {
        Description = "Shpool - Shell Session Pool";
        Requires = [ "shpool.socket" ];
      };
      Service = {
        ExecStart = "${pkgs.shpool}/bin/shpool daemon";
        KillMode = "mixed";
        TimeoutStopSec = "2s";
        SendSIGHUP = true;
        # Shells get the normal login environment
        Environment = [ path ];
      };
    };

    # Snapshot cwd, scrollback and placement every 2 minutes
    systemd.user.services.term-sessions-save = {
      Unit.Description = "Save persistent terminal sessions";
      Service = {
        Type = "oneshot";
        Environment = [ path ];
        ExecStart = "%h/bin/term-sessions save";
      };
    };
    systemd.user.timers.term-sessions-save = {
      Unit.Description = "Save persistent terminal sessions";
      Timer = {
        OnActiveSec = "2min";
        OnUnitActiveSec = "2min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Reopen every terminal that was open, once per login
    systemd.user.services.term-sessions-restore = {
      Unit = {
        Description = "Restore persistent terminal sessions";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [ path ];
        # Wait for umbriel's IPC before placing windows
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 50); do umbriel outputs >/dev/null 2>&1 && exit 0; sleep 0.2; done'";
        ExecStart = "%h/bin/term-sessions restore";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
