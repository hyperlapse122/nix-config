/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions reach every delivery path for
  user `h82` on every host this flake declares, each part exactly once. The
  template renders three parts: system (tool use, GPG, the cross-model peer),
  user (review findings, learning refresh, branch names, commit hooks, pull
  and merge requests, issue media), and T3 Code (the rules that only apply
  inside T3 Code). The channels, and the parts each must hold:

    Claude Code   ~/.claude/CLAUDE.md                          system + user
                  ~/.t3/instructions/claude-code/CLAUDE.md     T3 Code
    OpenCode      the file the wrapper's instructions config   system + user
                  names, which only a standalone run loads

  A terminal session reads the first row of each harness. A T3 Code session
  also reads the Claude Code T3 Code file, which the Claude instance's
  --add-dir loads. The OpenCode file is read from the installed wrapper itself:
  its INSTRUCTIONS_CONFIG constant, then the one file that config lists.
  Neither Codex's ~/.codex/AGENTS.md nor Antigravity's
  ~/.gemini/config/AGENTS.md may come back.

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
  - the Claude instance's launch arguments, read from the t3codeSettings
    declared file, must be `--add-dir` the directory of the T3 Code file,
    with the environment variable that makes Claude Code load it.
  - on each delivery path, every pinned sentence of each part the path
    carries appears exactly once, and no pinned sentence of another part
    appears, so a part dropped, doubled, or delivered to the wrong path fails.
  - in each channel, the parts it holds pass their sentence rules, and no
    channel without the T3 Code part contains the string `T3 Code`:
    - system: the opening sentence with this harness's name, the tool-use
      and GPG rules with every sentence pinned, every native tool its harness
      maps, and, for Claude Code only, the cross-model peer rule as the whole
      of its section. OpenCode's channel must not carry that rule, so a
      standalone OpenCode session never names itself as its own peer.
    - user: the review-findings, learning-refresh, branch-name, and media
      rules, and the commit-hook and pull and merge request rules with every
      sentence pinned, in order, inside their sections.
    - T3 Code: the T3 Code introduction in order, including the rule that
      every subagent job goes through T3 Code, and the delegation and T3 Code
      pull and merge request rules with every sentence pinned, in order,
      inside their sections, so a second cross-model peer, a retry onto
      another provider, or a new wait rule fails.
  - every required sentence starts where a sentence starts, so a guarded
    sentence negated by a prefix ("Do not ...") fails.
  - no channel names a removed harness, model, or rule (Antigravity, Gemini,
    Argon, Codex, OpenCode Zen, Model routing, the recipient disclosure),
    another harness's native tool, an unrendered template action (`{{`,
    `}}`), or `<no value>`.

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
    "In an autonomous run, such as `lfg`, apply the recommended fix and list the decision in the final report, but stop and ask with the question tool when the fix would reverse a decision the user made, such as a `session-settled` entry in the plan."
  ];

  learningRefreshSentences = [
    "Before each push, check whether the commits it would send break a learning, and refresh that learning on the branch before you push."
    "Check the commits the remote branch does not have yet, or, before the first push, the commits since the branch left the default branch."
    "Leave a learning that already carries `status: stale` alone, so a learning a refresh marked stale is not refreshed again."
    "Run `ce-compound-refresh` once for each learning that cites a collected item, with that learning's filename as the scope hint: in interactive mode in an interactive session, and with `mode:non-interactive`, which marks an ambiguous learning stale instead of asking, in an autonomous run such as `lfg`."
    "Commit each refresh as its own commit on the current branch, separate from the change that caused it."
    "Let `ce-compound-refresh` push nothing; push once, after every refresh run has finished, so the push carries the change and every refresh commit."
  ];

  branchNameSentences = [
    "Before the first push of a branch, check whether its name describes the change, and rename it locally with `git branch -m` when it does not."
    "A tool-generated placeholder, such as a worktree codename like `hyperlapse122/mooneye` or `worktree-memoized-juggling-hartmanis`, or a random-hex branch like `t3code/1a2b3c4d`, does not describe a change."
    "Rename only a branch that has never been pushed: no remote branch of the same name exists and no pull request uses it."
    "When the project documents no rule, name the branch `type/short-kebab-slug`: a Conventional Commits type such as `feat`, `fix`, `docs`, `refactor`, or `chore`, then a few lowercase hyphenated words that describe the change, for example `feat/add-branch-naming-rule`."
  ];

  commitHookSentences = [
    "A commit hook can copy the checkout into a temporary directory and run a mise shim there, which fails because mise has never trusted the copy's `mise.toml`."
    "When a commit hook fails because mise does not trust a `mise.toml` in a temporary directory the hook created, run that one commit again with `MISE_TRUSTED_CONFIG_PATHS` set to the resolved directory that holds the one the error names, usually `\"$(cd \"\${TMPDIR:-/tmp}\" && pwd -P)\"`."
    "Resolve that path with `pwd -P`, because mise checks the resolved path and `$TMPDIR` on macOS sits under `/var`, a link to `/private/var`."
    "When the retry fails with the same error, report the failure instead of retrying again."
    "Do not run `mise trust` on a temporary directory, which writes a trust entry for every throwaway copy, and do not skip the hook with `--no-verify`, which skips its checks."
    "When the untrusted file is the checkout's own `mise.toml`, trusting it is the user's decision; report the failure instead."
  ];

  toolUseSentences = [
    "Ask with the question tool when the user's answer changes what you do next, rather than ending your turn on an open question."
    "Hand independent work that can run in parallel to the subagent tool, on the model tier the invoked skill names for it."
    "Keep the shell for work no native tool covers: builds, tests, formatters, `git`, package managers, and searches of the tree."
    "When a native tool fails or cannot express an operation, say so and use the shell for that one operation only, then go back to the native tool."
  ];

  gpgSentences = [
    "The user's GPG key is on an OpenPGP card, a YubiKey that stays connected, and its PIN is usually cached, so GPG works from your shell without the user."
    "Run GPG signing, decryption, and encryption yourself, along with work that goes through GPG, such as SOPS re-encryption and editing; do not ask the user to run these commands."
    "When a pinentry dialog appears, still run the command and let the dialog reach the user."
    "Stop and report only when the PIN is rejected, the prompt times out, or the card is missing."
    "Never print decrypted values, pass them as command arguments, or read decrypted files with the file tools; send decrypted output straight into the command that consumes it."
    "Leave card administration and key management to the user: card-edit admin commands, PIN changes, key generation, secret-key export, and trust changes."
    "When a new SOPS setup or new secret file has no existing encryption method, use the user's card key, fingerprint `621512777E6933FEB4458FDC4945855D4F283F05`, as the user's recipient instead of creating an age key, and also add a machine's own recipient when that machine or service must decrypt the file without the card."
    "Keep the existing method in a project that already encrypts with age or another method."
  ];

  # The whole Cross-model review section. Only a harness that hosts CE's
  # automatic pass carries it; an OpenCode session would name itself.
  peerSentences = [
    "Compound Engineering (CE) skills use `opencode` as the cross-model peer."
    "When the peer fails, skip the pass and say why in one line; do not retry it or run another peer in its place."
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
    "These rules add to the Tool use, Cross-model review, and Pull and merge requests sections of your other instructions, and where they differ, these rules take precedence."
    "When the T3 Code MCP tools are available, delegate every subagent job through T3 Code as Delegation describes, instead of using your native subagent tool."
    "This covers scouts, workers, and the reviewers or other parallel agents a skill dispatches in-process, such as `ce-code-review`'s reviewers, and overrides Tool use's instruction to hand parallel work to the subagent tool and T3 Code's own guidance to prefer native subagent tools for same-provider work."
    "Use your native subagent tool only when the T3 Code MCP tools are not available in this session, or when a delegated job falls back to it as Delegation describes."
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
    "When you create or edit a GitHub or GitLab issue, pull request, merge request, or a comment on one of them, attach the images and videos a reader needs to see the problem or the change, whether the user supplied them or you capture them."
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

  # How a T3 Code delegation returns and how to wait for it: async by
  # default, a completion notification instead of a blocking call, one
  # status read per task, and no polling or self-wake.
  asyncDelegationSentences = [
    "`delegate_task` does not block in its default `async` mode: it returns a `taskId` at once, and when the child finishes, T3 Code sends this thread a notification, steered into your current turn where the harness supports that or queued to start your next turn otherwise."
    "The notification only reports that the task finished; read the task's result with one `task_status` call, which returns at once and never waits."
    "Launch with `mode: \"wait\"` only when your next step needs the child's result and no other work could run meanwhile; it blocks until the child finishes or `timeoutMs` passes, and on a `waitTimedOut` result the child keeps running and still sends its notification, so end your turn and wait for it."
    "After an `async` launch, do the work that does not need the result; when a step needs results whose notifications have not all arrived, end your turn, and resume that step once every task it waits on has notified."
    "Never call `task_status` in a loop, and never start a sleep, timer, or background command to wake yourself for a delegated task."
    "Read a task's `task_status` once after its notification arrives, and otherwise at most once per task in a turn that started without any delegation notification, so a task that failed or shows no progress reaches the failure rule in this section."
    "Only the agent that owns the T3 Code thread ends its turn to wait; a subagent that delegates through T3 Code returns its task IDs to its caller, at once after an `async` launch or when a `mode: \"wait\"` launch returns `waitTimedOut`."
    "Ending your turn to wait for a delegated task's notification is allowed even where a skill says not to end the turn yet, such as `lfg`'s rule not to end the turn before `<promise>DONE</promise>`; when the notification arrives, continue the same run from the step that waited."
  ];

  toolsSentence = "The tools are `orchestrator_capabilities`, `delegate_task`, `task_status`, and `task_cancel`, possibly under a prefix such as `mcp__t3-code__`.";

  # Every sentence of the delegation section that may speak about status
  # reads, waiting, or self-wake. Any other such sentence there, such as an
  # added "keep polling `task_status`" or "wait five minutes and check
  # whether the child finished", fails.
  waitTopicSentences = [ toolsSentence ] ++ asyncDelegationSentences;

  delegationSentences = [
    "Delegate subagent work through the T3 Code MCP server, which knows which providers and models can run right now and tracks the child task for you."
    toolsSentence
    "They count as available when the session lists them by name, even when the harness must load their schemas before the first call."
    "Before delegating, list the runnable providers and models with `orchestrator_capabilities`."
    "Run each job on your own provider at the model its skill's tier names: Haiku for the cheapest capable tier, Sonnet for the mid-tier, and your session model when the skill names no tier."
    "Choose the latest version of that model that `orchestrator_capabilities` lists as runnable; a newer model of another class does not outrank it."
    "Choose an older version only when the latest is unavailable, has failed in this session, or the user or project asked for that version, and say why when you name the model."
    # Literal, not read from home/h82/agents/opencode-model.nix, so the
    # rendered model id is checked against an independent value.
    "When a skill runs its cross-model pass, delegate that pass as one task to provider instance `opencode` on `synthetic/syn:large:text` instead of the skill's own launch route; the skill's gates, such as `cross_model_review_mode`, still decide whether the pass runs, and you never add a pass the skill would not run."
    "Delegate the cross-model pass asynchronously in the same step that dispatches the skill's in-process reviewers, merge its result when it returns, and carry out the rest of the skill's procedure with it, adapting where the skill assumes its own route, such as a receipt that marks a peer as independently verified."
    "Tell the user which provider and model you delegated to."
    "Run every delegated task in full-access runtime mode."
    "Write a self-contained task prompt with all the context, prior findings, and constraints the child needs, because the child receives none of your conversation."
    "When the delegated work must not change files, such as a review or a job your native subagent tool would run as a read-only agent type, say so in the task prompt."
  ]
  ++ asyncDelegationSentences
  ++ [
    "When a delegated task fails, reports a provider error, or shows no progress, cancel it with `task_cancel`."
    "Skip a failed cross-model pass and say why in one line, with no retry and no other reviewer in its place."
    "Run any other failed job with your native subagent tool and tell the user in one line that you did."
    "Verify a delegated result against the repository or other primary evidence before you rely on it or report it as fact."
  ];

  # The delegation sentences that speak about the cross-model pass or a
  # peer. Any other such sentence in that section, such as a second peer or a
  # retry onto another provider, fails with a message that names it.
  peerPattern = "[Pp]eer|opencode|OpenCode|[Cc]ross-model|[Rr]eviewer";
  delegationPeerSentences = lib.filter (
    sentence: builtins.match ".*(${peerPattern}).*" sentence != null
  ) delegationSentences;

  # Names of what this repository removed from the instructions: Codex, every
  # Antigravity and Gemini mention, the OpenCode Zen peer, Model routing, and
  # the disclosure that reviewed content leaves for another provider.
  removedTerms = [
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

  opencodeTools = [
    "`read`"
    "`edit`"
    "`write`"
    "`glob`"
    "`webfetch`"
    "`websearch`"
    "`question`"
    "`subagent`"
    "`shell`"
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
      absent = opencodeTools;
      peer = true;
    };
    opencode = {
      name = "OpenCode";
      sharedSentence = "Use the tools OpenCode provides natively before reaching for a shell equivalent.";
      present = opencodeTools;
      absent = claudeTools;
      peer = false;
    };
  };

  # Each part's pinned sentences, for the exactly-once and wrong-path counts.
  partSentences = harness: {
    system = [
      harness.sharedSentence
    ]
    ++ toolUseSentences
    ++ gpgSentences
    ++ lib.optionals harness.peer peerSentences;
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
    ${requireSentences "${label} lacks the tool-use rule:" toolUseSentences}
    ${requireSentences "${label} lacks the GPG rule:" gpgSentences}
    ${onlyPinnedSentences "${label} carries an unpinned GPG sentence:" "# GPG and encryption" "."
      gpgSentences
    }
    ${
      if harness.peer then
        ''
          ${requireSentences "${label} lacks the cross-model peer rule:" peerSentences}
          ${sentencesInOrder "${label} reorders, duplicates, or adds to the cross-model peer rule:"
            "# Cross-model review"
            peerSentences
          }
        ''
      else
        ''
          ${countSentences "${label} names its own harness as the cross-model peer" 0 peerSentences}
          if grep -qxF '# Cross-model review' "$file"; then
            echo ${esc "${label} carries the Cross-model review section"} >&2
            failed=1
          fi
        ''
    }
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
    ${requireSentences "${label} lacks the delegation rule:" delegationSentences}
    ${onlyPinnedSentences "${label} carries an unpinned cross-model peer sentence:" "# Delegation"
      peerPattern
      delegationPeerSentences
    }
    ${onlyPinnedSentences "${label} carries an unpinned delegation wait sentence:" "# Delegation"
      "task_status|[Pp]oll|[Nn]otif|[Ww]ait|[Ww]ake|[Bb]lock|[Ss]leep|[Tt]imer|[Cc]heck|[Ff]inish|[Bb]ackground|[Ss]chedul"
      waitTopicSentences
    }
    ${onlyPinnedSentences "${label} carries an unpinned delegation sentence:" "# Delegation" "."
      delegationSentences
    }
    ${sentencesInOrder "${label} reorders or duplicates a delegation sentence:" "# Delegation"
      delegationSentences
    }
    ${sentencesInSection "${label} moves a delegation sentence out of its section:" "# Delegation"
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
      for term in ${lib.escapeShellArgs removedTerms}; do
        if grep -qF -- "$term" "$file"; then
          echo ${esc "${label} names something the instructions no longer carry:"} "$term" >&2
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
      t3Activation = user.home.activation.t3codeSettings or null;
      on = lib.optionalString t3;
    in
    ''
      d=$(mktemp -d)

      ${homeFile label user ".claude/CLAUDE.md" 1 "$d/claude"}
      ${homeFile label user claudeT3Target (if t3 then 1 else 0) "$d/claude-t3"}
      ${homeFile label user ".codex/AGENTS.md" 0 "$d/codex"}
      ${homeFile label user ".gemini/config/AGENTS.md" 0 "$d/antigravity"}
      ${homeFile label user ".gemini/GEMINI.md" 0 "$d/gemini"}
      ${homeFile label user ".config/opencode/AGENTS.md" 0 "$d/opencode-global"}
      ${opencodeFile label user "$d/opencode"}

      ${
        if t3 then
          ''
            declared=$(${declaredOf (t3Activation.data or "")})
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
      file=$d/opencode
      ${channelRules "the standalone OpenCode instructions on ${label}" harnesses.opencode [
        "system"
        "user"
      ]}
      ${on ''
        file=$d/claude-t3
        ${channelRules "~/${claudeT3Target} on ${label}" harnesses.claude-code [ "t3code" ]}
      ''}

      ${pathRules "the Claude Code terminal path on ${label}" harnesses.claude-code
        [ "$d/claude" ]
        [ "system" "user" ]
      }
      ${pathRules "the standalone OpenCode path on ${label}" harnesses.opencode
        [ "$d/opencode" ]
        [ "system" "user" ]
      }
      ${on ''
        ${pathRules "the Claude Code T3 Code path on ${label}" harnesses.claude-code [
          "$d/claude"
          "$d/claude-t3"
        ] partNames}
      ''}

      rm -rf "$d"
    '';

  configurations = import ./lib/configurations.nix { inherit pkgs self fixtures; };

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
pkgs.runCommand "agent-instructions-tests"
  {
    nativeBuildInputs = [
      pkgs.jq
      pkgs.python3
    ];
  }
  ''
    ${configurations.userGuard}
    ${sidesGuard}
    failed=0
    seen=$(mktemp)

    ${lib.concatMapStringsSep "\n" assertEntry users}

    if [ "$failed" != "0" ]; then
      exit 1
    fi

    touch $out
  ''
