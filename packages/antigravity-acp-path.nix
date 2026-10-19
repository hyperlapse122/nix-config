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
  the nixpkgs one. When GEMINI_HOME is a private scratch home that Compound
  Engineering created for a run and holds no token yet, the wrapper copies
  ~/.gemini/antigravity-acp/acp_token.json into it with mode 0600 before
  execing the runtime.

  The runtime defaults to packages/antigravity-acp-release.json, which
  scripts/antigravity-acp-release keeps at Google's newest complete release.
  T3 Code's managed layout keeps the runtime its own pin names.
*/
{
  pkgs,
  runtime ? import ./antigravity-acp.nix {
    inherit pkgs;
    pins = (builtins.fromJSON (builtins.readFile ./antigravity-acp-release.json)).platforms;
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
    gemini_home=''${GEMINI_HOME:-}
    while [ "''${gemini_home%/}" != "$gemini_home" ]; do
      gemini_home=''${gemini_home%/}
    done
    case $gemini_home in
      */gemini-home)
        parent=''${gemini_home%/gemini-home}
        while [ "''${parent%/}" != "$parent" ]; do
          parent=''${parent%/}
        done
        case ''${parent##*/} in
          xmodel-cr-scratch-* | xmodel-doc-scratch-* | xmodel-pov-peer-* | ce-work-model-check-* | ce-work-adapter-*)
            acp_dir="$gemini_home/antigravity-acp"
            if [ -d "$parent" ] && [ ! -L "$parent" ] && [ -O "$parent" ] \
              && [ -d "$gemini_home" ] && [ ! -L "$gemini_home" ] && [ -O "$gemini_home" ] \
              && [ -d "$acp_dir" ] && [ ! -L "$acp_dir" ] && [ -O "$acp_dir" ] \
              && [ "$(${pkgs.coreutils}/bin/stat -c %a "$parent" 2>/dev/null)" = 700 ]; then
              source="''${HOME:-}/.gemini/antigravity-acp/acp_token.json"
              target="$acp_dir/acp_token.json"
              if [ -n "''${HOME:-}" ] && [ -f "$source" ] && [ ! -L "$source" ] \
                && ! { [ -f "$target" ] && [ ! -L "$target" ]; }; then
                had_target=0
                if [ -e "$target" ] || [ -L "$target" ]; then
                  had_target=1
                fi
                if ! (
                  umask 077
                  set -C
                  ${pkgs.coreutils}/bin/cat "$source" > "$target"
                ) 2>/dev/null; then
                  if [ "$had_target" -eq 0 ] && [ -f "$target" ] && [ ! -L "$target" ]; then
                    ${pkgs.coreutils}/bin/rm -f "$target"
                  fi
                  printf 'agy_acp_server.par: could not copy the ~/.gemini sign-in into GEMINI_HOME\n' >&2
                fi
              fi
            fi
            ;;
        esac
        ;;
    esac
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
