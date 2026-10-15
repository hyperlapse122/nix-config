{ pkgs, lib }:
let
  # `name` is what the text calls the harness; the template branches on the id
  # for its native-tool section.
  harnesses = {
    claude-code = "Claude Code";
    antigravity = "Antigravity";
    codex = "Codex";
  };

  # A merged file always carries its parts in this order, so the system rules
  # lead whatever channel ends up holding them.
  order = [
    "system"
    "user"
    "t3code"
  ];

  contextFile = name: value: pkgs.writeText "agent-instructions-${name}.json" (builtins.toJSON value);
in
{
  # Rendered with gomplate, whose templates are Go text/template. A missing
  # context key, or a harness or part the template has no branch for, fails
  # the build rather than shipping `<no value>` or a file without a section.
  # Parts are joined with one blank line.
  render =
    { harness, parts }:
    assert lib.assertMsg (builtins.hasAttr harness harnesses)
      "agent-instructions: unknown harness ${harness}";
    assert lib.assertMsg (
      parts != [ ] && lib.filter (part: lib.elem part parts) order == parts
    ) "agent-instructions: parts must be a non-empty, ordered subset of ${toString order}";
    let
      harnessContext = contextFile harness {
        id = harness;
        name = harnesses.${harness};
      };
      renderPart = part: ''
        gomplate \
          --missing-key error \
          --context harness=file://${harnessContext} \
          --context part=file://${contextFile "part-${part}" { id = part; }} \
          --file ${./instructions.md.tmpl} \
          --out ${part}.md
      '';
    in
    pkgs.runCommand "agent-instructions-${harness}-${lib.concatStringsSep "-" parts}.md"
      { nativeBuildInputs = [ pkgs.gomplate ]; }
      ''
        ${lib.concatMapStrings renderPart parts}
        ${lib.concatMapStringsSep "\nprintf '\\n' >> $out\n" (part: "cat ${part}.md >> $out") parts}
      '';

  # A declared-settings file: `base`, the declaration as a Nix value, with
  # setPaths leaves appended that carry rendered instruction text. The text is
  # read in the builder, not with builtins.readFile, so evaluating a host never
  # builds a rendered part (no import-from-derivation). Each leaf is
  # { path; encoding; source; }; see declare.py for encodings.
  declare =
    {
      name,
      base,
      leaves,
    }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.python3 ]; } ''
      python3 ${./declare.py} ${pkgs.writeText "${name}-base" (builtins.toJSON base)} $out ${
        lib.concatMapStringsSep " " (
          leaf: "--leaf ${lib.escapeShellArg (builtins.toJSON leaf.path)} ${leaf.encoding} ${leaf.source}"
        ) leaves
      }
    '';
}
