{ pkgs, lib }:
let
  # `name` is what the text calls the harness; the template branches on the id
  # for its native-tool section.
  harnesses = {
    claude-code = "Claude Code";
    opencode = "OpenCode";
  };

  # A merged file always carries its parts in this order, so the system rules
  # lead whatever channel ends up holding them.
  order = [
    "system"
    "user"
    "t3code"
  ];

  # The OpenCode peer's model, shared with OpenCode's own config.
  opencodeContext = contextFile "opencode" { model = import ../opencode-model.nix; };

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
          --context opencode=file://${opencodeContext} \
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

}
