{
  pkgs,
  self,
  fixtures ? [ ],
}:
let
  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };
  users =
    if pkgs.stdenv.hostPlatform.isDarwin then
      map (entry: entry.host.config.home-manager.users.${entry.host.config.my.user.name}) (
        import ./lib/darwin-fixtures.nix { inherit (self) inputs; }
      )
    else
      map (entry: entry.user) (
        pkgs.lib.filter (
          entry: entry.config.nixpkgs.hostPlatform.system == pkgs.stdenv.hostPlatform.system
        ) configurations.entries
      )
      ++ map (entry: entry.host.home.config) configurations.linuxFixtures;
  documents = pkgs.writeText "omp-provider-documents.json" (
    builtins.toJSON (
      pkgs.lib.unique (map (user: pkgs.lib.mapAttrs (_: path: toString path) user.my.omp.documents) users)
    )
  );
  omp = self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
  keyProbe = import ../packages/omp.nix {
    inherit pkgs;
    syntheticKeyFile = toString (pkgs.writeText "omp-fake-key" "sk-fake-file\n");
    openrouterKeyFile = "/omp-test-missing/key";
  };
in
pkgs.runCommand "omp-models-load-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.bash
      pkgs.openssl
    ];
  }
  ''
    python3 -I ${./omp_models_load.py} ${omp}/bin/omp ${documents} \
      ${../home/h82/agents/synthetic-catalog.json} ${../home/h82/agents/openrouter-catalog.json} ${keyProbe}/bin
    python3 -I ${./omp-headless.py} ${omp}/bin/omp ${documents} ${keyProbe}/bin/omp-openrouter-key
    touch $out
  ''
