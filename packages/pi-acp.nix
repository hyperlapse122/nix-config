/*
  pi-acp, the ACP adapter that runs `pi --mode rpc`, bound to the packaged Pi
  wrapper. It finds Pi through PI_ACP_PI_COMMAND, an executable it spawns with
  its own arguments, so each entry point sets it to a store path:

  - bin/pi-acp runs the pi wrapper.
  - bin/pi-acp-readonly runs libexec/pi-readonly, which adds
    `--exclude-tools bash,edit,write,web_fetch --no-mcp`. Neither pi-acp nor
    its client can stop Pi's own tools, so this is what keeps a review peer
    from writing, running commands, or fetching a URL it was steered to, and
    keeps an MCP server the user added from handing it a write tool. A
    `--tools` allowlist would also drop the tools extensions register, so the
    tools are removed by name and session_info and web_search stay.

  Both unset SYNTHETIC_API_KEY and EXA_API_KEY, so a key the calling session
  exported never reaches the commands Pi's tools run; Pi reads its keys from
  the key files instead.

  The npm tarball ships its built dist/ and no lock file. scripts/npm-release
  pins the tarball in pi-acp-release.json and writes pi-acp/package-lock.json
  for its package.json without devDependencies, which postPatch matches.
*/
{
  pkgs,
  pi ? import ./pi.nix { inherit pkgs; },
}:

let
  inherit (pkgs) lib;
  npmRelease = import ./npm-release-package.nix {
    inherit pkgs;
    pname = "pi-acp-adapter";
    release = ./pi-acp-release.json;
    lockDirectory = ./pi-acp;
  };
  inherit (npmRelease) source;

  adapter = pkgs.buildNpmPackage npmRelease.attrs;
in
pkgs.runCommand "pi-acp-${source.version}"
  {
    pname = "pi-acp";
    inherit (source) version;
    nativeBuildInputs = [
      pkgs.jq
      pkgs.makeWrapper
    ];
    passthru = { inherit adapter pi; };
    meta = {
      description = "ACP adapter for the packaged Pi";
      homepage = "https://github.com/svkozak/pi-acp";
      license = lib.licenses.mit;
      platforms = pi.meta.platforms or lib.platforms.unix;
      mainProgram = "pi-acp";
    };
  }
  ''
    mkdir -p $out/libexec
    cat > $out/libexec/pi-readonly <<EOF
    #!${pkgs.runtimeShell}
    exec ${pi}/bin/pi --exclude-tools bash,edit,write,web_fetch --no-mcp "\$@"
    EOF
    chmod 555 $out/libexec/pi-readonly

    for variant in pi-acp:${pi}/bin/pi pi-acp-readonly:$out/libexec/pi-readonly; do
      makeWrapper ${adapter}/bin/pi-acp $out/bin/''${variant%%:*} \
        --unset SYNTHETIC_API_KEY \
        --unset EXA_API_KEY \
        --set PI_ACP_PI_COMMAND "''${variant#*:}"
    done

    # pi-acp has no --version; its ACP initialize reply names its version.
    for program in $out/bin/*; do
      version=$(
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1}}' |
          HOME=$TMPDIR "$program" | jq -r '.result.agentInfo.version'
      )
      if [ "$version" != ${lib.escapeShellArg source.version} ]; then
        echo "$program reports version '$version', expected ${source.version}" >&2
        exit 1
      fi
    done
  ''
