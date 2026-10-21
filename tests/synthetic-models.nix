/*
  Check interface:

    import ./tests/synthetic-models.nix { inherit pkgs; }

  Pins the shape of home/h82/agents/synthetic-models.nix, the one source of
  every Synthetic model the repository uses: each `id` starts with `hf:` and
  its family is the one its org maps to, no role runs at effort `medium`, which
  these models do not offer, each lineage pattern matches its own `id` and its
  first capture group is a version under both Nix `builtins.match` and Python
  `re.fullmatch`, and the top-level selections name existing entries. Every
  problem is listed from the builder before it fails.
*/
{ pkgs }:
let
  inherit (pkgs) lib;

  source = import ../home/h82/agents/synthetic-models.nix;

  # Org to family, as the shared instructions map a model ID.
  orgFamilies = {
    zai-org = "glm";
    moonshotai = "kimi";
    deepseek-ai = "deepseek";
    Qwen = "qwen";
  };

  selections = [
    "opencodeDefault"
    "small"
    "textGeneration"
  ];

  entryNames = lib.subtractLists selections (lib.attrNames source);
  entries = lib.genAttrs entryNames (name: source.${name});

  versionShape = "[0-9]+([.][0-9]+)?";

  capturedVersion =
    entry:
    let
      groups = builtins.match (entry.lineage or "") (entry.id or "");
    in
    if groups == null || groups == [ ] then null else builtins.head groups;

  entryProblems =
    name: entry:
    let
      id = entry.id or "";
      org = builtins.match "hf:([^/]+)/.+" id;
      version = capturedVersion entry;
    in
    lib.optional (!lib.hasPrefix "hf:" id) "${name}: id `${id}` does not start with hf:"
    ++ lib.optional (
      org == null || (orgFamilies.${builtins.head org} or "unknown") != (entry.family or "")
    ) "${name}: family `${entry.family or ""}` is not the family of the org of `${id}`"
    ++ lib.optional (
      version == null
    ) "${name}: lineage `${entry.lineage or ""}` does not match `${id}` with a capture"
    ++ lib.optional (
      version != null && builtins.match versionShape version == null
    ) "${name}: lineage captures `${version}`, not a version"
    ++ lib.optional ((entry.roles or { }) == { }) "${name}: no roles"
    ++ lib.mapAttrsToList (role: _: "${name}: role ${role} runs at effort medium") (
      lib.filterAttrs (_: effort: effort == "medium") (entry.roles or { })
    )
    ++ lib.optional (
      (entry.opencodeEffort or "medium") == "medium"
    ) "${name}: opencodeEffort is missing or medium";

  problems =
    lib.optional (entries == { }) "no model entries"
    ++ lib.concatLists (lib.mapAttrsToList entryProblems entries)
    ++ map (selection: "${selection} does not name a model entry") (
      lib.filter (selection: !(entries ? ${source.${selection} or ""})) selections
    );

  # The model-watch script matches catalog IDs with Python re.fullmatch and
  # takes the version from group 1, so the patterns must agree there too.
  pythonCases = pkgs.writeText "synthetic-models-lineage.json" (
    builtins.toJSON (
      lib.mapAttrsToList (name: entry: {
        inherit name;
        id = entry.id or "";
        lineage = entry.lineage or "";
        version = capturedVersion entry;
      }) entries
    )
  );
in
pkgs.runCommand "synthetic-models-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  fail=0

  for problem in ${lib.escapeShellArgs problems}; do
    echo "synthetic-models: $problem" >&2
    fail=1
  done

  python3 -I - ${pythonCases} <<'EOF' || fail=1
  import json, re, sys

  failed = False
  for case in json.load(open(sys.argv[1])):
      match = re.fullmatch(case["lineage"], case["id"])
      found = match.group(1) if match and match.re.groups else None
      if found != case["version"]:
          print(f"synthetic-models: {case['name']}: Python captures {found!r}, "
                f"Nix captures {case['version']!r}", file=sys.stderr)
          failed = True
  sys.exit(1 if failed else 0)
  EOF

  [ "$fail" = 0 ] || exit 1
  touch $out
''
