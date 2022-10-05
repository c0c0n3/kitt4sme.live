{
  description = "KITT4SME cluster install & dev tools.";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-21.11";
    nixpkgs-22-05.url = "github:NixOs/nixpkgs/nixos-22.05";
    nixie = {
      url = "github:c0c0n3/nixie";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-22-05, nixie }:
    let
      buildWith = nixie.lib.flakes.mkOutputSetForCoreSystems nixpkgs;
      mkSysOutput = { system, sysPkgs }:
      let
        opa = sysPkgs.callPackage ./opa.nix {};
        # kubeseal = sysPkgs.callPackage ./kubeseal.nix {};  # NOTE (1)
        kubeseal = nixpkgs-22-05.legacyPackages.${system}.kubeseal;
        # ^ Nixpkgs 22.05 comes w/ kubeseal 0.17.5, same as kubeseal.nix
      in {
        defaultPackage.${system} = with sysPkgs; buildEnv {
          name = "kitt4sme-cluster-shell";
          paths = [ git kubectl istioctl argocd kustomize opa kubeseal ];
        };
      };
    in
      buildWith mkSysOutput;
}
# NOTE
# 1. kubeseal. Ideally we'd build it off Nixpkgs 21.11, our main package
# source at the moment. In fact, that'd save quite a bit of build time
# and almost 4GB space in the Nix store---on MacOS. That's why we whipped
# together that kubeseal.nix recipe. But it looks like we did it too quickly,
# as it breaks on some Linux flavours, see
# - https://github.com/c0c0n3/kitt4sme.live/issues/167
