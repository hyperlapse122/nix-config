/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions, one plain file rendered with the
  user's card key, reach every installed harness for user `h82` on every host
  this flake declares:

    Claude Code       ~/.claude/CLAUDE.md, which T3 Code's Claude sessions read
    OpenCode          ~/.config/opencode/AGENTS.md, which every run loads
    Antigravity CLI   ~/.gemini/config/AGENTS.md

  The user list is `userEntries` from `tests/lib/configurations.nix`.

  Verifies, per Home Manager user:
  - exactly one enabled Home Manager file resolves to each delivery path, and
    none to the retired ~/.t3/instructions/claude-code/CLAUDE.md, Codex's
    ~/.codex/AGENTS.md, or Gemini's ~/.gemini/GEMINI.md, none of which is
    installed. The lookup compares each entry's resolved `target` rather than
    its attribute name, and reads `enable`, because either can move the file
    without changing its text.
  - each delivery path exists in the materialized `home-files`, and the three
    files there are byte-identical. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - every pinned sentence appears exactly once and starts where a sentence
    starts, so a dropped, doubled, or negated ("Do not ...") rule fails. See
    .compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md
  - the recipient sentence names the entry's own `my.user.gpgKey`, and Git
    signs with that same key. The fixture host whose key is the fake value
    below must carry neither the card fingerprint in its instructions nor the
    card key in its Git config, so a literal fingerprint left in the
    instructions or in Git turns this red. The fake entry is selected by its
    evaluated key, never by its name, and the builder fails when no entry
    carries it on x86_64-linux, where that fixture builds. See
    .compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md
  - the file names no removed section, harness, model, or rule, matched
    without regard to case, and carries no template action (`{{`, `}}`,
    `<no value>`) or unrendered `@name@` placeholder.

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

  cardKey = "621512777E6933FEB4458FDC4945855D4F283F05";
  fakeKey = "0123456789ABCDEF0123456789ABCDEF01234567";

  recipientSentence =
    key:
    "For a new SOPS setup or secret file, use the card key `${key}` as the user's recipient, plus a machine's own recipient when it must decrypt without the card.";

  pinnedSentences = [
    "# GPG and encryption"
    "Run GPG signing, decryption, and encryption yourself, including SOPS re-encryption and edits; when a pinentry dialog appears, let it reach the user."
    "Never print decrypted values, pass them as arguments, or open decrypted files with the file tools; pipe decrypted output straight into the command that consumes it."
    "Leave card administration and key management to the user."
    "# Git"
    "Follow the project's documented naming rule; otherwise name it `<kind>/short-kebab-slug` with a full-word GitHub Flow kind: `feature/`, `fix/`, `docs/`, `chore/`, or `refactor/`."
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
    "# T3 Code"
    "When the session lists T3 Code's delegation tools, such as `delegate_task`, delegate subagent work through them; otherwise use your native subagent tool."
    "When the session lists T3 Code's pull request tools, such as `watch_pull_request`, use them to watch a request you babysit instead of your own background wait."
  ];

  removedTerms = [
    "# Tool use"
    "# Cross-model review"
    "# Delegation"
    "cross-model peer"
    "type/short-kebab-slug"
    "Conventional Commits type"
    "Gemini"
    "gemini-"
    "Argon"
    "Flash"
    "Codex"
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

  fileRules = label: key: absentKeys: ''
    if [ ! -s "$file" ]; then
      echo ${esc "${label} is missing or empty"} >&2
      failed=1
    else
      ${requireSentences "${label} does not hold this sentence exactly once, where a sentence starts:" (
        pinnedSentences ++ [ (recipientSentence key) ]
      )}
      for term in ${lib.escapeShellArgs removedTerms}; do
        if grep -qiF -- "$term" "$file"; then
          echo ${esc "${label} names something the instructions no longer carry:"} "$term" >&2
          failed=1
        fi
      done
      for key in ${lib.escapeShellArgs absentKeys}; do
        if grep -qF -- "$key" "$file"; then
          echo ${esc "${label} names a key other than the host's my.user.gpgKey:"} "$key" >&2
          failed=1
        fi
      done
      if grep -qE '\{\{|\}\}|<no value>|@[A-Za-z_]+@' "$file"; then
        echo ${esc "${label} carries an unrendered template action or placeholder"} >&2
        failed=1
      fi
    fi
  '';

  homeFile =
    label: userConfig: target: want:
    let
      entries = lib.filter (file: (file.target or "") == target) (
        lib.attrValues (userConfig.home.file or { })
      );
      entry = if lib.length entries == 1 then lib.head entries else null;
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
    '';

  deliveryPaths = [
    ".claude/CLAUDE.md"
    ".config/opencode/AGENTS.md"
    ".gemini/config/AGENTS.md"
  ];

  retiredPaths = [
    ".t3/instructions/claude-code/CLAUDE.md"
    ".codex/AGENTS.md"
    ".gemini/GEMINI.md"
  ];

  assertEntry =
    entry:
    let
      label = entry.name;
      user = entry.user;
      key = user.my.user.gpgKey or null;
      fake = key == fakeKey;
      homeFiles = user.home-files or null;
    in
    ''
      ${lib.concatMapStrings (target: homeFile label user target 1) deliveryPaths}
      ${lib.concatMapStrings (target: homeFile label user target 0) retiredPaths}
    ''
    + lib.optionalString (key == null) ''
      echo ${esc "my.user.gpgKey is unset on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (homeFiles == null) ''
      echo ${esc "no materialized home-files on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (key != null && homeFiles != null) ''
      ${lib.optionalString fake "fakeEntries=$((fakeEntries + 1))"}
      first=
      for target in ${lib.escapeShellArgs deliveryPaths}; do
        file=${homeFiles}/$target
        label=${esc "~/"}$target${esc " on ${label}"}
        if [ ! -s "$file" ]; then
          echo "$label is missing or empty in home-files" >&2
          failed=1
          continue
        fi
        if [ -z "$first" ]; then
          first=$target
        elif ! cmp -s "$file" ${homeFiles}/"$first"; then
          echo "$label differs from ~/$first" >&2
          failed=1
        fi
      done

      file=${homeFiles}/.claude/CLAUDE.md
      ${fileRules "the shared instructions on ${label}" key (lib.optional fake cardKey)}

      gitConfig=${homeFiles}/.config/git/config
      if ! grep -qxF -- ${esc "\tsigningKey = \"${key}\""} "$gitConfig" 2>/dev/null; then
        echo ${esc "Git on ${label} does not sign with my.user.gpgKey"} >&2
        failed=1
      fi
      ${lib.optionalString fake ''
        if grep -qF -- ${esc cardKey} "$gitConfig" 2>/dev/null; then
          echo ${esc "Git on ${label} names the card key instead of my.user.gpgKey"} >&2
          failed=1
        fi
      ''}
    '';

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };
in
pkgs.runCommand "agent-instructions-tests" { } ''
  ${configurations.userGuard}
  failed=0
  fakeEntries=0

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  ${lib.optionalString (pkgs.stdenv.hostPlatform.system == "x86_64-linux") ''
    if [ "$fakeEntries" = "0" ]; then
      echo ${esc "no user entry carries the fake my.user.gpgKey, so a literal fingerprint would pass"} >&2
      failed=1
    fi
  ''}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
