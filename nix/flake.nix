{
  description = "KITT4SME cluster install & dev tools.";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-21.11";
    nixie = {
      url = "github:c0c0n3/nixie";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixie }:
    let
      buildWith = nixie.lib.flakes.mkOutputSetForCoreSystems nixpkgs;
      mkSysOutput = { system, sysPkgs }:
      let
        opa = sysPkgs.callPackage ./opa.nix {};
        kubeseal = sysPkgs.callPackage ./kubeseal.nix {};
      in {
        defaultPackage.${system} = with sysPkgs; buildEnv {
          name = "kitt4sme-cluster-shell";
          paths = [ git kubectl istioctl argocd kustomize opa kubeseal ];
        };
      };
    in
      buildWith mkSysOutput;
}
