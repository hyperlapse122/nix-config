/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions reach every delivery path for
  user `h82` on every host this flake declares, each part exactly once. The
  template renders three parts: system (tool use, GPG, model routing), user
  (review findings, learning refresh, branch names, commit hooks, pull and
  merge requests, issue media), and T3 Code (the rules that only apply inside
  T3 Code). The channels, and the parts each must hold:

    Claude Code   ~/.claude/CLAUDE.md                          system + user
                  ~/.t3/instructions/claude-code/CLAUDE.md     T3 Code
    Antigravity   ~/.gemini/config/AGENTS.md                   system + user
    Codex         ~/.codex/AGENTS.md                           user
                  config.toml developer_instructions           system
                  T3 Code launch -c developer_instructions     system + T3 Code

  A terminal session reads the first row of each harness, plus Codex's
  developer_instructions. A T3 Code session also reads the Claude Code T3
  Code file, which the Claude instance's --add-dir loads, and Codex's launch
  override, which replaces developer_instructions. Antigravity under T3 Code
  has no channel yet and is not checked.

  The user list is `userEntries` from `tests/lib/configurations.nix`, plus each
  production configuration and this architecture's production fixtures
  re-evaluated with both T3 Code traits forced off. The guard fails the build
  when either side, T3 Code on or off, holds no user, or when a forced-off
  user still has a trait on, so neither side passes by covering nothing. See
  .compound-engineering/artifacts/solutions/best-practices/removing-a-host-empties-one-side-of-a-partitioned-check.md

  Verifies, per Home Manager user:
  - exactly one enabled Home Manager file resolves to each terminal target,
    and to the Claude Code T3 Code target exactly when a T3 Code trait is on.
    The lookup compares each entry's resolved `target` rather than its
    attribute name, and reads `enable`, because either can move the file
    without changing its text. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - Codex's developer_instructions is read from the declared file the
    codexSettings activation passes the merger. The launch override is read
    from the t3codeSettings declared file, split as a shell would split it and
    decoded as TOML, so a broken `'` or `"` escape fails. The Claude
    instance's launch arguments must be `--add-dir` the directory of the T3
    Code file, with the environment variable that makes Claude Code load it.
  - on each delivery path, every pinned sentence of each part the path
    carries appears exactly once, and no pinned sentence of another part
    appears, so a part dropped, doubled, or delivered to the wrong path fails.
  - in each channel, the parts it holds pass their sentence rules, and no
    channel without the T3 Code part contains the string `T3 Code`:
    - system: the opening sentence with this harness's name, the GPG rule
      with every sentence pinned, the model-routing rule with each table row
      matched whole, and every native tool its harness maps.
    - user: the review-findings, learning-refresh, branch-name, and media
      rules, and the commit-hook and pull and merge request rules with every
      sentence pinned, in order, inside their sections.
    - T3 Code: the T3 Code introduction in order, the cross-model delegation
      rules inside their section with only pinned sentences naming
      Antigravity, Argon, or OpenCode or speaking of waiting, and the T3 Code
      pull and merge request rules with every sentence pinned, in order.
  - every required sentence starts where a sentence starts, so a guarded
    sentence negated by a prefix ("Do not ...") fails.
  - no channel carries a superseded directive, another harness's native
    tool, an unrendered template action (`{{`, `}}`), or `<no value>`.

  The expected sentences and tool names are literals here, not read from the
  module, so a mutation of the template turns this red.

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

  commitHookSentences = [
    "A commit hook can copy the checkout into a temporary directory and run a mise shim there, which fails because mise has never trusted the copy's `mise.toml`."
    "When a commit hook fails because mise does not trust a `mise.toml` in a temporary directory the hook created, run that one commit again with `MISE_TRUSTED_CONFIG_PATHS` set to the resolved directory that holds the one the error names, usually `\"$(cd \"\${TMPDIR:-/tmp}\" && pwd -P)\"`."
    "Resolve that path with `pwd -P`, because mise checks the resolved path and `$TMPDIR` on macOS sits under `/var`, a link to `/private/var`."
    "When the retry fails with the same error, report the failure instead of retrying again."
    "Do not run `mise trust` on a temporary directory, which writes a trust entry for every throwaway copy, and do not skip the hook with `--no-verify`, which skips its checks."
    "When the untrusted file is the checkout's own `mise.toml`, trusting it is the user's decision; report the failure instead."
  ];

  gpgSentences = [
    "The user's GPG key is on an OpenPGP card, a YubiKey that stays connected, and its PIN is usually cached, so GPG works from your shell without the user."
    "Run GPG signing, decryption, and encryption yourself, along with work that goes through GPG, such as SOPS re-encryption and editing; do not ask the user to run these commands."
    "When a pinentry dialog appears, still run the command and let the dialog reach the user."
    "Stop and report only when the PIN is rejected, the prompt times out, or the card is missing."
    "Never print decrypted values, pass them as command arguments, or read decrypted files with the file tools; send decrypted output straight into the command that consumes it."
    "Leave card administration and key management to the user: card-edit admin commands, PIN changes, key generation, secret-key export, and trust changes."
    "When a new SOPS setup or new secret file has no existing encryption method, use the user's card key, fingerprint `621512777E6933FEB4458FDC4945855D4F283F05`, as the user's recipient instead of creating an age key."
    "When a machine or service must decrypt that file without the card, also add the machine's own recipient."
    "Keep the existing method in a project that already encrypts with age or another method."
  ];

  pullRequestSentences = [
    "GitHub and GitLab are both normal forges."
    "Treat a GitLab project as the same case as a GitHub one, and babysit every pull or merge request you open or push to until it looks ready to merge."
    "When a Compound Engineering skill that speaks only GitHub, such as `ce-commit-push-pr`, `ce-babysit-pr`, `ce-resolve-pr-feedback`, `ce-code-review` on a pull request, or `lfg`, runs in a GitLab project, carry out the same procedure with `glab` instead of stopping or skipping its forge steps."
    "Map each GitHub concept to its GitLab counterpart: a pull request is a merge request, a review thread is a resolvable discussion, and an Actions run or check is a pipeline or job."
    "Open the merge request with `glab mr create`, read discussions with `glab mr note list -F json`, reply with `glab mr note create --reply`, post a top-level note with `glab mr note create --resolvable=false` so your own note opens no discussion, resolve with `glab mr note resolve`, retry a job with `glab ci retry`, and reach anything else through `glab api`."
    "When a skill step has no GitLab counterpart, such as a `gh stack` posture, skip only that step, keep the rest of the procedure, and name the skipped step in your report."
    "After you open a pull or merge request, or push to one, start babysitting it without being asked, in interactive and autonomous runs alike."
    "Babysit a draft only when the user asked you to watch that draft; otherwise report it as a draft and arm no watch."
    "Babysit a GitHub pull request with `ce-babysit-pr` unchanged."
    "Babysit a GitLab merge request with the same ticks and a background watcher that polls every two to three minutes and exits when the head pipeline finishes, a note or discussion appears, the conflict or merge status changes, or the merge request closes or merges."
    "Never wait in a foreground sleep loop; when your harness cannot run a background command, report the open request and how to resume babysitting."
    "On GitLab, read each tick's state from `glab mr view <id> -F json` (`state`, `draft`, `sha`, `head_pipeline`, `detailed_merge_status`, `has_conflicts`, `blocking_discussions_resolved`) and from `glab mr note list <id> -F json`."
    "Call a merge request ready only when `head_pipeline.sha` equals `sha`, `head_pipeline.status` is `success`, `detailed_merge_status` is `mergeable`, no discussion is unresolved, no note or `needs-human` item is unhandled, and the settle window has passed."
    "A `glab ci status` result or an empty pipeline list is not evidence that a merge request is ready."
    "On GitLab, the settle window is 300 seconds with no new push, note, or discussion, the default `ce-babysit-pr` uses, unless the project sets another."
    "When no pipeline runs for `sha` once the settle window has passed, report the missing CI evidence as a blocker for the user instead of calling the merge request ready."
    "When only an approval stands between the merge request and `mergeable`, such as `detailed_merge_status` `not_approved`, wait one more settle window for review activity, then report the wait for that approval as a blocker for the user."
    "On GitLab, never rebase: report a branch that is behind or conflicts with its target as a blocker for the user."
    "When babysitting reaches looks-ready, a blocker, or its budget, stop your background waits before you hand back, and leave the merge to the user."
    "Using `glab` instead of `gh` is not a decision you made on the user's behalf; leave it out of the report, and mention the forge only for a skipped step or a blocker."
  ];

  t3IntroSentences = [
    "This session runs inside T3 Code."
    "These rules add to the Tool use, Model routing, and Pull and merge requests sections of your other instructions, and where they differ, these rules take precedence."
    "Route to another provider only through T3 Code, as Cross-model delegation describes."
    "A broad scout runs on Flash low through T3 Code; when Antigravity is not runnable through T3 Code, it keeps the short scout's class from the table."
    "When your native subagent tool cannot select the table's class, delegate through T3 Code as Cross-model delegation describes instead of letting the subagent inherit your session model."
  ];

  t3PullRequestSentences = [
    "These rules replace the waits in Pull and merge requests while T3 Code can watch the request."
    "When the T3 Code pull request tools are available, call `link_pull_request` and run one babysit tick; unless that tick reached looks-ready or a blocker, call `watch_pull_request` and end your turn."
    "On each T3 Code wake, stop the background waits you started, then run one babysit tick in the skill's order: review feedback first, then CI on the current head, then branch currency."
    "When a tick finds the request ready except for the skill's settle window or its bounded wait for a review still coming, keep the watch and start a background wait for that window, then run another tick when it ends."
    "While T3 Code watches, also start one background wait of 30 minutes after each tick that runs a tick when no wake has arrived, so a watch that stopped reading the request does not strand it."
    "The T3 Code pull request tools are available when the session lists `link_pull_request`, `watch_pull_request`, and `unwatch_pull_request` by name, even when the harness must load their schemas before the first call."
    "Inside T3 Code, `ce-babysit-pr` still runs every tick, but where it would arm `pr-snapshot watch` or wait between pipeline ticks, call `watch_pull_request` and end your turn instead."
    "This holds when you babysit a request directly, through `ce-commit-push-pr`'s babysit handoff, and in `lfg` step 10."
    "On every wake, whether T3 Code, the bridge watcher, or a background wait started it, run the next tick under the invocation the first tick started, presenting its recorded `RUN_INVOCATION_ID`, `RUN_STARTED_AT`, and `RUN_BUDGET_SECONDS`, and never pass `--start-invocation` again."
    "When those values are no longer in your context, read them back from the request's `state.json` in `ce-babysit-pr`'s state directory, and at a stack layer transition also pass `--continue-invocation` as the skill directs."
    "Under T3 Code, `lfg` runs a `ce-babysit-pr mode:pipeline` tick on each wake until one reaches its CI-decided stop, and prints its close-out and `<promise>DONE</promise>` in that turn."
    "In that close-out, say that T3 Code watches the request instead of pointing the user to run `ce-babysit-pr`."
    "When that tick also reached looks-ready, a blocker, or the budget, unwatch as the stop rule in this section says; otherwise keep the watch and end the turn, and later wakes keep babysitting under the same invocation until looks-ready, a blocker, or the budget, with every delegate still in `mode:pipeline`."
    "A failed call to `link_pull_request` or `watch_pull_request`, such as `The calling provider no longer owns an active thread run`, does not make T3 Code unavailable: when `link_pull_request` failed, still call `watch_pull_request` in that turn, and while the watch has not succeeded, arm a bridge watcher in place of the 30-minute wait and retry each failed call at the next tick."
    "The bridge watcher is `ce-babysit-pr`'s own watcher on GitHub and the GitLab background watcher from Pull and merge requests on GitLab, and you stop it after at most 30 minutes, so a retry tick runs even when the request has not changed."
    "Once `watch_pull_request` succeeds, stop the bridge watcher and start the 30-minute wait."
    "When `unwatch_pull_request` fails at a babysitting stop, arm no bridge and schedule no tick, and say in your final report that T3 Code still watches the request."
    "Inside T3 Code, this section overrides these skill rules:"
    "`ce-babysit-pr`'s default `pr-snapshot watch` sustain mode, except for the bridge watcher above;"
    "`ce-babysit-pr`'s pipeline-mode wait between ticks, and its rule never to wait on the settle window or human review;"
    "`ce-commit-push-pr`'s rule against arming a watcher outside `ce-babysit-pr`, which does not cover `watch_pull_request` or the waits this section starts;"
    "`lfg`'s stop once CI is decided, its close-out line that points the user to `ce-babysit-pr`, and its rule not to end the turn before `<promise>DONE</promise>`."
    "A T3 Code wake is not evidence that a merge request is ready."
    "When a harness cannot run a background command, rely on T3 Code's wakes alone, and when a tick then finds only a wait outstanding, call `unwatch_pull_request` and report the open request and how to resume babysitting."
    "When babysitting reaches looks-ready, a blocker, or its budget, call `unwatch_pull_request` before you hand back."
    "Using T3 Code's watch instead of the skill's watcher is not a decision you made on the user's behalf; leave it out of the report."
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
    "Never choose Gemini 3.1 Pro (`gemini-pro-agent`, `gemini-3.1-pro-low`), any Codex Terra model, or any Claude Fable model yourself; use one only when the user, the project, or its CE config names it."
    "Run a delegated or subagent task at the chosen model's default effort unless the table, the skill, its config, the project, or the user names one."
    "Apply the same-provider cells in every session; a subagent you start yourself runs on your own provider."
    "When your native subagent tool cannot select the table's class, let the subagent inherit your session model and say so in one line."
    # Role table rows, each matched whole so a changed cell fails.
    "| Short scout | Haiku | Luna | Flash low |"
    "| Broad scout | Haiku | Luna | Flash low |"
    "| Worker | Sonnet | Luna | Flash medium |"
  ];

  # How a T3 Code delegation returns and how to wait for it: async by
  # default, a completion notification instead of a blocking call, one
  # status read per task, and no polling or self-wake.
  asyncDelegationSentences = [
    "`delegate_task` does not block in its default `async` mode: it returns a `taskId` at once, and when the child finishes, T3 Code sends this thread a notification, steered into your current turn where the harness supports that or queued to start your next turn otherwise."
    "The notification only reports that the task finished; read the task's result with one `task_status` call, which returns at once and never waits."
    "Launch with `mode: \"wait\"` only when your next step needs the child's result and no other work could run meanwhile; it blocks until the child finishes or `timeoutMs` passes, and on a `waitTimedOut` result the child keeps running and still sends its notification, so end your turn and wait for it."
    "After an `async` launch, do the work that does not need the result; when a step needs results whose notifications have not all arrived, end your turn, and resume that step once every task it waits on has notified."
    "Never call `task_status` in a loop, and never start a sleep, timer, or background command to wake yourself for a delegated task."
    "Read a task's `task_status` once after its notification arrives, and otherwise at most once per task in a turn that started without any delegation notification, so a task that failed or shows no progress reaches the retry rule in this section."
    "Only the agent that owns the T3 Code thread ends its turn to wait; a subagent that delegates through T3 Code returns its task IDs to its caller, at once after an `async` launch or when a `mode: \"wait\"` launch returns `waitTimedOut`."
    "Ending your turn to wait for a delegated task's notification is allowed even where a skill says not to end the turn yet, such as `lfg`'s rule not to end the turn before `<promise>DONE</promise>`; when the notification arrives, continue the same run from the step that waited."
  ];

  # Every sentence of the delegation section that may speak about status
  # reads, waiting, or self-wake. Any other such sentence there, such as an
  # added "keep polling `task_status`" or "wait five minutes and check
  # whether the child finished", fails.
  waitTopicSentences = [
    "The tools are `orchestrator_capabilities`, `delegate_task`, `task_status`, and `task_cancel`."
  ]
  ++ asyncDelegationSentences;

  delegationSentences = [
    "This section applies only when the T3 Code MCP tools are available in this session and the work needs a provider other than your own or a model your native subagent tool cannot serve; otherwise, keep using the native subagent tool."
    "When a skill has decided to run cross-model work and tells you to discover, attest, or launch another harness, delegate that run through T3 Code instead of the skill's own launch route; the skill's gates, such as `cross_model_review_mode`, decide first whether the run happens."
    "Once you know which model class suits the task (Sol, Luna, or Astra for Codex; Opus, Sonnet, or Haiku for Claude; Argon, at the Opus tier, or Flash, between Sonnet and Haiku, for Gemini), choose the latest version of that class that `orchestrator_capabilities` lists as runnable."
    "Compare versions only within that class: a newer model of another class does not outrank the class the task needs."
    "Choose an older version only when the latest is unavailable, has failed in this session, or the user or project asked for that version, and say why when you name the model."
    "When a skill's cross-model pass runs through T3 Code, take its model and effort from `cross_model_model` and `cross_model_effort` when they are set, otherwise from the skill's own mapping; the latest-version rule does not replace a model the skill names."
    "When a skill's cross-model pass runs through T3 Code, also delegate that pass to Antigravity on the latest runnable Argon at medium effort (today `gemini-4-argon-medium` on provider instance `antigravity`), even though the skill's mapping has no Gemini entry."
    "The Antigravity peer belongs to the pass the skill already runs, not a pass of its own, so it runs only when the skill's own peer runs."
    "It mirrors every job the skill's peer runs, with the same brief, scope, and output shape, and its findings fold in beside that peer's with `antigravity` as the provider name."
    "It obeys the skill's recipient restrictions, such as `CROSS_MODEL_PEERS` or a user's refusal of a provider, and is announced before dispatch as a further recipient that receives the reviewed content."
    "When a gate or restriction excludes it, or Antigravity is not runnable, skip it and say why in one line."
    # Literal, not read from home/h82/agents/opencode-model.nix, so the
    # rendered model id is checked against an independent value.
    "When a skill's cross-model pass runs through T3 Code, also delegate that pass to OpenCode on `opencode/glm-5.3-flash-free` on provider instance `opencode`, even though the skill's mapping has no OpenCode entry."
    "The OpenCode peer belongs to the pass the skill already runs, not a pass of its own, so it runs only when the skill's own peer runs."
    "It mirrors every job the skill's peer runs, with the same brief, scope, and output shape, and its findings fold in beside that peer's with `opencode` as the provider name."
    "It obeys the same recipient restrictions and is announced before dispatch as a further recipient that receives the reviewed content, adding that the content goes to OpenCode Zen's free tier under the data terms at `https://opencode.ai/docs/zen/#privacy`."
    "When a gate or restriction excludes it, or OpenCode is not runnable, skip it and say why in one line."
    "Run every delegated task in full-access runtime mode."
  ]
  ++ asyncDelegationSentences
  ++ [
    "When a skill's review procedure turns on its cross-model pass, delegate that pass asynchronously in the same step that dispatches the skill's in-process reviewers, and merge its result when it returns; never add a cross-model pass the skill would not run."
    "When a delegated task fails, reports a provider error, or shows no progress, cancel it with `task_cancel` and retry the same task on another runnable T3 Code provider."
    "A retried cross-model pass uses the skill's mapping for that provider when the skill has one, and the latest Argon at medium effort on Antigravity, which the skills do not map."
    "Never retry a cross-model pass on a provider that already runs a peer of the same pass, so a failed Antigravity or OpenCode peer is not retried elsewhere and a failed skill peer does not land beside a running Argon or OpenCode peer."
    "Fall back to the skill's own cross-model method only when no T3 Code provider succeeds, and tell the user that you did."
    "Verify a delegated result against the repository or other primary evidence before you rely on it or report it as fact."
  ];

  supersededDirectives = [
    "before any of the skill's own discovery or launch steps"
    "for the task instead of inheriting its defaults"
    "Apply every finding that `ce-code-review` and `ce-simplify-code` report"
    "Flash for Gemini)"
    "the latest Flash at high effort on Antigravity"
    "Argon at high effort"
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

  # Fails the build, naming each sentence, when `$file` lacks any of them.
  # A sentence counts only where one begins: at the start of a line, after a
  # list marker (nested or not), or after the previous sentence's full stop. A substring match
  # would accept the sentence inside its own negation ("Do not Apply every...").
  requireSentences = message: sentences: ''
    for sentence in ${lib.escapeShellArgs sentences}; do
      if ! awk -v s="$sentence" '
        {
          i = index($0, s)
          if (i == 0) next
          pre = substr($0, 1, i - 1)
          if (pre == "" || pre ~ /^ *- $/ || pre ~ /\. $/) found = 1
        }
        END { exit !found }
      ' "$file"; then
        echo ${esc message} "$sentence" >&2
        failed=1
      fi
    done
  '';

  # The pinned delegation sentences that name an extra peer: Antigravity,
  # Argon, or OpenCode. Any other sentence in that section naming them, such
  # as an added reversal kept beside the pinned rule, fails.
  peerPattern = "Antigravity|Argon|OpenCode|opencode";
  antigravitySentences = lib.filter (
    sentence: builtins.match ".*(${peerPattern}).*" sentence != null
  ) delegationSentences;

  # Prints the section under `heading` one sentence per line, list markers
  # (nested ones included) dropped, splitting after each full stop.
  sectionSentences = heading: ''
    awk -v h=${esc heading} '
      $0 == h { inside = 1; next }
      /^# / { inside = 0 }
      inside { sub(/^ *- /, ""); gsub(/\. /, ".\n"); print }
    ' "$file"'';

  # Fails the build, naming each sentence, when the section under `heading`
  # carries a sentence matching `pattern` that is not one of `sentences`.
  onlyPinnedSentences = message: heading: pattern: sentences: ''
    if ! grep -qxF -- ${esc heading} "$file"; then
      echo ${esc "${message} section missing:"} ${esc heading} >&2
      failed=1
    fi
    allowed=$(mktemp)
    printf '%s\n' ${lib.escapeShellArgs sentences} > "$allowed"
    while IFS= read -r sentence; do
      if ! grep -qxF -- "$sentence" "$allowed"; then
        echo ${esc message} "$sentence" >&2
        failed=1
      fi
    done < <(
      ${sectionSentences heading} | grep -E -- ${esc pattern} || true
    )
  '';

  # Fails the build, naming each sentence, when the section under `heading`
  # lacks it. `requireSentences` reads the whole file, so a pinned sentence
  # moved into another section would still pass it.
  sentencesInSection = message: heading: sentences: ''
    present=$(mktemp)
    ${sectionSentences heading} > "$present"
    for sentence in ${lib.escapeShellArgs sentences}; do
      if ! grep -qxF -- "$sentence" "$present"; then
        echo ${esc message} "$sentence" >&2
        failed=1
      fi
    done
  '';

  # Fails the build when the section under `heading`, read top to bottom, is
  # not exactly `sentences` in that order. Membership checks pass a
  # duplicated sentence, or one moved away from the sentence it leans on,
  # such as "This holds when ...".
  sentencesInOrder = message: heading: sentences: ''
    expected=$(mktemp)
    actual=$(mktemp)
    printf '%s\n' ${lib.escapeShellArgs sentences} > "$expected"
    ${sectionSentences heading} | grep -E -- . > "$actual" || true
    if ! cmp -s "$expected" "$actual"; then
      echo ${esc message} >&2
      diff "$expected" "$actual" >&2 || true
      failed=1
    fi
  '';

  harnesses = {
    claude-code = {
      name = "Claude Code";
      sharedSentence = "Use the tools Claude Code provides natively before reaching for a shell equivalent.";
      present = claudeTools;
      absent = antigravityTools ++ codexTools;
    };
    antigravity = {
      name = "Antigravity";
      sharedSentence = "Use the tools Antigravity provides natively before reaching for a shell equivalent.";
      present = antigravityTools;
      absent = claudeTools ++ codexTools;
    };
    codex = {
      name = "Codex";
      sharedSentence = "Use the tools Codex provides natively before reaching for a shell equivalent.";
      present = codexTools;
      absent = claudeTools ++ antigravityTools;
    };
  };

  # Each part's pinned sentences, for the exactly-once and wrong-path counts.
  partSentences = harness: {
    system = [ harness.sharedSentence ] ++ gpgSentences ++ routingSentences;
    user =
      reviewFindingsSentences
      ++ learningRefreshSentences
      ++ branchNameSentences
      ++ commitHookSentences
      ++ pullRequestSentences
      ++ mediaSentences;
    t3code = t3IntroSentences ++ delegationSentences ++ t3PullRequestSentences;
  };

  partNames = [
    "system"
    "user"
    "t3code"
  ];

  # Fails the build, naming each sentence, when `$file` does not hold it
  # exactly `count` times.
  countSentences = message: count: sentences: ''
    for sentence in ${lib.escapeShellArgs sentences}; do
      # grep -c counts lines, not matches, and grep exits 1 on no match,
      # which pipefail would turn into a failed assignment.
      n=$( (grep -oF -- "$sentence" "$file" || true) | wc -l)
      n=$((n))
      if [ "$n" != ${toString count} ]; then
        echo ${esc message} "($n times):" "$sentence" >&2
        failed=1
      fi
    done
  '';

  systemRules = label: harness: ''
    if ! grep -qF -- ${esc harness.sharedSentence} "$file"; then
      echo ${esc "${label} lacks the system part's opening sentence"} >&2
      failed=1
    fi
    ${requireSentences "${label} lacks the GPG rule:" gpgSentences}
    ${onlyPinnedSentences "${label} carries an unpinned GPG sentence:" "# GPG and encryption" "."
      gpgSentences
    }
    ${requireSentences "${label} lacks the model-routing rule:" routingSentences}
    for tool in ${lib.escapeShellArgs harness.present}; do
      if ! grep -qF -- "$tool" "$file"; then
        echo ${esc "${label} does not name"} "$tool" >&2
        failed=1
      fi
    done
  '';

  userRules = label: ''
    ${requireSentences "${label} lacks the review-findings rule:" reviewFindingsSentences}
    ${requireSentences "${label} lacks the learning-refresh rule:" learningRefreshSentences}
    ${requireSentences "${label} lacks the branch-name rule:" branchNameSentences}
    ${requireSentences "${label} lacks the commit-hook rule:" commitHookSentences}
    ${onlyPinnedSentences "${label} carries an unpinned commit-hook sentence:" "# Commit hooks" "."
      commitHookSentences
    }
    ${sentencesInSection "${label} moves a commit-hook sentence out of its section:" "# Commit hooks"
      commitHookSentences
    }
    ${sentencesInOrder "${label} reorders or duplicates a commit-hook sentence:" "# Commit hooks"
      commitHookSentences
    }
    ${requireSentences "${label} lacks the pull and merge request rule:" pullRequestSentences}
    ${onlyPinnedSentences "${label} carries an unpinned pull and merge request sentence:"
      "# Pull and merge requests"
      "."
      pullRequestSentences
    }
    ${sentencesInSection "${label} moves a pull and merge request sentence out of its section:"
      "# Pull and merge requests"
      pullRequestSentences
    }
    ${sentencesInOrder "${label} reorders or duplicates a pull and merge request sentence:"
      "# Pull and merge requests"
      pullRequestSentences
    }
    ${requireSentences "${label} lacks the issue and pull request media rule:" mediaSentences}
  '';

  t3codeRules = label: ''
    ${requireSentences "${label} lacks the T3 Code introduction:" t3IntroSentences}
    ${sentencesInOrder "${label} reorders, duplicates, or adds to the T3 Code introduction:" "# T3 Code"
      t3IntroSentences
    }
    ${requireSentences "${label} lacks the cross-model delegation rule:" delegationSentences}
    ${onlyPinnedSentences "${label} carries an unpinned extra-peer sentence:" "# Cross-model delegation"
      peerPattern
      antigravitySentences
    }
    ${onlyPinnedSentences "${label} carries an unpinned delegation wait sentence:"
      "# Cross-model delegation"
      "task_status|[Pp]oll|[Nn]otif|[Ww]ait|[Ww]ake|[Bb]lock|[Ss]leep|[Tt]imer|[Cc]heck|[Ff]inish|[Bb]ackground|[Ss]chedul"
      waitTopicSentences
    }
    ${sentencesInSection "${label} moves a cross-model delegation sentence out of its section:"
      "# Cross-model delegation"
      delegationSentences
    }
    ${requireSentences "${label} lacks the T3 Code pull and merge request rule:" t3PullRequestSentences}
    ${onlyPinnedSentences "${label} carries an unpinned T3 Code pull and merge request sentence:"
      "# Pull and merge requests in T3 Code"
      "."
      t3PullRequestSentences
    }
    ${sentencesInOrder "${label} reorders or duplicates a T3 Code pull and merge request sentence:"
      "# Pull and merge requests in T3 Code"
      t3PullRequestSentences
    }
  '';

  # Checks the channel file at `$file`, which must hold exactly `parts`.
  channelRules =
    label: harness: parts:
    let
      sentences = partSentences harness;
      foreign = lib.concatMap (part: sentences.${part}) (lib.subtractLists parts partNames);
    in
    # The same rendered file recurs across hosts; a repeat of a file already
    # checked for the same harness and parts is skipped, since it can only
    # repeat the first check's result.
    ''
      key="$(sha256sum < "$file" 2>/dev/null | cut -d' ' -f1) ${esc "${harness.name} ${toString parts}"}"
      if [ -s "$file" ] && grep -qxF -- "$key" "$seen"; then
        :
      else
      echo "$key" >> "$seen"
      if [ ! -s "$file" ]; then
        echo ${esc "${label} is missing or empty"} >&2
        failed=1
      fi
      ${lib.optionalString (lib.elem "system" parts) (systemRules label harness)}
      ${lib.optionalString (lib.elem "user" parts) (userRules label)}
      ${lib.optionalString (lib.elem "t3code" parts) (t3codeRules label)}
      ${countSentences "${label} carries a sentence of a part it must not hold" 0 foreign}
      ${lib.optionalString (!lib.elem "t3code" parts) ''
        if grep -qF 'T3 Code' "$file"; then
          echo ${esc "${label} mentions T3 Code, which only the T3 Code part may"} >&2
          failed=1
        fi
      ''}
      for directive in ${lib.escapeShellArgs supersededDirectives}; do
        if grep -qF -- "$directive" "$file"; then
          echo ${esc "${label} carries a superseded directive:"} "$directive" >&2
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
      fi
    '';

  # Checks one delivery path: the channels it reads, concatenated, must hold
  # each of `parts` exactly once and no other part.
  pathRules =
    label: harness: channels: parts:
    let
      sentences = partSentences harness;
      foreign = lib.concatMap (part: sentences.${part}) (lib.subtractLists parts partNames);
    in
    ''
      file=$(mktemp)
      for channel in ${lib.concatStringsSep " " channels}; do
        if [ -f "$channel" ]; then
          cat "$channel" >> "$file"
        fi
      done
      ${countSentences "${label} does not carry this sentence exactly once" 1 (
        lib.concatMap (part: sentences.${part}) parts
      )}
      ${countSentences "${label} carries a sentence of a part it must not reach" 0 foreign}
      rm -f "$file"
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

  # Prints the store file an activation entry passes the merger as --declared.
  declaredOf = script: ''
    printf '%s\n' ${esc script} \
      | tr '\n' ' ' | grep -oE -- '--declared[[:space:]]+/nix/store/[^[:space:]]+' \
      | head -1 | awk '{print $2}' || true
  '';

  channels = ./agent-instruction-channels.py;

  claudeT3Target = ".t3/instructions/claude-code/CLAUDE.md";

  t3On =
    userConfig: (userConfig.my.t3.cli.enable or false) || (userConfig.my.t3.desktop.enable or false);

  assertEntry =
    entry:
    let
      label = entry.name;
      user = entry.user;
      t3 = t3On user;
      home = user.home.homeDirectory or "";
      codexScript = user.home.activation.codexSettings.data or "";
      t3Activation = user.home.activation.t3codeSettings or null;
      on = lib.optionalString t3;
    in
    ''
      d=$(mktemp -d)

      ${homeFile label user ".claude/CLAUDE.md" 1 "$d/claude"}
      ${homeFile label user ".gemini/config/AGENTS.md" 1 "$d/antigravity"}
      ${homeFile label user ".codex/AGENTS.md" 1 "$d/codex-agents"}
      ${homeFile label user claudeT3Target (if t3 then 1 else 0) "$d/claude-t3"}

      declared=$(${declaredOf codexScript})
      if [ -z "$declared" ] || ! python3 ${channels} developer "$declared" "$d/codex-dev"; then
        echo ${esc "the Codex developer_instructions on ${label} cannot be read from the codexSettings declaration"} >&2
        failed=1
      fi

      ${
        if t3 then
          ''
            declared=$(${declaredOf (t3Activation.data or "")})
            if [ -z "$declared" ] || ! python3 ${channels} codex-launch "$declared" "$d/codex-launch"; then
              echo ${esc "the Codex launch override on ${label} cannot be read from the t3codeSettings declaration"} >&2
              failed=1
            fi
            dir=$(python3 ${channels} claude-dir "$declared" || true)
            if [ "$dir" != ${esc "${home}/.t3/instructions/claude-code"} ]; then
              echo ${esc "the Claude instance on ${label} must --add-dir the directory of ~/${claudeT3Target}, got"} "'$dir'" >&2
              failed=1
            fi
          ''
        else
          lib.optionalString (t3Activation != null) ''
            echo ${esc "${label} has both T3 Code traits off but declares the t3codeSettings merge"} >&2
            failed=1
          ''
      }

      file=$d/claude
      ${channelRules "~/.claude/CLAUDE.md on ${label}" harnesses.claude-code [
        "system"
        "user"
      ]}
      file=$d/antigravity
      ${channelRules "~/.gemini/config/AGENTS.md on ${label}" harnesses.antigravity [
        "system"
        "user"
      ]}
      file=$d/codex-agents
      ${channelRules "~/.codex/AGENTS.md on ${label}" harnesses.codex [ "user" ]}
      file=$d/codex-dev
      ${channelRules "Codex developer_instructions on ${label}" harnesses.codex [ "system" ]}
      ${on ''
        file=$d/claude-t3
        ${channelRules "~/${claudeT3Target} on ${label}" harnesses.claude-code [ "t3code" ]}
        file=$d/codex-launch
        ${channelRules "the T3 Code Codex launch override on ${label}" harnesses.codex [
          "system"
          "t3code"
        ]}
      ''}

      ${pathRules "the Claude Code terminal path on ${label}" harnesses.claude-code
        [ "$d/claude" ]
        [ "system" "user" ]
      }
      ${pathRules "the Antigravity terminal path on ${label}" harnesses.antigravity
        [ "$d/antigravity" ]
        [ "system" "user" ]
      }
      ${pathRules "the Codex terminal path on ${label}" harnesses.codex
        [ "$d/codex-agents" "$d/codex-dev" ]
        [ "system" "user" ]
      }
      ${on ''
        ${pathRules "the Claude Code T3 Code path on ${label}" harnesses.claude-code [
          "$d/claude"
          "$d/claude-t3"
        ] partNames}
        ${pathRules "the Codex T3 Code path on ${label}" harnesses.codex [
          "$d/codex-agents"
          "$d/codex-launch"
        ] partNames}
      ''}

      rm -rf "$d"
    '';

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

  # No delivery path carries the Antigravity T3 Code part yet, so no host
  # renders it. Rendered here, so the template's Antigravity branches in that
  # part keep producing the part minus the rules about Antigravity peers.
  antigravityT3 = (import ../home/h82/agents/instructions/render.nix { inherit pkgs lib; }).render {
    harness = "antigravity";
    parts = [ "t3code" ];
  };
  # The broad-scout rule and the Antigravity-peer bullet, the two places the
  # template leaves out for Antigravity. The OpenCode-peer bullet shares its
  # openings but stays, so its sentences are kept out of this list.
  antigravityT3Omitted = [
    "A broad scout runs on Flash low through T3 Code; when Antigravity is not runnable through T3 Code, it keeps the short scout's class from the table."
  ]
  ++ lib.filter (
    sentence:
    !(lib.hasInfix "OpenCode" sentence || lib.hasInfix "`opencode`" sentence)
    && lib.any (prefix: lib.hasPrefix prefix sentence) [
      "When a skill's cross-model pass runs through T3 Code, also delegate"
      "The Antigravity peer belongs"
      "It mirrors every job"
      "It obeys the skill's recipient restrictions"
      "When a gate or restriction excludes it"
    ]
  ) delegationSentences;
  antigravityT3Rules =
    assert lib.assertMsg (lib.length antigravityT3Omitted == 6)
      "tests/agent-instructions.nix: antigravityT3Omitted no longer names the six sentences the Antigravity branches leave out";
    ''
      file=${antigravityT3}
      ${countSentences "the Antigravity T3 Code part does not carry this sentence exactly once" 1 (
        lib.subtractLists antigravityT3Omitted (
          t3IntroSentences ++ delegationSentences ++ t3PullRequestSentences
        )
      )}
      ${countSentences "the Antigravity T3 Code part carries a rule about Antigravity peers" 0
        antigravityT3Omitted
      }
      for tool in ${lib.escapeShellArgs harnesses.antigravity.absent}; do
        if grep -qF -- "$tool" "$file"; then
          echo "the Antigravity T3 Code part names another harness's tool $tool" >&2
          failed=1
        fi
      done
      if grep -qE '\{\{|\}\}|<no value>' "$file"; then
        echo 'the Antigravity T3 Code part carries an unrendered template action' >&2
        failed=1
      fi
    '';

  forceT3Off = {
    my.t3.cli.enable = lib.mkForce false;
    my.t3.desktop.enable = lib.mkForce false;
  };

  mkLinuxHost = import ../lib/linux-host.nix { inherit (self) inputs; };

  # Every configuration today enables a T3 Code trait, so the T3-off side
  # comes from production configurations re-evaluated with both forced off.
  # One configuration of each kind is enough: forcing the traits off
  # removes the same files on every host of that kind.
  forcedOff =
    map (entry: {
      name = "${entry.name} with both T3 Code traits forced off";
      forced = true;
      user =
        (self.nixosConfigurations.${entry.name}.extendModules { modules = [ forceT3Off ]; })
        .config.home-manager.users.h82 or { };
    }) (lib.take 1 configurations.production)
    ++ map (entry: {
      name = "${entry.name} with both T3 Code traits forced off";
      forced = true;
      user =
        (mkLinuxHost {
          hostName = entry.fixture;
          dir = ./fixtures/hosts + "/${entry.fixture}";
          inherit (entry) bootstrap;
          extraModules.home = [
            ./lib/fake-secrets-module.nix
            forceT3Off
          ];
        }).home.config;
    }) (lib.take 1 (lib.filter (entry: !entry.bootstrap) configurations.linuxFixtures));

  users =
    map (entry: {
      inherit (entry) name user;
      forced = false;
    }) configurations.userEntries
    ++ forcedOff;

  sidesGuard = lib.concatStrings [
    (lib.optionalString (!lib.any (entry: t3On entry.user) users) ''
      echo 'tests/agent-instructions.nix: no user enables a T3 Code trait, so the T3 Code paths are never checked' >&2
      exit 1
    '')
    (lib.optionalString (lib.all (entry: t3On entry.user) users) ''
      echo 'tests/agent-instructions.nix: every user enables a T3 Code trait, so no terminal-only user is checked' >&2
      exit 1
    '')
    (lib.concatMapStrings (
      entry:
      lib.optionalString (entry.forced && t3On entry.user) ''
        echo ${esc "tests/agent-instructions.nix: ${entry.name} still enables a T3 Code trait"} >&2
        exit 1
      ''
    ) forcedOff)
  ];
in
pkgs.runCommand "agent-instructions-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  ${configurations.userGuard}
  ${sidesGuard}
  failed=0
  seen=$(mktemp)

  ${lib.concatMapStringsSep "\n" assertEntry users}
  ${antigravityT3Rules}

  if [ "$failed" != "0" ]; then
    exit 1
  fi

  touch $out
''
