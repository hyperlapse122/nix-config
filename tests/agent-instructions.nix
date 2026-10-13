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
  - it carries the shared review-findings rule: the coverage of every
    `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` finding, its
    override of those skills' and their callers' apply bars, deferral steps,
    and review prompts, the outlets a finding may not be parked in, and the
    stop when an autonomous fix would reverse a user decision, so any of those
    sentences dropped or moved into one harness's branch fails.
  - every required sentence starts where a sentence starts, so a guarded
    sentence negated by a prefix ("Do not ...") fails.
  - it carries the shared model-routing defaults: their precedence below the
    conversation, project instructions, and CE config, the one-line reason for
    leaving the table, the tier-to-row mapping, the broad-scout fallback, the
    excluded models, default effort, where same-provider and cross-provider
    routing apply, the inherit-and-say rule, and each row of the role table
    matched whole, so any sentence dropped, reworded, or moved into one
    harness's branch, or any cell changed, fails.
  - it carries the shared cross-model delegation rules through the T3 Code
    MCP server: when they apply, that a skill's gates decide before T3 Code
    replaces its launch route, choosing the latest runnable version of a
    model class and when an older one is allowed, taking a cross-model pass's
    model and effort from the skill, full-access runtime mode, running a
    skill's cross-model review pass alongside its in-process reviewers, the
    retry and fallback order, and verifying a delegated result, so any of
    those sentences dropped, reworded, or moved into one harness's branch
    fails.
  - it carries no superseded directive: delegating before a skill's own
    gates, setting effort instead of inheriting a model's default, or the
    review-findings rule that named only `ce-code-review` and
    `ce-simplify-code`, so any of them added back beside its replacement
    fails.
  - it exists and is non-empty.
  - it carries the shared learning-refresh rule: check the commits a push
    would send for broken learnings, which commits those are, leave a learning
    already marked stale alone, one `ce-compound-refresh` run per learning scoped by
    its filename, `mode:non-interactive` in autonomous runs, the refresh as
    its own commit on the current branch, and one push after every run, so
    any of those sentences dropped or moved into one harness's branch fails.
  - it carries the shared branch-name rule: rename a placeholder before the
    first push, what counts as a tool-generated placeholder (including a
    random-hex branch), only a branch never pushed, and the
    `type/short-kebab-slug` fallback, so any of those sentences dropped or
    moved into one harness's branch fails.
  - it carries the shared issue and pull request media rule: which GitHub and
    GitLab items it covers, attaching the conversation's media, capturing
    media when showing would help and when not to, logs as code blocks,
    before-and-after states for visible changes, masking with an opaque box
    placed at the file's real pixel size, stripping metadata, when a file is
    left out, viewing masked files and dense video frames before upload, CLI
    or API upload only, the `gh --attach` commands and the separate-comment
    fallback, the GitLab uploads API and its authentication check on the
    project that receives the upload, reporting failed uploads, and keeping a skill's body
    structure, so any of those sentences dropped, reworded, negated, or moved
    into one harness's branch fails.
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
    "Apply every finding that `ce-code-review` (its cross-model pass included), `ce-simplify-code`, and `ce-doc-review` report, whatever its severity (P2 and P3 included), its confidence, or the list it sits in."
    "This rule overrides the apply bars, deferral steps, and review prompts of those skills and of the skills that call them, such as `lfg` and `ce-work`."
    "Do not park a finding in a residual list, a follow-up ticket, a pull request section of unapplied findings such as `## Unapplied review findings`, a document's `## Deferred / Open Questions` section, or a report-only or FYI listing."
    "In an autonomous run, stop and ask with the question tool when a fix would reverse a decision the user made, such as a `session-settled` entry in the plan."
  ];

  learningRefreshSentences = [
    "Before each push, check whether the commits it would send break a learning, and refresh that learning on the branch before you push."
    "Check the commits the remote branch does not have yet, or, before the first push, the commits since the branch left the default branch."
    "Leave a learning alone when it already carries `status: stale`, so a learning a refresh marked stale is not refreshed again."
    "Run `ce-compound-refresh` once for each learning that cites a collected item, with that learning's filename as the scope hint."
    "In an autonomous run, such as `lfg`, pass `mode:non-interactive`, which marks an ambiguous learning stale instead of asking."
    "Commit the refresh as its own commit on the current branch, separate from the change that caused it, and push it with that change."
    "Let `ce-compound-refresh` push nothing; push once, after every refresh run has finished, so the push carries every refresh commit."
  ];

  branchNameSentences = [
    "Before the first push of a branch, check whether its name describes the change, and rename it locally with `git branch -m` when it does not."
    "A tool-generated placeholder, such as a worktree codename like `hyperlapse122/mooneye` or `worktree-memoized-juggling-hartmanis`, or a random-hex branch like `t3code/1a2b3c4d`, does not describe a change."
    "Rename only a branch that has never been pushed: no remote branch of the same name exists and no pull request uses it."
    "When the project documents no rule, name the branch `type/short-kebab-slug`: a Conventional Commits type such as `feat`, `fix`, `docs`, `refactor`, or `chore`, then a few lowercase hyphenated words that describe the change."
  ];

  mediaSentences = [
    "When you create or edit a GitHub or GitLab issue, pull request, merge request, or a comment on one of them, attach the images and videos a reader needs to see the problem or the change."
    "Attach every image or video from the conversation that relates to the item you are writing."
    "When showing the screen or behavior would help a reader and no media in the conversation already shows it, reproduce it with the tools this session offers, such as browser automation, an app preview, or a device simulator, and capture a screenshot, or a recording when the point is motion or a sequence of steps."
    "Do not capture when reproducing needs production data, a payment, a login you do not already hold, or another action with side effects; tell the user why you captured nothing."
    "Put logs and terminal output in the body as fenced code blocks, not as images."
    "For a pull or merge request that changes something visible, attach the state after the change, and add the state before it when the base revision runs without much effort."
    "Before upload, mask credentials, tokens, passwords, personal data, and internal hosts or addresses with an opaque filled box over the whole region, never with blur or pixelation, which can be reversed."
    "Place each box using the file's real pixel size from `ffprobe`, scaling any coordinates you read off a downscaled view of the image."
    "Before upload, remove embedded metadata, such as location, device, and capture time, from every image and video by re-encoding it with `ffmpeg -map_metadata -1`, including files that need no masking."
    "Leave a file out only when masking would remove what it was meant to show, or when the sensitive content cannot be masked reliably, such as a region you cannot locate in every frame of a recording; tell the user which file you left out and why."
    "Look at every masked file before you upload it."
    "Check a video by extracting a frame at every scene change, with a low threshold so a small overlay counts as one, and at least two frames per second, and view them, both to find what to mask and to confirm the mask held."
    "When something sensitive could appear between the frames you viewed, such as a token typed and cleared within a second, leave the video out."
    "Upload only through the CLI or API, never through the web UI in a browser."
    "On GitHub, pass each file to the `--attach` option of `gh issue create`, `gh issue comment`, `gh issue edit`, `gh pr create`, `gh pr comment`, or `gh pr edit`."
    "When the GitHub item has no `--attach` path, such as a review-thread reply or an edit of a comment other than your last, post the media in a separate `gh issue comment --attach` or `gh pr comment --attach` on the same issue or pull request, and link that comment from the text you wrote."
    "On GitLab, upload each file with `glab api --form file=@<path> projects/:id/uploads` and put the `markdown` field it returns into the body; for a merge request from a fork, upload to the target project instead of `:id`."
    "Before uploading an image to a private or internal GitLab project, read `visibility` and `enforce_auth_checks_on_uploads` from `glab api projects/<project>` for the project you upload to, which for a merge request from a fork is the target project; when authentication is not enforced, upload no images there and tell the user which files you held back, why, and that a maintainer can turn on \"Require authentication to view media files\" in the project's visibility settings."
    "When an upload fails, tell the user which files did not attach, including when `gh` created the item but exited non-zero."
    "When a skill defines the body of an issue or pull request, keep its structure and add the media to it."
  ];

  routingSentences = [
    "Each routing choice follows this order: the user's conversation, then the project's instructions and its CE config (`.compound-engineering/config.local.yaml`, then `.compound-engineering/config.yaml`) in the order the invoked skill defines, then the table below, then the skill's own default mapping."
    "Start from the table's default; when you choose a different model, tell the user in one line which model you chose and why."
    "A skill's cheapest capable (extraction) tier maps to the short scout row; its mid-tier and the native `ce-work` worker map to the worker row."
    "When Antigravity is not runnable through T3 Code, a broad scout uses the short scout's class."
    "Never choose Gemini 3.1 Pro (`gemini-pro-agent`, `gemini-3.1-pro-low`), any Codex Terra model, or any Claude Fable model yourself; use one only when the user, the project, or its CE config names it."
    "Run a delegated or subagent task at the chosen model's default effort unless the table, the skill, its config, the project, or the user names one."
    "Apply the same-provider cells in every session, and route to another provider only through T3 Code, as Cross-model delegation below describes."
    "When your native subagent tool cannot select the table's class and T3 Code is unavailable, let the subagent inherit your session model and say so in one line."
    # Role table rows, each matched whole so a changed cell fails.
    "| Short scout | Haiku | Luna | Flash low |"
    "| Broad scout | Flash low through T3 Code | Flash low through T3 Code | Flash low |"
    "| Worker | Sonnet | Luna | Flash medium |"
  ];

  delegationSentences = [
    "This section applies only when the T3 Code MCP tools are available in this session and the work needs a provider other than your own or a model your native subagent tool cannot serve; otherwise, keep using the native subagent tool."
    "When a skill has decided to run cross-model work and tells you to discover, attest, or launch another harness, delegate that run through T3 Code instead of the skill's own launch route; the skill's gates, such as `cross_model_review_mode`, decide first whether the run happens."
    "Once you know which model class suits the task (Sol, Luna, or Astra for Codex; Opus, Sonnet, or Haiku for Claude; Flash for Gemini), choose the latest version of that class that `orchestrator_capabilities` lists as runnable."
    "Compare versions only within that class: a newer model of another class does not outrank the class the task needs."
    "Choose an older version only when the latest is unavailable, has failed in this session, or the user or project asked for that version, and say why when you name the model."
    "When a skill's cross-model pass runs through T3 Code, take its model and effort from `cross_model_model` and `cross_model_effort` when they are set, otherwise from the skill's own mapping; the latest-version rule does not replace a model the skill names."
    "Run every delegated task in full-access runtime mode."
    "When a skill's review procedure turns on its cross-model pass, delegate that pass asynchronously in the same step that dispatches the skill's in-process reviewers, and merge its result when it returns; never add a cross-model pass the skill would not run."
    "When a delegated task fails, reports a provider error, or shows no progress, cancel it with `task_cancel` and retry the same task on another runnable T3 Code provider."
    "A retried cross-model pass uses the skill's mapping for that provider when the skill has one, and the latest Flash at high effort on Antigravity, which the skills do not map."
    "Fall back to the skill's own cross-model method only when no T3 Code provider succeeds, and tell the user that you did."
    "Verify a delegated result against the repository or other primary evidence before you rely on it or report it as fact."
  ];

  # Fragments of directives this template replaced; each contradicts a rule
  # above, so its return must fail even while the replacement is present.
  supersededDirectives = [
    "before any of the skill's own discovery or launch steps"
    "for the task instead of inheriting its defaults"
    "Apply every finding that `ce-code-review` and `ce-simplify-code` report"
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
  # A sentence counts only where one begins: at the start of a line, after a
  # list marker, or after the previous sentence's full stop. A substring match
  # would accept the sentence inside its own negation ("Do not Apply every...").
  requireSentences = message: sentences: ''
    for sentence in ${lib.escapeShellArgs sentences}; do
      if ! awk -v s="$sentence" '
        {
          i = index($0, s)
          if (i == 0) next
          pre = substr($0, 1, i - 1)
          if (pre == "" || pre == "- " || pre ~ /\. $/) found = 1
        }
        END { exit !found }
      ' "$file"; then
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
        ${requireSentences "${label} lacks the model-routing rule:" routingSentences}
        ${requireSentences "${label} lacks the cross-model delegation rule:" delegationSentences}
        ${requireSentences "${label} lacks the learning-refresh rule:" learningRefreshSentences}
        ${requireSentences "${label} lacks the branch-name rule:" branchNameSentences}
        ${requireSentences "${label} lacks the issue and pull request media rule:" mediaSentences}
        for directive in ${lib.escapeShellArgs supersededDirectives}; do
          if grep -qF -- "$directive" "$file"; then
            echo ${esc "${label} carries a superseded directive:"} "$directive" >&2
            failed=1
          fi
        done
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
