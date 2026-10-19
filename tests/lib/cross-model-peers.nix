/*
  Helper interface:

    expectedPeers = import ./lib/cross-model-peers.nix { inherit lib; };
    expectedPeers kind packages

  The Compound Engineering review tokens a user environment of host kind
  `kind` must allow, sorted, derived from the `pname`s of its installed
  `packages` rather than from my.agents.crossModelPeers, so a module that
  installs a harness but drops its token fails. Antigravity counts only on
  darwin: CE finds that route through agy_acp_server.par, which
  antigravity-acp-path provides, and on Linux the allowlist leaves it out.
*/
{ lib }:
kind: packages:
let
  tokens = {
    claude-code = "claude";
    opencode = "opencode";
    grok-build = "grok";
  }
  // lib.optionalAttrs (kind == "darwin") { antigravity-acp-path = "antigravity"; };
  pnames = map (p: p.pname or (lib.getName p)) packages;
in
lib.sort lib.lessThan (
  lib.unique (lib.attrValues (lib.filterAttrs (pname: _: lib.elem pname pnames) tokens))
)
