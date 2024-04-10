#################### DevShell ####################
#
# Custom shell for bootstrapping on new hosts, modifying nix-config, and secrets management

{ pkgs ? import <nixpkgs> {} }:
{
  default = pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      git
      hugo
      awscli2
    ];
  };
}
