{
  description = "Dev shell for wardtalks.com (Hugo site)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # terraform is licensed under BSL 1.1, which nixpkgs treats as unfree.
          config.allowUnfree = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            git
            hugo
            awscli2
            awsume
            terraform
          ];

          # `awsume` must be sourced (not exec'd) so it can export AWS_* env
          # vars into the calling shell; this function shadows the plain
          # script of the same name that's on PATH from the package above.
          shellHook = ''
            awsume() { source "${pkgs.awsume}/bin/awsume" "$@"; }
          '';
        };
      });
}
