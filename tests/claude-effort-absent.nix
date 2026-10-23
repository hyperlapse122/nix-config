/*
  Check interface:

    import ./tests/claude-effort-absent.nix { inherit pkgs self fixtures; }

  `fixtures` is tests/lib/linux-fixtures.nix. Fails when anything this
  repository renders gives a Claude model an effort again, so Claude Code runs
  every model at its own default. Codex's `reasoningEffort` and Pi's `thinking`
  effort stay allowed. Runs over `userEntries` from
  `tests/lib/configurations.nix`: every NixOS configuration and every
  non-NixOS fixture host, production and bootstrap alike. A macOS user's files
  need an aarch64-darwin builder, so that side is left to the shared modules
  these users run.

  Reads what activation and Home Manager materialize, not the Nix attribute
  sets behind them:
  - each of the five instruction copies in `home-files`, split into sentences
    outside store paths. A sentence that names Claude -- the word, a
    `claude-*` model ID, or a role alias -- and the whole word `effort`,
    `efforts`, `effortLevel`, or `CLAUDE_CODE_EFFORT_LEVEL` fails, and so does
    a `claudeAgent` instance followed by "with `<knob>` `<value>`", which is how
    an assignment carries a knob. `reasoningEffort` and `CROSS_MODEL_EFFORT_OVERRIDE` are
    not whole words, and a sentence about Codex or Pi names no Claude.
  - the declaration JSON that the Claude Code settings merge and the Claude
    Code global config merge are invoked with, found through the `--declared`
    flag of the activation script. Neither may hold a string or key that spells
    an effort outside `remove` and `removePaths`, and the settings merge must
    still retire the top-level `effortLevel` key and
    `modelSettings."claude-opus-5-5".effortLevel` with `prune`, so the value
    an earlier rebuild wrote goes.
  - the declaration JSON the T3 Code settings merge is invoked with, found the
    same way. It must own at least one selection on the `claudeAgent` instance,
    and no such selection may carry anything that spells an effort. It is read
    wherever the T3 Code trait is on, and the builder fails when no user
    environment has it on.

  The self-test applies each mutant to the real rendering or declaration of
  the first user environment and requires this check's own message:
  - instruction copies: a `claudeAgent` assignment given `effort` `high`, one
    given another knob, a sentence that names a `claude-*` model and an effort
    in words, and one that sets `effortLevel`. A Codex `reasoningEffort`
    `xhigh` assignment, a sentence naming a store path that spells `effort`,
    and the real Pi copy's `thought_level=<effort>` must pass, and the builder
    fails when the real copies no longer carry them, so those passes are not
    vacuous.
  - the Claude declaration: the Opus `effortLevel` path set again, `effortLevel`
    in the settings tier, either retirement dropped, and an `effortLevel` in
    the global config tier.
  - the T3 Code declaration: an `effort` option on `defaultModelSelection` or
    on `textGenerationModelSelection`, and no selection left on `claudeAgent`.
    An effort on a selection that is not on `claudeAgent` passes.
  - the wiring: an activation script whose declared-settings flag is gone, and
    one whose flag points at a declaration that spells an effort. The first
    must name the missing file and the second must follow the flag to it, so
    the check cannot pass on a declaration the activation never reads.
  Every mutant is applied by an edit that must change its input, so a rewording
  that stops matching fails the builder instead of passing as a no-op.

  See
  .compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md
  and
  .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md

  Every lookup carries an `or` fallback and each store path is interpolated
  only inside its present branch, so a removed declaration fails inside the
  builder rather than during evaluation. The builder collects every failure
  instead of exiting at the first.
*/
{
  pkgs,
  self,
  fixtures,
}:
let
  inherit (pkgs) lib;

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  esc = value: lib.escapeShellArg (toString value);

  deliveryPaths = [
    ".pi/agent/AGENTS.md"
    ".claude/CLAUDE.md"
    ".codex/AGENTS.md"
    ".config/opencode/AGENTS.md"
    ".gemini/config/AGENTS.md"
  ];

  # Prints each sentence of the file that pairs Claude with an effort, outside
  # store paths, and exits 1 when it printed any. Sentences end at a full stop
  # and a space, as in tests/agent-instructions.nix.
  sentenceProgram = pkgs.writeText "claude-effort-absent-sentences.awk" ''
    function hasWord(line, term,    from, pos, before, after) {
      from = 1
      while ((pos = index(substr(line, from), term)) > 0) {
        pos += from - 1
        before = (pos > 1) ? substr(line, pos - 1, 1) : ""
        after = substr(line, pos + length(term), 1)
        if (before !~ /[[:alnum:]_]/ && after !~ /[[:alnum:]_]/) return 1
        from = pos + 1
      }
      return 0
    }
    {
      line = $0
      gsub(/\/nix\/store\/[0-9a-z]{32}-[^[:space:]`"]*/, "", line)
      count = split(line, sentences, /\. /)
      for (i = 1; i <= count; i++) {
        original = sentences[i]
        lowered = tolower(original)
        if (lowered ~ /`claudeagent` instance with `[^`]+` `[^`]+`/) {
          print "a claudeAgent assignment carries a knob: " original
          bad = 1
        }
        claude = (lowered ~ /claude/ || lowered ~ /`(opus|sonnet|haiku|fable)`/)
        effort = (hasWord(lowered, "effort") || hasWord(lowered, "efforts") || hasWord(lowered, "effortlevel") || hasWord(lowered, "claude_code_effort_level"))
        if (claude && effort) {
          print "a sentence gives a Claude model an effort: " original
          bad = 1
        }
      }
    }
    END { exit bad }
  '';

  # The Claude Code merges. `retire` is true for settings.json, whose
  # declaration must keep the two retirements of the Opus effort.
  claudeProgram = pkgs.writeText "claude-effort-absent-claude.jq" ''
    (
      del(.remove, .removePaths)
      | [ (paths | .[] | strings), (.. | strings) ]
      | map(select(ascii_downcase | test("effort")))
      | unique
      | .[]
      | "declares an effort outside its retirements: \(.)"
    ),
    (
      if $retire and (((.remove // []) | any(. == "effortLevel")) | not) then
        "no longer retires the top-level effortLevel key"
      else empty end
    ),
    (
      if $retire and (((.removePaths // []) | any(
        .path == ["modelSettings", "claude-opus-5-5"] and .key == "effortLevel" and .prune == true
      )) | not) then
        "no longer retires modelSettings.claude-opus-5-5.effortLevel with prune"
      else empty end
    )
  '';

  # The T3 Code settings merge: every selection on the claudeAgent instance,
  # wherever the declaration puts it.
  t3Program = pkgs.writeText "claude-effort-absent-t3.jq" ''
    [.. | objects | select(.instanceId? == "claudeAgent")] as $selections
    | (
        if ($selections | length) == 0 then
          "declares no model selection on the claudeAgent instance"
        else empty end
      ),
      (
        $selections[]
        | select(tojson | ascii_downcase | test("effort"))
        | "a claudeAgent selection carries an effort: \(tojson)"
      )
  '';

  # A store path that spells `effort` in its name, which the sentence rule must
  # not read.
  storePathCase = "- Claude `sonnet` reads /nix/store/0123456789abcdfghijklmnpqrsvwxyz-effort-tools for the notes.";
  codexCase = "- Codex runs `gpt-6.1-sol` on the `codex` instance with `reasoningEffort` `xhigh`.";
  # The Pi ACP command carries `<effort>`; Pi reads no ACP section, so this
  # holds in the copies that do.
  piEffortTerm = "thought_level=<effort>";

  userOf = entry: entry.user;
  activation = user: name: user.home.activation.${name}.data or "";
  t3On = user: (user.my.t3.cli.enable or false) || (user.my.t3.desktop.enable or false);

  base = lib.head configurations.userEntries;
  t3Base = lib.findFirst (entry: t3On entry.user) null configurations.userEntries;

  assertEntry =
    entry:
    let
      label = entry.name;
      user = userOf entry;
      homeFiles = user.home-files or null;
    in
    lib.optionalString (homeFiles == null) ''
      echo ${esc "no materialized home-files on ${label}"} >&2
      failed=1
    ''
    + lib.optionalString (homeFiles != null) (
      lib.concatMapStrings (target: ''
        file=${homeFiles}/${target}
        if [ ! -s "$file" ]; then
          echo ${esc "~/${target} on ${label} is missing or empty in home-files"} >&2
          failed=1
        else
          instructionProblems "$file" > "$scratch/problems" || {
            sed ${esc "s|^|the instructions at ~/${target} on ${label}: |"} "$scratch/problems" >&2
            failed=1
          }
        fi
      '') deliveryPaths
    )
    + ''
      checkDeclaration ${esc "the Claude Code settings merge on ${label}"} claude-settings ${esc (activation user "claudeSettings")} || failed=1
      checkDeclaration ${esc "the Claude Code global config merge on ${label}"} claude-global ${esc (activation user "claudeGlobalConfig")} || failed=1
    ''
    + lib.optionalString (t3On user) ''
      t3Covered=$((t3Covered + 1))
      checkDeclaration ${esc "the T3 Code settings merge on ${label}"} t3-settings ${esc (activation user "t3codeSettings")} || failed=1
    '';

  selfTest =
    let
      baseUser = userOf base;
      baseFiles = baseUser.home-files or null;
      t3Script = if t3Base == null then "" else activation (userOf t3Base) "t3codeSettings";
    in
    ''
      ${
        if baseFiles == null then
          ''
            echo ${esc "self-test: no materialized home-files on ${base.name}"} >&2
            selfTestFailed=1
          ''
        else
          ''
            claudeCopy=${baseFiles}/.claude/CLAUDE.md
            piCopy=${baseFiles}/.pi/agent/AGENTS.md
            if [ ! -s "$claudeCopy" ] || [ ! -s "$piCopy" ]; then
              echo "self-test: the instruction copies of the first user are missing" >&2
              selfTestFailed=1
            else
              expectPass 'the real Claude Code copy' instructionProblems "$claudeCopy"
              expectPass 'the real Pi copy' instructionProblems "$piCopy"
              if ! grep -qF -- ${esc "`reasoningEffort` `xhigh`"} "$claudeCopy"; then
                echo "self-test: the real copy no longer carries the Codex reasoningEffort xhigh assignment, so that pass would be vacuous" >&2
                selfTestFailed=1
              fi
              if ! grep -qF -- ${esc piEffortTerm} "$claudeCopy"; then
                echo "self-test: the real copy no longer carries Pi's thought_level=<effort>, so that pass would be vacuous" >&2
                selfTestFailed=1
              fi

              textMutant() { # name, expected message, sed program
                local name=$1 expect=$2 program=$3 mutated
                mutated=$(mktemp)
                sed -E "$program" "$claudeCopy" > "$mutated"
                if applied "$name" "$claudeCopy" "$mutated"; then
                  expectFail "$name" "$expect" instructionProblems "$mutated"
                fi
              }
              appended() { # name, expected message, line; expected message empty means it must pass
                local name=$1 expect=$2 mutated
                mutated=$(mktemp)
                { cat "$claudeCopy"; printf '%s\n' "$3"; } > "$mutated"
                if [ -n "$expect" ]; then
                  expectFail "$name" "$expect" instructionProblems "$mutated"
                else
                  expectPass "$name" instructionProblems "$mutated"
                fi
              }

              textMutant 'a claudeAgent assignment given effort high' \
                'a claudeAgent assignment carries a knob' \
                '0,/on the `claudeAgent` instance/s//on the `claudeAgent` instance with `effort` `high`/'
              textMutant 'a claudeAgent assignment given another knob' \
                'a claudeAgent assignment carries a knob' \
                '0,/on the `claudeAgent` instance/s//on the `claudeAgent` instance with `thinking` `max`/'
              appended 'a claude-* model with an effort in words' \
                'a sentence gives a Claude model an effort' \
                '- Launch a `claude-opus-5-5` scout at high effort.'
              appended 'a Claude sentence that sets effortLevel' \
                'a sentence gives a Claude model an effort' \
                '- Set `effortLevel` to `medium` for Claude Code.'
              appended 'a role alias with CLAUDE_CODE_EFFORT_LEVEL' \
                'a sentence gives a Claude model an effort' \
                '- Run `sonnet` with CLAUDE_CODE_EFFORT_LEVEL set to `high`.'
              appended 'a Codex reasoningEffort xhigh assignment' "" ${esc codexCase}
              appended 'a store path whose name spells effort' "" ${esc storePathCase}
            fi
          ''
      }

      ${
        if activation baseUser "claudeSettings" == "" then
          ''
            echo ${esc "self-test: no Claude Code settings activation on ${base.name}"} >&2
            selfTestFailed=1
          ''
        else
          ''
            claudeScript=${esc (activation baseUser "claudeSettings")}
            claudeDeclared=$(declaredIn "$claudeScript")
            globalDeclared=$(declaredIn ${esc (activation baseUser "claudeGlobalConfig")})
            if [ -z "$claudeDeclared" ] || [ ! -s "$claudeDeclared" ] || [ -z "$globalDeclared" ] || [ ! -s "$globalDeclared" ]; then
              echo "self-test: the first user's Claude Code activation passes no declared-settings file" >&2
              selfTestFailed=1
            else
              expectPass 'the real Claude Code settings declaration' declarationProblems claude-settings "$claudeDeclared"
              expectPass 'the real Claude Code global config declaration' declarationProblems claude-global "$globalDeclared"

              jsonMutant 'the Opus effortLevel path set again' claude-settings 'declares an effort outside its retirements' "$claudeDeclared" \
                '.setPaths += [{path: ["modelSettings", "claude-opus-5-5", "effortLevel"], value: "xhigh"}]'
              jsonMutant 'effortLevel in the settings tier' claude-settings 'declares an effort outside its retirements' "$claudeDeclared" \
                '.set.effortLevel = "medium"'
              jsonMutant 'the removePaths retirement dropped' claude-settings 'no longer retires modelSettings.claude-opus-5-5.effortLevel with prune' "$claudeDeclared" \
                '.removePaths = []'
              jsonMutant 'the prune flag dropped' claude-settings 'no longer retires modelSettings.claude-opus-5-5.effortLevel with prune' "$claudeDeclared" \
                '.removePaths |= map(del(.prune))'
              jsonMutant 'the top-level retirement dropped' claude-settings 'no longer retires the top-level effortLevel key' "$claudeDeclared" \
                '.remove -= ["effortLevel"]'
              jsonMutant 'effortLevel in the global config tier' claude-global 'declares an effort outside its retirements' "$globalDeclared" \
                '.set.effortLevel = "high"'

              # The wiring: the check reads the file the activation script
              # names, so a script that names none, or names another file,
              # cannot pass on a clean declaration elsewhere.
              decoy=$(mktemp)
              jq '.set.effortLevel = "high"' "$claudeDeclared" > "$decoy"
              expectFail 'an activation script with no declared-settings flag' \
                'passes no declared-settings file' \
                checkDeclaration 'the self-test script' claude-settings "''${claudeScript//--declared/--other}"
              expectFail 'an activation script whose flag points at a declaration that spells an effort' \
                'declares an effort outside its retirements' \
                checkDeclaration 'the self-test script' claude-settings "''${claudeScript//$claudeDeclared/$decoy}"
              # The decoy lives outside the store, so the path pattern of
              # declaredIn must accept it for the mutant above to be read.
            fi
          ''
      }

      ${
        if t3Base == null then
          ''
            echo 'self-test: no user environment turns the T3 Code trait on' >&2
            selfTestFailed=1
          ''
        else
          ''
            t3Script=${esc t3Script}
            t3Declared=$(declaredIn "$t3Script")
            if [ -z "$t3Declared" ] || [ ! -s "$t3Declared" ]; then
              echo "self-test: the T3 Code activation passes no declared-settings file" >&2
              selfTestFailed=1
            else
              expectPass 'the real T3 Code settings declaration' declarationProblems t3-settings "$t3Declared"
              jsonMutant 'an effort option on defaultModelSelection' t3-settings 'a claudeAgent selection carries an effort' "$t3Declared" \
                '.own.defaultModelSelection.options = [{id: "effort", value: "high"}]'
              jsonMutant 'an effort option on textGenerationModelSelection' t3-settings 'a claudeAgent selection carries an effort' "$t3Declared" \
                '.own.textGenerationModelSelection.options = [{id: "effort", value: "medium"}]'
              jsonMutant 'no selection left on claudeAgent' t3-settings 'declares no model selection on the claudeAgent instance' "$t3Declared" \
                '.own |= with_entries(.value.instanceId = "codex")'
              codexSelection=$(mktemp)
              jq '.own.defaultModelSelection |= (.instanceId = "codex" | .options = [{id: "reasoningEffort", value: "xhigh"}])' "$t3Declared" > "$codexSelection"
              if applied 'a Codex selection with a reasoning effort' "$t3Declared" "$codexSelection"; then
                expectPass 'a Codex selection with a reasoning effort' declarationProblems t3-settings "$codexSelection"
              fi
            fi
          ''
      }
    '';
in
pkgs.runCommand "claude-effort-absent-tests"
  {
    nativeBuildInputs = [
      pkgs.gawk
      pkgs.jq
    ];
  }
  ''
    ${configurations.guard}
    ${configurations.userGuard}
    failed=0
    t3Covered=0
    scratch=$(mktemp -d)

    # Prints the sentences of an instruction copy that give a Claude model an
    # effort; the status is 1 when there are any.
    instructionProblems() {
      awk -f ${sentenceProgram} "$1"
    }

    # The declared-settings file an activation script hands the merger.
    declaredIn() {
      printf '%s' "$1" | tr '\n' ' ' | grep -oE -- '--declared[[:space:]]+/[^[:space:]]+' \
        | head -1 | awk '{print $2}' || true
    }

    # Prints what a declaration holds that it must not, or lacks, and fails
    # when it prints anything.
    declarationProblems() {
      local out
      case "$1" in
        claude-settings) out=$(jq -r --argjson retire true -f ${claudeProgram} "$2") ;;
        claude-global) out=$(jq -r --argjson retire false -f ${claudeProgram} "$2") ;;
        t3-settings) out=$(jq -r -f ${t3Program} "$2") ;;
      esac || return 1
      if [ -n "$out" ]; then
        printf '%s\n' "$out"
        return 1
      fi
    }

    # Follows the --declared flag of an activation script to the declaration
    # it is invoked with, so a declaration the activation never reads cannot
    # be what passes.
    checkDeclaration() {
      local label=$1 kind=$2 script=$3 declared problems
      declared=$(declaredIn "$script")
      if [ -z "$declared" ] || [ ! -s "$declared" ]; then
        echo "$label passes no declared-settings file" >&2
        return 1
      fi
      problems=$(declarationProblems "$kind" "$declared") || {
        printf '%s\n' "$problems" | sed "s|^|$label: |" >&2
        return 1
      }
    }

    ${lib.concatMapStrings assertEntry configurations.userEntries}

    if [ "$t3Covered" = "0" ]; then
      echo 'no user environment turns the T3 Code trait on, so the T3 Code side of this check covered none' >&2
      failed=1
    fi

    selfTestFailed=0

    # Runs a command that must fail with the given message.
    expectFail() {
      local name=$1 expect=$2 out
      shift 2
      if out=$("$@" 2>&1); then
        echo "self-test: a mutant passed: $name" >&2
        selfTestFailed=1
      elif ! grep -qF -- "$expect" <<< "$out"; then
        echo "self-test: a mutant failed without the expected message ($expect): $name" >&2
        printf '%s\n' "$out" >&2
        selfTestFailed=1
      fi
    }
    expectPass() {
      local name=$1 out
      shift
      if ! out=$("$@" 2>&1); then
        echo "self-test: an allowed case failed: $name" >&2
        printf '%s\n' "$out" >&2
        selfTestFailed=1
      fi
    }
    # Edits the file, and reports an edit that changed nothing.
    applied() {
      local name=$1 original=$2 mutated=$3
      if cmp -s "$original" "$mutated"; then
        echo "self-test: the mutation did not apply: $name" >&2
        selfTestFailed=1
        return 1
      fi
    }

    jsonMutant() { # name, kind, expected message, base file, jq filter
      local name=$1 kind=$2 expect=$3 source=$4 mutated
      mutated=$(mktemp)
      jq "$5" "$source" > "$mutated"
      if applied "$name" "$source" "$mutated"; then
        expectFail "$name" "$expect" declarationProblems "$kind" "$mutated"
      fi
    }

    ${selfTest}

    if [ "$failed" != "0" ] || [ "$selfTestFailed" != "0" ]; then
      exit 1
    fi

    touch $out
  ''
