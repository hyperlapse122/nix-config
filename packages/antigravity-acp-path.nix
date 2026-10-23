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
  execing the runtime. It also links each skill in `skills` from
  ~/.gemini/antigravity-cli/skills/ into the scratch home's
  antigravity-cli/skills/ when the source skill exists. Home Manager passes
  the names home/h82/agents/skills.nix links there; the default lists the
  skills this flake declares, sorted as `lib.attrNames` sorts them, for
  callers outside Home Manager; tests/t3code-traits.nix compares the two.

  The runtime defaults to packages/antigravity-acp-release.json, which
  scripts/antigravity-acp-release keeps at Google's newest complete release.
  T3 Code's managed layout keeps the runtime its own pin names.
*/
{
  pkgs,
  skills ? [
    "grammar-checker"
    "humanizer"
    "style-guide"
    "test-audit"
  ],
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
  coreutils = "${pkgs.coreutils}/bin";

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
    strip_slashes() {
      local value=''${!1}
      while [ "''${value%/}" != "$value" ]; do
        value=''${value%/}
      done
      printf -v "$1" '%s' "$value"
    }

    private_dir() {
      [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ]
    }

    seed_acp_token() {
      local gemini_home=''${GEMINI_HOME:-} parent acp_dir token_source token_target tmp
      strip_slashes gemini_home
      case $gemini_home in
        */gemini-home) ;;
        *) return 0 ;;
      esac
      parent=''${gemini_home%/gemini-home}
      strip_slashes parent
      case ''${parent##*/} in
        xmodel-cr-scratch-* | xmodel-doc-scratch-* | xmodel-pov-peer-* | ce-work-model-check-* | ce-work-adapter-*) ;;
        *) return 0 ;;
      esac
      acp_dir=$gemini_home/antigravity-acp
      private_dir "$parent" && private_dir "$gemini_home" && private_dir "$acp_dir" || return 0
      [ "$(${coreutils}/stat -c %a "$parent" 2>/dev/null)" = 700 ] || return 0

      [ -n "''${HOME:-}" ] || return 0
      token_source=$HOME/.gemini/antigravity-acp/acp_token.json
      token_target=$acp_dir/acp_token.json
      if [ -f "$token_source" ] && [ -s "$token_source" ] && [ ! -L "$token_source" ]; then
        if [ ! -f "$token_target" ] || [ -L "$token_target" ]; then
          if ! (
            umask 077
            tmp=$(${coreutils}/mktemp "$acp_dir/.acp_token.XXXXXX") || exit 1
            if ! ${coreutils}/cat "$token_source" > "$tmp" || [ ! -s "$tmp" ] || ! ${coreutils}/ln "$tmp" "$token_target"; then
              ${coreutils}/rm -f "$tmp"
              exit 1
            fi
            ${coreutils}/rm -f "$tmp"
          ) 2>/dev/null; then
            printf 'agy_acp_server.par: could not copy the ~/.gemini sign-in into GEMINI_HOME\n' >&2
          fi
        fi
      fi

      local agy_cli_dir skills_dir src_dir skill src dest
      agy_cli_dir=$gemini_home/antigravity-cli
      skills_dir=$agy_cli_dir/skills
      src_dir=$HOME/.gemini/antigravity-cli/skills
      (
        umask 077
        [ -e "$agy_cli_dir" ] || [ -L "$agy_cli_dir" ] || ${coreutils}/mkdir -m 700 "$agy_cli_dir" || exit 0
        private_dir "$agy_cli_dir" || exit 0
        [ -e "$skills_dir" ] || [ -L "$skills_dir" ] || ${coreutils}/mkdir -m 700 "$skills_dir" || exit 0
        private_dir "$skills_dir" || exit 0
        for skill in ${pkgs.lib.escapeShellArgs skills}; do
          src=$src_dir/$skill
          dest=$skills_dir/$skill
          if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
            ${coreutils}/ln -s "$src" "$dest" || true
          fi
        done
      ) 2>/dev/null || true
    }

    seed_acp_token
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
