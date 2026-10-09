/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions reach each harness's user-level
  instruction file for user `h82` on every host this flake declares, rendered
  by gomplate from the one shared template with that harness's context.

  The user list is `userEntries` from `tests/lib/configurations.nix`: the h82
  generation of every NixOS configuration and of every non-NixOS fixture host,
  so a host of either kind added later is covered the day it is added, and the
  helper's guard fails the build when either kind is missing instead of
  letting it pass.

  Verifies, per Home Manager user and per harness:
  - exactly one enabled Home Manager file resolves to the harness's target.
    The lookup compares each entry's resolved `target` rather than its
    attribute name, and reads `enable`, because either can move the file
    without changing its text. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - the materialized file carries the shared body's opening sentence with this
    harness's name filled in, so a context carrying the other harness's name
    fails.
  - it carries the shared rule to apply every review finding and its ban on
    deferring findings, so either sentence dropped from the template or moved
    into one harness's branch fails.
  - it carries the shared cross-model delegation rules through the T3 Code
    MCP server: when they apply, their precedence over a skill's own harness
    discovery, choosing the latest runnable version of a model class and when
    an older one is allowed, setting that version's options, full-access
    runtime mode, running a skill's cross-model review
    pass alongside its in-process reviewers, the fallback order, and verifying
    a delegated result, so any of those sentences dropped, reworded, or moved
    into one harness's branch fails.
  - it exists and is non-empty.
  - it carries the shared branch-name rule: rename a placeholder before the
    first push, what counts as a tool-generated placeholder (including a
    random-hex branch), only a branch never pushed, and the
    `type/short-kebab-slug` fallback, so any of those sentences dropped or
    moved into one harness's branch fails.
  - it names every native tool its harness template maps, and none of the
    other harnesses', so a branch keyed on the wrong id, or swapped targets,
    fail.
  - no template action (`{{`, `}}`) or `<no value>` survives in it, which is
    what gomplate prints for a missing key when `--missing-key error` is lost.

  The expected sentence and tool names are literals here, not read from the
  module, so a mutation of the templates turns this red.

  Every lookup carries an `or` fallback and the store path is interpolated only
  inside the present branch, so a removed declaration fails inside the builder
  rather than during evaluation. See
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

  reviewFindingsSentences = [
    "Apply every finding that `ce-code-review` and `ce-simplify-code` report, whatever its severity, P2 and P3 included."
    "Do not defer a finding to a residual list, a follow-up ticket, or a note in the pull request body."
  ];

  branchNameSentences = [
    "Before the first push of a branch, check whether its name describes the change, and rename it locally with `git branch -m` when it does not."
    "A tool-generated placeholder, such as a worktree codename like `hyperlapse122/mooneye` or `worktree-memoized-juggling-hartmanis`, or a random-hex branch like `t3code/1a2b3c4d`, does not describe a change."
    "Rename only a branch that has never been pushed: no remote branch of the same name exists and no pull request uses it."
    "When the project documents no rule, name the branch `type/short-kebab-slug`: a Conventional Commits type such as `feat`, `fix`, `docs`, `refactor`, or `chore`, then a few lowercase hyphenated words that describe the change."
  ];

  delegationSentences = [
    "This section applies only when the T3 Code MCP tools are available in this session and the work needs a provider other than your own or a model your native subagent tool cannot serve; otherwise, keep using the native subagent tool."
    "When a skill tells you to discover, attest, or launch another harness for cross-model work, delegate through T3 Code instead, before any of the skill's own discovery or launch steps."
    "Once you know which model class suits the task (Sol, Luna, or Astra for Codex; Opus, Sonnet, or Haiku for Claude; Pro or Flash for Gemini), choose the latest version of that class that `orchestrator_capabilities` lists as runnable."
    "Compare versions only within that class: a newer model of another class does not outrank the class the task needs."
    "Choose an older version only when the latest is unavailable, has failed in this session, or the user or project asked for that version, and say why when you name the model."
    "Set the chosen version's options, such as reasoning effort, for the task instead of inheriting its defaults, which can differ between versions of one class."
    "Run every delegated task in full-access runtime mode."
    "When a skill's review procedure turns on its cross-model pass, delegate that pass asynchronously in the same step that dispatches the skill's in-process reviewers, and merge its result when it returns; never add a cross-model pass the skill would not run."
    "When a delegated task fails, reports a provider error, or shows no progress, cancel it with `task_cancel` and retry the same task on another runnable T3 Code provider; fall back to the skill's own cross-model method only when no T3 Code provider succeeds, and tell the user that you did."
    "Verify a delegated result against the repository or other primary evidence before you rely on it or report it as fact."
  ];

  claudeTools = [
    "`Read`"
    "`Edit`"
    "`Write`"
    "`NotebookEdit`"
    "`WebFetch`"
    "`WebSearch`"
    "`AskUserQuestion`"
    "`Agent`"
    "`Bash`"
  ];

  antigravityTools = [
    "`view_file`"
    "`replace_file_content`"
    "`write_to_file`"
    "`read_url_content`"
    "`search_web`"
    "`ask_question`"
    "`invoke_subagent`"
    "`manage_task`"
    "`schedule`"
    "`run_command`"
  ];

  codexTools = [
    "`apply_patch`"
    "`view_image`"
    "`web_search`"
    "`request_user_input`"
    "`spawn_agent`"
    "`update_plan`"
    "`exec_command`"
  ];

  harnesses = [
    {
      name = "Claude Code";
      sharedSentence = "Use the tools Claude Code provides natively before reaching for a shell equivalent.";
      target = ".claude/CLAUDE.md";
      present = claudeTools;
      absent = antigravityTools ++ codexTools;
    }
    {
      name = "Antigravity";
      sharedSentence = "Use the tools Antigravity provides natively before reaching for a shell equivalent.";
      target = ".gemini/config/AGENTS.md";
      present = antigravityTools;
      absent = claudeTools ++ codexTools;
    }
    {
      name = "Codex";
      sharedSentence = "Use the tools Codex provides natively before reaching for a shell equivalent.";
      target = ".codex/AGENTS.md";
      present = codexTools;
      absent = claudeTools ++ antigravityTools;
    }
  ];

  # Fails the build, naming each sentence, when `$file` lacks any of them.
  requireSentences = message: sentences: ''
    for sentence in ${lib.escapeShellArgs sentences}; do
      if ! grep -qF -- "$sentence" "$file"; then
        echo ${esc message} "$sentence" >&2
        failed=1
      fi
    done
  '';

  assertHarness =
    hostName: userConfig: harness:
    let
      entries = lib.filter (file: (file.target or "") == harness.target) (
        lib.attrValues (userConfig.home.file or { })
      );
      entry = if lib.length entries == 1 then lib.head entries else null;
      source = if entry == null then null else (entry.source or null);
      label = "${harness.name} (${harness.target}) on ${hostName}";

      countWrong = lib.optionalString (lib.length entries != 1) ''
        echo ${esc "expected exactly one home.file for ${label}, found ${toString (lib.length entries)}"} >&2
        failed=1
      '';

      entryPresent = lib.optionalString (entry != null) ''
        if [ ${esc (lib.boolToString (entry.enable or false))} != "true" ]; then
          echo ${esc "home.file for ${label} is not enabled"} >&2
          failed=1
        fi
      '';

      sourcePresent = lib.optionalString (source != null) ''
        file=${source}
        if [ ! -s "$file" ]; then
          echo ${esc "${label} is missing or empty"} >&2
          failed=1
        fi
        if ! grep -qF -- ${esc harness.sharedSentence} "$file"; then
          echo ${esc "${label} lacks the shared instructions"} >&2
          failed=1
        fi
        ${requireSentences "${label} lacks the review-findings rule:" reviewFindingsSentences}
        ${requireSentences "${label} lacks the cross-model delegation rule:" delegationSentences}
        ${requireSentences "${label} lacks the branch-name rule:" branchNameSentences}
        for tool in ${lib.escapeShellArgs harness.present}; do
          if ! grep -qF -- "$tool" "$file"; then
            echo ${esc "${label} does not name"} "$tool" >&2
            failed=1
          fi
        done
        for tool in ${lib.escapeShellArgs harness.absent}; do
          if grep -qF -- "$tool" "$file"; then
            echo ${esc "${label} names another harness's tool"} "$tool" >&2
            failed=1
          fi
        done
        if grep -qE '\{\{|\}\}|<no value>' "$file"; then
          echo ${esc "${label} carries an unrendered template action"} >&2
          failed=1
        fi
      '';

      sourceAbsent = lib.optionalString (entry != null && source == null) ''
        echo ${esc "home.file for ${label} has no source"} >&2
        failed=1
      '';
    in
    countWrong + entryPresent + sourcePresent + sourceAbsent;

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  assertEntry = entry: lib.concatMapStrings (assertHarness entry.name entry.user) harnesses;
in
pkgs.runCommand "agent-instructions-tests" { } ''
  ${configurations.userGuard}
  failed=0

  ${lib.concatMapStringsSep "\n" assertEntry configurations.userEntries}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
