/*
  Check interface:

    import ./tests/nixos-rebuild-helper.nix { inherit pkgs self; }

  Asserts the declarative wiring of the nixos-rebuild helper on every
  configuration `tests/lib/configurations.nix` yields: the zsh aliases, the
  packaged helper itself, the generation-diff invocation baked into it, and the
  host-variant marker each configuration exposes.

  Verifies, per configuration:
  - programs.zsh.shellAliases maps nrs, nrb, nrt and nrd onto the four helper
    subcommands.
  - The packaged nr helper is in the user package list.
  - The built helper carries the substituted nvd store path and invokes it,
    so the generation diff cannot be dropped silently.
  - environment.etc."nixos-host-variant" is enabled and reads bootstrap on a
    configuration whose `my.bootstrap` is set and production otherwise. The
    expected word comes from the helper's `bootstrap` field, never from the
    marker's own text.

  The marker is checked through its enable flag and its resolved target rather
  than its attribute name, and the helper is checked through the built script
  rather than a package-list entry, because a package list is a proxy the
  script does not read.

  The helper's guard runs first, so an empty configuration list, or one with no
  bootstrap output, fails the build instead of passing it. The builder collects
  every failure before it exits, so one red build names every affected
  configuration.
*/
{ pkgs, self }:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self; };

  esc = value: lib.escapeShellArg (toString value);

  fail = message: ''
    echo ${esc message} >&2
    failed=1
  '';

  expectedAliases = {
    nrs = "nr switch";
    nrb = "nr boot";
    nrt = "nr test";
    nrd = "nr build";
  };

  assertAliases =
    entry:
    let
      aliases = entry.user.programs.zsh.shellAliases or { };
      wrongAliases = lib.attrNames (
        lib.filterAttrs (name: want: (aliases.${name} or null) != want) expectedAliases
      );
    in
    ''
      if [ ${esc (builtins.toJSON wrongAliases)} != '[]' ]; then
        ${fail "${entry.name}: these zsh aliases are missing or point at the wrong subcommand: ${builtins.toJSON wrongAliases}"}
      fi
    '';

  assertHelper =
    entry:
    let
      nrPackage = lib.lists.findFirst (p: (p.pname or "") == "nr") null (entry.user.home.packages or [ ]);
    in
    if nrPackage == null then
      fail "${entry.name}: the packaged nr helper is missing from the user package list"
    else
      ''
        nr=${esc "${nrPackage}/bin/nr"}
        if [ ! -x "$nr" ]; then
          ${fail "${entry.name}: the nr package ships no bin/nr executable"}
        else
          if ! grep -q ${esc "${pkgs.nvd}/bin/nvd"} "$nr"; then
            ${fail "${entry.name}: the built nr helper does not carry the substituted nvd store path"}
          fi
          if ! grep -q ${esc "${pkgs.git}/bin/git"} "$nr"; then
            ${fail "${entry.name}: the built nr helper does not carry the substituted git store path"}
          fi
          if ! grep -q '"$NVD" diff' "$nr"; then
            ${fail "${entry.name}: the built nr helper never invokes nvd diff, so it reports no generation change"}
          fi
          # Any surviving placeholder, not just @NVD@: a check that names one
          # token passes while another substitution is silently dropped.
          if grep -qE '@[A-Z_]+@' "$nr"; then
            ${fail "${entry.name}: the built nr helper still contains an unsubstituted placeholder"}
          fi
        fi
      '';

  assertMarker =
    entry:
    let
      marker = lib.lists.findFirst (e: (e.target or "") == "nixos-host-variant") null (
        lib.attrValues (entry.config.environment.etc or { })
      );
      expected = if entry.bootstrap then "bootstrap" else "production";
    in
    if marker == null then
      fail "${entry.name}: no /etc entry targets nixos-host-variant"
    else
      ''
        if [ ${esc (builtins.toJSON (marker.enable or false))} != "true" ]; then
          ${fail "${entry.name}: the nixos-host-variant entry is declared but not enabled"}
        fi
        if [ ${esc (lib.strings.trim (marker.text or ""))} != ${esc expected} ]; then
          ${fail "${entry.name}: the configuration reports the wrong host variant, expected ${expected}"}
        fi
      '';
in
pkgs.runCommand "nixos-rebuild-helper-tests" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  set -x
  ${configurations.guard}
  failed=0

  ${lib.concatMapStringsSep "\n" (
    entry:
    lib.concatStringsSep "\n" [
      (assertAliases entry)
      (assertHelper entry)
      (assertMarker entry)
    ]
  ) configurations.entries}

  if [ "$failed" != 0 ]; then
    exit 1
  fi
  touch $out
''
