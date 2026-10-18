/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions, one plain file, reach both
  delivery paths for user `h82` on every host this flake declares:

    Claude Code   ~/.claude/CLAUDE.md, which T3 Code's Claude sessions read too
    OpenCode      the file the wrapper's instructions config names, which only
                  a standalone run loads

  The OpenCode file is read from the installed wrapper itself: its
  INSTRUCTIONS_CONFIG constant, then the one file that config lists. The user
  list is `userEntries` from `tests/lib/configurations.nix`.

  Verifies, per Home Manager user:
  - exactly one enabled Home Manager file resolves to ~/.claude/CLAUDE.md, and
    none to the retired ~/.t3/instructions/claude-code/CLAUDE.md, Codex's
    ~/.codex/AGENTS.md, Antigravity's ~/.gemini/config/AGENTS.md, Gemini's
    ~/.gemini/GEMINI.md, or OpenCode's always-loaded
    ~/.config/opencode/AGENTS.md. The lookup compares each entry's resolved
    `target` rather than its attribute name, and reads `enable`, because
    either can move the file without changing its text. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - the Claude Code file and the OpenCode file are byte-identical.
  - every pinned sentence appears exactly once and starts where a sentence
    starts, so a dropped, doubled, or negated ("Do not ...") rule fails. See
    .compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md
  - the file names no removed section, harness, model, or rule, and carries
    no template action (`{{`, `}}`) or `<no value>`.

  The expected sentences are literals here, not read from the module, so a
  mutation of the instruction file turns this red.

  Every lookup carries an `or` fallback and each store path is interpolated
  only inside its present branch, so a removed declaration fails inside the
  builder rather than during evaluation. See
  .compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md

  The builder collects every failure instead of exiting at the first, so one
  red build names every broken assertion across all hosts.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  esc = value: lib.escapeShellArg (toString value);

  pinnedSentences = [
    "# GPG and encryption"
    "Run GPG signing, decryption, and encryption yourself, including SOPS re-encryption and edits; when a pinentry dialog appears, let it reach the user."
    "Never print decrypted values, pass them as arguments, or open decrypted files with the file tools; pipe decrypted output straight into the command that consumes it."
    "Leave card administration and key management to the user."
    "For a new SOPS setup or secret file, use the card key `621512777E6933FEB4458FDC4945855D4F283F05` as the user's recipient, plus a machine's own recipient when it must decrypt without the card."
    "# Git"
    "Never rename onto or push over an existing branch."
    "Do not run `mise trust` on the copy or skip the hook with `--no-verify`."
    "Refresh each with `ce-compound-refresh`, commit each refresh separately on the current branch, then push once."
    "# Pull and merge requests"
    "Treat GitLab like GitHub: when a Compound Engineering skill speaks only GitHub, do the same steps with `glab`, and skip only a step with no GitLab counterpart, naming it in your report."
    "After you open or push to a pull or merge request, babysit it until it looks ready to merge, then leave the merge to the user."
    "Before uploading, cover secrets, personal data, and internal hosts with opaque boxes, never blur, and strip metadata with `ffmpeg -map_metadata -1`."
    "# Review findings"
    "Apply every finding that `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` report, whatever its severity, confidence, or list, including testing gaps and residual risks."
    "Leave a finding unapplied only when you verified it is wrong or its fix would weaken a safety check, and say why."
    "When a fix needs a user decision, such as a product or scope change, ask in an interactive run; in an autonomous run, apply the recommended fix and report it, but ask before reversing a decision the user made."
    "Compound Engineering skills use `opencode` as the cross-model peer."
    "When the peer fails, skip the pass and say why in one line; do not retry it or run another peer in its place."
    "# T3 Code"
    "When the session lists T3 Code's delegation tools, such as `delegate_task`, delegate subagent work through them; otherwise use your native subagent tool."
    "When the session lists T3 Code's pull request tools, such as `watch_pull_request`, use them to watch a request you babysit instead of your own background wait."
  ];

  removedTerms = [
    "# Tool use"
    "# Cross-model review"
    "# Delegation"
    "Antigravity"
    "Gemini"
    "gemini-"
    "Argon"
    "Flash"
    "Codex"
    "codex"
    "Zen"
    "glm-"
    "Model routing"
    "receives the reviewed content"
    "data terms"
  ];

  # Fails the build, naming each sentence, unless `$file` holds it exactly
  # once and that occurrence starts where a sentence starts: at the start of
  # a line, after a list marker, or after the previous sentence's full stop.
  # A substring match would accept the sentence inside its own negation
  # ("Do not Apply every...").
  requireSentences = message: sentences: ''
    for sentence in ${lib.escapeShellArgs sentences}; do
      if ! awk -v s="$sentence" '
        {
          line = $0
          while ((i = index(line, s)) > 0) {
            pre = substr(line, 1, i - 1)
            n++
            if (pre == "" || pre ~ /^ *- $/ || pre ~ /\. $/) anchored++
            line = substr(line, i + length(s))
          }
        }
        END { exit !(n == 1 && anchored == 1) }
      ' "$file"; then
        echo ${esc message} "$sentence" >&2
        failed=1
      fi
    done
  '';

  fileRules = label: ''
    if [ ! -s "$file" ]; then
      echo ${esc "${label} is missing or empty"} >&2
      failed=1
    else
      key=$(sha256sum < "$file" | cut -d' ' -f1)
      if ! grep -qxF -- "$key" "$seen"; then
        echo "$key" >> "$seen"
        ${requireSentences "${label} does not hold this sentence exactly once, where a sentence starts:" pinnedSentences}
        for term in ${lib.escapeShellArgs removedTerms}; do
          if grep -qF -- "$term" "$file"; then
            echo ${esc "${label} names something the instructions no longer carry:"} "$term" >&2
            failed=1
          fi
        done
        if grep -qE '\{\{|\}\}|<no value>' "$file"; then
          echo ${esc "${label} carries an unrendered template action"} >&2
          failed=1
        fi
      fi
    fi
  '';

  # Copies the one enabled Home Manager file at `target` to `dest`, failing
  # unless exactly `want` (0 or 1) such files exist.
  homeFile =
    label: userConfig: target: want: dest:
    let
      entries = lib.filter (file: (file.target or "") == target) (
        lib.attrValues (userConfig.home.file or { })
      );
      entry = if lib.length entries == 1 then lib.head entries else null;
      source = if entry == null then null else (entry.source or null);
    in
    lib.optionalString (lib.length entries != want) ''
      echo ${esc "expected ${toString want} home.file for ~/${target} on ${label}, found ${toString (lib.length entries)}"} >&2
      failed=1
    ''
    + lib.optionalString (entry != null) ''
      if [ ${esc (lib.boolToString (entry.enable or false))} != "true" ]; then
        echo ${esc "home.file for ~/${target} on ${label} is not enabled"} >&2
        failed=1
      fi
    ''
    + lib.optionalString (entry != null && source == null) ''
      echo ${esc "home.file for ~/${target} on ${label} has no source"} >&2
      failed=1
    ''
    + lib.optionalString (source != null) ''
      cp ${source} ${dest}
    '';

  # Copies the instruction file the installed opencode wrapper hands a
  # standalone run to `dest`: the wrapper's INSTRUCTIONS_CONFIG constant
  # names a config whose `instructions` must list exactly one file.
  opencodeFile =
    label: userConfig: dest:
    let
      package = lib.findFirst (p: (p.pname or "") == "opencode") null (userConfig.home.packages or [ ]);
    in
    lib.optionalString (package == null) ''
      echo ${esc "missing opencode in user packages on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (package != null) ''
      config=$(sed -nE "s/^INSTRUCTIONS_CONFIG='(.*)'$/\1/p" ${package}/bin/opencode)
      listed=$(jq -r '.instructions | if type == "array" and length == 1 then .[0] else empty end' "$config" 2>/dev/null || true)
      if [ -n "$listed" ] && [ -f "$listed" ]; then
        cp "$listed" ${dest}
      else
        echo ${esc "the opencode wrapper on ${label} hands a standalone run no single instructions file"} >&2
        failed=1
      fi
    '';

  assertEntry =
    entry:
    let
      label = entry.name;
      user = entry.user;
    in
    ''
      d=$(mktemp -d)

      ${homeFile label user ".claude/CLAUDE.md" 1 "$d/claude"}
      ${homeFile label user ".t3/instructions/claude-code/CLAUDE.md" 0 "$d/claude-t3"}
      ${homeFile label user ".codex/AGENTS.md" 0 "$d/codex"}
      ${homeFile label user ".gemini/config/AGENTS.md" 0 "$d/antigravity"}
      ${homeFile label user ".gemini/GEMINI.md" 0 "$d/gemini"}
      ${homeFile label user ".config/opencode/AGENTS.md" 0 "$d/opencode-global"}
      ${opencodeFile label user "$d/opencode"}

      file=$d/claude
      ${fileRules "~/.claude/CLAUDE.md on ${label}"}
      file=$d/opencode
      ${fileRules "the standalone OpenCode instructions on ${label}"}

      if [ -f "$d/claude" ] && [ -f "$d/opencode" ] && ! cmp -s "$d/claude" "$d/opencode"; then
        echo ${esc "~/.claude/CLAUDE.md and the standalone OpenCode instructions differ on ${label}"} >&2
        failed=1
      fi

      rm -rf "$d"
    '';

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };
in
pkgs.runCommand "agent-instructions-tests"
  {
    nativeBuildInputs = [ pkgs.jq ];
  }
  ''
    ${configurations.userGuard}
    failed=0
    seen=$(mktemp)

    ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

    if [ "$failed" != "0" ]; then
      exit 1
    fi

    touch $out
  ''
