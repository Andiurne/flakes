{
        description = "swayimg home-manager module with lua config";

        inputs = {
                nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
                home-manager.url = "github:nix-community/home-manager";
                home-manager.inputs.nixpkgs.follows = "nixpkgs";
                luaUtils = {
                        url = "github:Andiurne/flakes?dir=luaUtils";
                        inputs.nixpkgs.follows = "nixpkgs";
                };
        };


        outputs = {self, nixpkgs, luaUtils, ...}:
        let
                allSystems = [
                        "x86_64-linux" # 64-bit Intel/AMD Linux
                        "aarch64-linux" # 64-bit ARM Linux
                        "x86_64-darwin" # 64-bit Intel macOS
                        "aarch64-darwin" # 64-bit ARM macOS
                ];
                forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
                        pkgs = import nixpkgs {inherit system; };
                        });
                swayimgVersion = "v5.5";
        in
        {
                packages = forAllSystems ({pkgs}: {
                        default = pkgs.swayimg.overrideAttrs {
                                src = pkgs.fetchFromGithub {
                                        owner = "artemsen";
                                        repo = "swayimg";
                                        rev = swayimgVersion;
                                        hash = "sha256-PaxVcuEafLdUETSG78lGSaDukPv/2m1TUbfvpBZTT40=";
                                };
                                version = swayimgVersion;
                        };
                });

                homeModules = {
                        default = self.homeModules."v5.5";
                        ${swayimgVersion} = import ./hm-module.nix luaUtils;
                };
        };
}
