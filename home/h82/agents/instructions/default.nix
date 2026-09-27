{ pkgs, lib, ... }:
let
  # Every harness renders the one template, which branches on `.harness.id`
  # for the native-tool section. `name` is what the text calls the harness, and
  # the target is the user-level instruction file it loads in every workspace.
  #
  # The Antigravity CLI loads both ~/.gemini/GEMINI.md and
  # ~/.gemini/config/AGENTS.md as global rules. The first is also the Gemini
  # CLI's global context file, which would hand Antigravity's tool names to a
  # different harness, so this uses the second.
  harnesses = {
    claude-code = {
      name = "Claude Code";
      target = ".claude/CLAUDE.md";
    };
    antigravity = {
      name = "Antigravity";
      target = ".gemini/config/AGENTS.md";
    };
  };

  # Rendered with gomplate, whose templates are Go text/template. A missing
  # context key, or a harness id the template has no branch for, fails the
  # build rather than shipping `<no value>` or a file without its tool section.
  render =
    id: harness:
    let
      context = pkgs.writeText "agent-instructions-${id}.json" (
        builtins.toJSON {
          inherit id;
          inherit (harness) name;
        }
      );
    in
    pkgs.runCommand "agent-instructions-${id}.md" { nativeBuildInputs = [ pkgs.gomplate ]; } ''
      gomplate \
        --missing-key error \
        --context harness=file://${context} \
        --file ${./instructions.md.tmpl} \
        --out $out
    '';
in
{
  # Plain store links: neither harness rewrites these files, unlike the
  # settings files claude.nix and gemini.nix merge at activation.
  home.file = lib.mapAttrs' (
    id: harness:
    lib.nameValuePair "agent-instructions-${id}" {
      inherit (harness) target;
      source = render id harness;
    }
  ) harnesses;
}
