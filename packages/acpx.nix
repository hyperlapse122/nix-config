/*
  acpx, the headless ACP client, with its built-in `pi` agent bound to the
  packaged pi-acp and a `pi-readonly` agent beside it.

  acpx's own override is an `agents` entry in ~/.acpx/config.json or in the
  `.acpxrc.json` of the directory it runs in, and neither can be set from a
  wrapper. So postPatch rewrites the built-in definitions instead: `pi` runs
  pi-acp by store path, never `npx pi-acp`, and `pi-readonly` runs
  pi-acp-readonly. Every rewrite must match the shipped text exactly, so a
  release that moves them fails the build instead of falling back to npx.

  postPatch also stops acpx reading `.acpxrc.json` from the directory it runs
  in. Its `agents` entries outrank the built-ins, so a checkout under review
  could otherwise rebind `pi-readonly` to any command it ships.
  ~/.acpx/config.json, the user's own file, still applies.

  The npm tarball ships its built dist/ and no lock file. scripts/npm-release
  pins the tarball in acpx-release.json and writes acpx/package-lock.json for
  its package.json without devDependencies, which postPatch matches.
*/
{
  pkgs,
  piAcp ? import ./pi-acp.nix { inherit pkgs; },
}:

let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ./acpx-release.json);
in
pkgs.buildNpmPackage {
  pname = "acpx";
  inherit (source) version;
  src = pkgs.fetchurl { inherit (source) url hash; };
  # The dependency cache comes from the committed lock file alone, the way
  # prefetch-npm-deps hashed it.
  npmDeps = pkgs.fetchNpmDeps {
    name = "acpx-${source.version}-npm-deps";
    src = ./acpx;
    hash = source.npmDepsHash;
  };
  # acpx needs Node 22.13 or newer.
  nodejs = pkgs.nodejs_24;

  nativeBuildInputs = [ pkgs.jq ];
  postPatch = ''
    cp ${./acpx/package-lock.json} package-lock.json
    jq 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json

    registry=(dist/agent-registry-*.js)
    if [ "''${#registry[@]}" -ne 1 ] || [ ! -f "''${registry[0]}" ]; then
      echo "acpx: expected one dist/agent-registry-*.js, found: ''${registry[*]}" >&2
      exit 1
    fi
    substituteInPlace "''${registry[0]}" \
      --replace-fail 'argv: ["npx", `pi-acp@''${ACP_ADAPTER_PACKAGE_RANGES.pi}`],' \
        'argv: ["${piAcp}/bin/pi-acp"],' \
      --replace-fail 'installedArgv: ["pi-acp"],' \
        'installedArgv: ["${piAcp}/bin/pi-acp"],' \
      --replace-fail 'requiredCommands: ["pi"],' "" \
      --replace-fail 'const AGENT_DEFINITIONS = {' \
        'const AGENT_DEFINITIONS = { "pi-readonly": { name: "Pi (read-only tools)", argv: ["${piAcp}/bin/pi-acp-readonly"] },'
    substituteInPlace dist/cli.js \
      --replace-fail 'readConfigFile(projectPath),' '{ config: void 0, exists: false },'
  '';
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru = { inherit piAcp; };

  meta = {
    description = "Headless command-line client for the Agent Client Protocol";
    homepage = "https://github.com/openclaw/acpx";
    license = lib.licenses.mit;
    inherit (piAcp.meta) platforms;
    mainProgram = "acpx";
  };
}
