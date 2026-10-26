{ pkgs }:

let
  manifest = builtins.fromJSON (builtins.readFile ./claude-code-manifest.json);
in
(pkgs.claude-code.override { inherit manifest; }).overrideAttrs (old: {
  # The native runtime's system store misses public issuers on macOS even when
  # curl trusts them. Keep system-only trust and supplement it with macOS's PEM
  # bundle; an explicitly supplied corporate CA bundle still takes precedence.
  postInstall =
    (old.postInstall or "")
    + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      wrapProgram $out/bin/claude --set-default NODE_EXTRA_CA_CERTS /etc/ssl/cert.pem
    '';
})
