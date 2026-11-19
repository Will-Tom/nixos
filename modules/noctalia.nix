# Noctalia desktop shell (bar, launcher, notifications)
{ config, inputs, ... }:
{
  home-manager.users.${config.my.username} = {
    imports = [ inputs.noctalia.homeModules.default ];

    programs.noctalia = {
      enable = true;
      systemd.enable = true;

      settings = {
        theme = {
          mode = "dark";
          source = "community";
          community_palette = "Rosey AMOLED";
        };

        shell.launch_apps_as_systemd_services = true;
        # Password prompts for polkit (the dashboard's Accept button)
        shell.polkit_agent = true;

        # Local plugins (read-only path source in the store)
        plugins = {
          enabled = [ "willisk/submap-mode" "willisk/dashboard" "willisk/term-sessions" ];
          source = [{
            name = "local-nix";
            kind = "path";
            location = "${./noctalia/plugins}";
            enabled = true;
          }];
        };

        # Bar text with the active umbriel submap. Add "mode" to a bar section
        # (Settings → Bar); the bar layout itself is GUI-managed.
        widget.mode.type = "willisk/submap-mode:mode";

        # Dashboard widgets; each opens its own panel on click
        widget.updates.type = "willisk/dashboard:updates";
        widget.filesystem.type = "willisk/dashboard:filesystem";
        widget.git.type = "willisk/dashboard:git";
      };
    };
  };
}
