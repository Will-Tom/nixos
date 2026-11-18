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
      };
    };
  };
}
