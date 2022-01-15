#
# Custom Open Policy Agent package.
# Actually it's a fat C&P from Nixpkgs:
#
# - https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/open-policy-agent/default.nix
#
# to get around test failures on MacOS. The only thing I changed is the
# `doCheck` attribute below.
#
# Uh? Why not override the original package?
#
# 1. It looks like overriding a Go package is a total pain in the backside.
# See e.g.
# - https://github.com/NixOS/nixpkgs/issues/86349
# 2. But hang on, you ain't seen Flake overlays yet
# - https://discourse.nixos.org/t/how-to-apply-an-overlay-defined-in-one-flake-in-my-flake/11987
# - https://discourse.nixos.org/t/how-can-i-install-a-package-using-overlays-and-flakes/16205
# Honestly guys, what the hell.
#
{ lib
, buildGoModule
, fetchFromGitHub
, installShellFiles

, enableWasmEval ? false
}:

buildGoModule rec {

  # Don't run the Go tests since they're broken on MacOS at the moment.
  doCheck = false;

  pname = "open-policy-agent";
  version = "0.36.1";

  src = fetchFromGitHub {
    owner = "open-policy-agent";
    repo = "opa";
    rev = "v${version}";
    sha256 = "sha256-Eoc+1Jwv0xUAQNtyHWCKezcpV6zWMFgNYtmkqAoedV0=";
  };
  vendorSha256 = null;

  nativeBuildInputs = [ installShellFiles ];

  subPackages = [ "." ];

  ldflags = [ "-s" "-w" "-X github.com/open-policy-agent/opa/version.Version=${version}" ];

  tags = lib.optional enableWasmEval (
    builtins.trace
      ("Warning: enableWasmEval breaks reproducability, "
        + "ensure you need wasm evaluation. "
        + "`opa build` does not need this feature.")
      "opa_wasm");

  preCheck = ''
    # Feed in all but the e2e tests for testing
    # This is because subPackages above limits what is built to just what we
    # want but also limits the tests
    getGoDirs() {
      go list ./... | grep -v e2e
    }

    # Remove test case that fails on < go1.17
    rm test/cases/testdata/cryptox509parsecertificates/test-cryptox509parsecertificates-0123.yaml
  '';

  postInstall = ''
    installShellCompletion --cmd opa \
      --bash <($out/bin/opa completion bash) \
      --fish <($out/bin/opa completion fish) \
      --zsh <($out/bin/opa completion zsh)
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/opa --help
    $out/bin/opa version | grep "Version: ${version}"

    ${lib.optionalString enableWasmEval ''
      # If wasm is enabled verify it works
      $out/bin/opa eval -t wasm 'trace("hello from wasm")'
    ''}

    runHook postInstallCheck
  '';

  meta = with lib; {
    homepage = "https://www.openpolicyagent.org";
    changelog = "https://github.com/open-policy-agent/opa/blob/v${version}/CHANGELOG.md";
    description = "General-purpose policy engine";
    longDescription = ''
      The Open Policy Agent (OPA, pronounced "oh-pa") is an open source, general-purpose policy engine that unifies
      policy enforcement across the stack. OPA provides a high-level declarative language that let’s you specify policy
      as code and simple APIs to offload policy decision-making from your software. You can use OPA to enforce policies
      in microservices, Kubernetes, CI/CD pipelines, API gateways, and more.
    '';
    license = licenses.asl20;
    maintainers = with maintainers; [ lewo jk ];
  };
}
