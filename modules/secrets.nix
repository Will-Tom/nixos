# sops-nix setup. Each secret is declared in the module that uses it.
{ pkgs, ... }:
{
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  environment.systemPackages = with pkgs; [ sops ssh-to-age ];

  environment.persistence."/persist".directories = [
    "/var/lib/sops-nix"
  ];
}
