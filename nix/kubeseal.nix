#
# Custom Sealed Secrets package.
# Actually it's a fat C&P from Nixpkgs:
#
# - https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/kubeseal/default.nix
#
# The only thing I changed is the `version` attribute below.
# Uh? Wot?! Why not just use an expression like
#
#   kubeseal = pkgs.kubeseal.overrideAttrs ( old: rec {
#     version = "0.17.3";
#     ...
#   });
#
# Cuz it don't flippin work? If you try that, you actually get whatever
# version is in your Nixpkgs---`0.16.0` in my case. See my rant about
# overriding Go packages in `opa.nix`.
#
{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "kubeseal";
  version = "0.17.3";

  src = fetchFromGitHub {
    owner = "bitnami-labs";
    repo = "sealed-secrets";
    rev = "v${version}";
    sha256 = "sha256-7u7lsMeeZOUGn8eb8sjV9Td+XNEUPDvbSaITdp1JTf4=";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "cmd/kubeseal" ];

  ldflags = [ "-s" "-w" "-X main.VERSION=${version}" ];

  meta = with lib; {
    description = "A Kubernetes controller and tool for one-way encrypted Secrets";
    homepage = "https://github.com/bitnami-labs/sealed-secrets";
    license = licenses.asl20;
    maintainers = with maintainers; [ groodt ];
  };
}
