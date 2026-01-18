# setup

home-manager flake.nix:
```
{
  description = "Home Manager configuration of saktidc";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixe.url = "github:sakti/nixe";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nixe, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."saktidc" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
         ./home.nix
         nixe.nixosModules.default
        ];
      };
    };
}
```


home.nix:
```
...

  services.nixe = {
    enable = true;
  };
...
```
