/*
  Helper interface:

    expectedPeers = import ./lib/cross-model-peers.nix { inherit lib; };
    expectedPeers packages

  The Compound Engineering review tokens a user environment must allow,
  sorted, derived from the `pname`s of its installed `packages` rather than
  from my.agents.crossModelPeers, so a module that installs a peer harness
  but drops its token fails. OpenCode and Pi have no entry, because Compound
  Engineering has no route for them, and neither has Antigravity, so none of
  them is in CROSS_MODEL_PEERS even where its package is installed.
*/
{ lib }:
packages:
let
  tokens = {
    claude-code = "claude";
  };
  pnames = map (p: p.pname or (lib.getName p)) packages;
in
lib.sort lib.lessThan (
  lib.unique (lib.attrValues (lib.filterAttrs (pname: _: lib.elem pname pnames) tokens))
)
