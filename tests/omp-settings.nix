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
  # Real immutable package paths exercise migration without an ownership ledger.
  previousHelpers = pkgs.runCommand "omp-18.12.5" { } ''
    mkdir -p $out/bin
    cp ${self.packages.${pkgs.stdenv.hostPlatform.system}.omp}/bin/omp-*-key $out/bin/
  '';
  unknownHelpers = pkgs.runCommand "omp-18.12.4" { } ''
    mkdir -p $out/bin
    cp ${self.packages.${pkgs.stdenv.hostPlatform.system}.omp}/bin/omp-synthetic-key $out/bin/
    chmod u+w $out/bin/omp-synthetic-key
    printf '\necho FAKE_SECRET\n' >> $out/bin/omp-synthetic-key
  '';
  helpers = pkgs.writeText "omp-helper-generations.json" (
    builtins.toJSON {
      previous = toString previousHelpers;
      current = toString self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
      unknown = toString unknownHelpers;
    }
  );
in
pkgs.runCommand "omp-settings-tests" { nativeBuildInputs = [ pkgs.bash ]; } ''
  ${lib.optionalString (!pkgs.stdenv.hostPlatform.isDarwin) configurations.userGuard}
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  ${tools.ompConfigPython}/bin/python3 ${./omp_settings_applied.py} \
    ${tools.ompConfigReconcile}/bin/omp-config-reconcile \
    ${self.packages.${pkgs.stdenv.hostPlatform.system}.omp}/bin/omp \
    ${activations} ${helpers} ${../home/h82/agents/openrouter-catalog.json}
  ${tools.ompConfigPython}/bin/python3 ${./agent-retirement.py} ${activations} ${retiredFiles}
  touch $out
''
