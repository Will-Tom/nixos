{ inputs, ... }:
{
  # iets: faster evaluator (Rust) in front of the nix CLI. nix, nix-build,
  # nix-instantiate and nix-shell evaluate with iets and hand building and
  # anything it doesn't support to the real Nix, so nixos-rebuild evaluates
  # about 3x faster. Remove the import (and the flake input) to go back.
  imports = [ inputs.iets.nixosModules.default ];
  iets.classic.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
    auto-optimise-store = true;
    accept-flake-config = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  environment.persistence."/persist".directories = [
    "/root/.cache/nix"
  ];
}
