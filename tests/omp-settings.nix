{
  pkgs,
  self,
  fixtures ? [ ],
}:
let
  inherit (pkgs) lib;
  tools = import ../packages/agent-tools.nix { inherit pkgs; };
  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };
  entries =
    if pkgs.stdenv.hostPlatform.isDarwin then
      map (entry: {
        inherit (entry) name;
        user = entry.host.config.home-manager.users.${entry.host.config.my.user.name};
      }) (import ./lib/darwin-fixtures.nix { inherit (self) inputs; })
    else
      map (entry: { inherit (entry) name user; }) (
        lib.filter (
          entry: entry.config.nixpkgs.hostPlatform.system == pkgs.stdenv.hostPlatform.system
        ) configurations.entries
      )
      ++ map (entry: {
        inherit (entry) name;
        user = entry.host.home.config;
      }) configurations.linuxFixtures;
  activations = pkgs.writeText "omp-activations.json" (
    builtins.toJSON (
      map (entry: {
        inherit (entry) name;
        home = entry.user.home.homeDirectory or "";
        activate = "${entry.user.home.activationPackage}/activate";
        files = toString entry.user.home-files;
        path = toString entry.user.home.path;
      }) entries
    )
  );
  retiredFiles = pkgs.linkFarm "home-manager-files" (
    map
      (name: {
        inherit name;
        path = pkgs.writeText "retired-agent-fixture" "old generation";
      })
      [
        ".pi/agent/AGENTS.md"
        ".pi/agent/extensions/nix-config"
        ".pi/agent/skills/test-audit"
      ]
  );
in
pkgs.runCommand "omp-settings-tests" { nativeBuildInputs = [ pkgs.bash ]; } ''
  ${lib.optionalString (!pkgs.stdenv.hostPlatform.isDarwin) configurations.userGuard}
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  ${tools.ompConfigPython}/bin/python3 ${./omp_settings_applied.py} \
    ${tools.ompConfigReconcile}/bin/omp-config-reconcile \
    ${self.packages.${pkgs.stdenv.hostPlatform.system}.omp}/bin/omp \
    ${activations}
  ${tools.ompConfigPython}/bin/python3 ${./agent-retirement.py} ${activations} ${retiredFiles}
  touch $out
''
