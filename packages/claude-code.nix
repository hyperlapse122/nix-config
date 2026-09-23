{ pkgs }:

let
  manifest = builtins.fromJSON (builtins.readFile ./claude-code-manifest.json);
in
pkgs.claude-code.override { inherit manifest; }
