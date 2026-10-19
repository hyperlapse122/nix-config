/*
  The Antigravity ACP runtime's two binaries in one bin/ directory on PATH,
  for Compound Engineering's Antigravity route: it finds the runtime with
  `command -v agy_acp_server.par` and takes localharness_external from the
  same directory.

  agy_acp_server.par is a wrapper that execs the runtime by its absolute store
  path. The .par loads its embedded archive through argv[0], and acpx spawns
  it by bare name, so a symlink would hand it `agy_acp_server.par`; nothing
  may pass `-a` either. The Linux .par embeds an OpenSSL whose default CA path
  does not exist on NixOS, and a session without SSL_CERT_FILE hangs after
  session/prompt, so on Linux the wrapper supplies a bundle when the caller set
  none: the first system bundle that exists, so local CAs still apply, then
  the nixpkgs one.
*/
{
  pkgs,
  runtime ? import ./antigravity-acp.nix {
    inherit pkgs;
    pins = (builtins.fromJSON (builtins.readFile ./t3code-release.json)).antigravity;
  },
  caBundles ? [
    "/etc/ssl/certs/ca-certificates.crt"
    "/etc/pki/tls/certs/ca-bundle.crt"
    "/etc/ssl/cert.pem"
    "/etc/ssl/ca-bundle.pem"
    "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ],
}:

let
  inherit (pkgs) lib;
  inherit (runtime.passthru.pin) executable harness;
  dir = "${runtime}/libexec/antigravity-acp";

  wrapper = pkgs.writeShellScript executable.name ''
    ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      if [ -z "''${SSL_CERT_FILE:-}" ]; then
        for bundle in ${lib.escapeShellArgs caBundles}; do
          if [ -f "$bundle" ]; then
            export SSL_CERT_FILE="$bundle"
            break
          fi
        done
      fi
    ''}
    exec ${dir}/${executable.name} "$@"
  '';
in
pkgs.runCommand "antigravity-acp-path-${runtime.version}"
  {
    pname = "antigravity-acp-path";
    inherit (runtime) version;
    meta = {
      description = "Antigravity ACP runtime on PATH for Compound Engineering";
      inherit (runtime.meta) homepage license platforms;
    };
  }
  ''
    mkdir -p $out/bin
    install -m 555 ${wrapper} $out/bin/${executable.name}
    ln -s ${dir}/${harness.name} $out/bin/${harness.name}
  ''
