/*
  Check interface:

    import ./tests/nixos-rebuild-helper.nix { inherit pkgs self; }

  Asserts the declarative wiring of the nixos-rebuild helper: the zsh aliases,
  the packaged helper itself, the generation-diff invocation baked into it, and
  the host-variant marker both configurations expose.

  Verifies:
  - programs.zsh.shellAliases maps nrs, nrb, nrt and nrd onto the four helper
    subcommands.
  - The packaged nr helper is in the user package list.
  - The built helper carries the substituted nvd store path and invokes it,
    so the generation diff cannot be dropped silently.
  - environment.etc."nixos-host-variant" is enabled on both hosts and reads
    production on one and bootstrap on the other.

  The marker is checked through its enable flag and its resolved target rather
  than its attribute name, and the helper is checked through the built script
  rather than a package-list entry, because a package list is a proxy the
  script does not read.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  host = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11;
  bootstrapHost = self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap;
  msHost = self.nixosConfigurations.MS-7D91;
  msBootstrapHost = self.nixosConfigurations.MS-7D91-bootstrap;

  userConfig = host.config.home-manager.users.h82;
  aliases = userConfig.programs.zsh.shellAliases;

  expectedAliases = {
    nrs = "nr switch";
    nrb = "nr boot";
    nrt = "nr test";
    nrd = "nr build";
  };

  wrongAliases = lib.attrNames (
    lib.filterAttrs (name: want: (aliases.${name} or null) != want) expectedAliases
  );

  nrPackage = lib.lists.findFirst (p: (p.pname or "") == "nr") null userConfig.home.packages;

  markerFor =
    cfg:
    lib.lists.findFirst (e: (e.target or "") == "nixos-host-variant") null (
      lib.attrValues cfg.environment.etc
    );

  hostMarker = markerFor host.config;
  bootstrapMarker = markerFor bootstrapHost.config;
  msHostMarker = markerFor msHost.config;
  msBootstrapMarker = markerFor msBootstrapHost.config;

  markerCheck =
    label: marker: expected:
    if marker == null then
      ''
        echo 'no /etc entry targets nixos-host-variant on the ${label} configuration' >&2
        exit 1
      ''
    else
      ''
        if [ "${builtins.toJSON (marker.enable or false)}" != "true" ]; then
          echo 'the nixos-host-variant entry is declared but not enabled on the ${label} configuration' >&2
          exit 1
        fi
        if [ "${lib.strings.trim (marker.text or "")}" != "${expected}" ]; then
          echo 'the ${label} configuration reports the wrong host variant' >&2
          exit 1
        fi
      '';

  nrAbsent = lib.optionalString (nrPackage == null) ''
    echo 'the packaged nr helper is missing from the user package list' >&2
    exit 1
  '';

  nrPresent = lib.optionalString (nrPackage != null) ''
    if [ ! -x ${nrPackage}/bin/nr ]; then
      echo 'the nr package ships no bin/nr executable' >&2
      exit 1
    fi
    if ! grep -q '${pkgs.nvd}/bin/nvd' ${nrPackage}/bin/nr; then
      echo 'the built nr helper does not carry the substituted nvd store path' >&2
      exit 1
    fi
    if ! grep -q '${pkgs.git}/bin/git' ${nrPackage}/bin/nr; then
      echo 'the built nr helper does not carry the substituted git store path' >&2
      exit 1
    fi
    if ! grep -q '"$NVD" diff' ${nrPackage}/bin/nr; then
      echo 'the built nr helper never invokes nvd diff, so it reports no generation change' >&2
      exit 1
    fi
    # Any surviving placeholder, not just @NVD@: a check that names one token
    # passes while another substitution is silently dropped.
    if grep -qE '@[A-Z_]+@' ${nrPackage}/bin/nr; then
      echo 'the built nr helper still contains an unsubstituted placeholder' >&2
      exit 1
    fi
  '';
in
pkgs.runCommand "nixos-rebuild-helper-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x

  # 1. The four aliases map onto the helper's subcommands.
  if [ '${builtins.toJSON wrongAliases}' != '[]' ]; then
    echo 'these zsh aliases are missing or point at the wrong subcommand: ${builtins.toJSON wrongAliases}' >&2
    exit 1
  fi

  # 2. The packaged helper exists and still carries its generation diff.
  ${nrAbsent}
  ${nrPresent}

  # 3. Both configurations report their own variant across all hosts.
  ${markerCheck "ThinkPad production" hostMarker "production"}
  ${markerCheck "ThinkPad bootstrap" bootstrapMarker "bootstrap"}
  ${markerCheck "MS-7D91 production" msHostMarker "production"}
  ${markerCheck "MS-7D91 bootstrap" msBootstrapMarker "bootstrap"}

  touch $out
''
