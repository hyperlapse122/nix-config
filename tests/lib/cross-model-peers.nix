/*
  Helper interface:

    expectedPeers = import ./lib/cross-model-peers.nix { inherit lib; };
    expectedPeers packages

  The Compound Engineering review tokens a user environment must allow,
  sorted, derived from the `pname`s of its installed `packages` rather than
  from my.agents.crossModelPeers, so a module that installs a peer harness
  but drops its token fails. OpenCode is excluded from CROSS_MODEL_PEERS, so
  its package maps to no token. Antigravity counts wherever
  antigravity-acp-path is installed: CE finds that route through
  agy_acp_server.par, and the PATH wrapper seeds the ~/.gemini sign-in on
  every host kind.
*/
{ lib }:
packages:
let
  tokens = {
    claude-code = "claude";
    grok-build = "grok";
    antigravity-acp-path = "antigravity";
  };
  pnames = map (p: p.pname or (lib.getName p)) packages;
in
lib.sort lib.lessThan (
  lib.unique (lib.attrValues (lib.filterAttrs (pname: _: lib.elem pname pnames) tokens))
)
