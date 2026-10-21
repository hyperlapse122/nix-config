/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions, one Go template rendered once
  per harness over the host facts and that harness's peers, reach every
  installed harness for user `h82` on every host this flake declares:

    Claude Code       ~/.claude/CLAUDE.md, which T3 Code's Claude sessions read
    OpenCode          ~/.config/opencode/AGENTS.md, which every run loads;
                      the Claude Code rendering
    Antigravity CLI   ~/.gemini/config/AGENTS.md
    Grok Build        ~/.grok/rules/instructions.md

  The user list is `userEntries` from `tests/lib/configurations.nix`.

  Verifies, per Home Manager user:
  - exactly one enabled Home Manager file resolves to each delivery path, and
    none to the retired ~/.t3/instructions/claude-code/CLAUDE.md, Codex's
    ~/.codex/AGENTS.md, or Gemini's ~/.gemini/GEMINI.md, none of which is
    installed. The lookup compares each entry's resolved `target` rather than
    its attribute name, and reads `enable`, because either can move the file
    without changing its text.
  - each delivery path exists in the materialized `home-files` and equals its
    harness's expected file byte for byte. Paths of one harness share one
    expected file, so OpenCode matches the Claude Code rendering. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - every pinned sentence appears exactly once and starts where a sentence
    starts, so a dropped, doubled, or negated ("Do not ...") rule fails. See
    .compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md
  - every section holds only its pinned sentences, each once and in order,
    so a separate sentence that reverses a pinned rule fails wherever it is
    added. The Compound Engineering list is a function of that harness's peer
    literals.
  - the file's top-level `# ` headings are exactly the expected list, in
    order, and no text precedes the first, so a rule under a new heading or
    above every heading cannot escape the section checks.
  - every delivery path's recipient sentence names the entry's own
    `my.user.gpgKey`, and Git signs with that same key. The fixture host whose
    key is the fake value below must carry neither the card fingerprint in any
    of its instruction files nor the card key in its Git config, so a literal
    fingerprint left in the instructions or in Git turns this red. The fake
    entry is selected by its evaluated key, never by its name, and the builder
    fails when no entry carries it on x86_64-linux, where that fixture builds.
    See
    .compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md
  - each expected file is the template with the known actions replaced by
    literals written in this check, not read from the module: `{{ .user.gpgKey }}`
    by the entry's key, and each `{{ .peers.<first|second>.<field> }}` by that
    harness's peer. Any other action in the template turns the check red. The
    byte comparison stays green across a prose edit of the template; the
    pinned sentences do not.
  - `t3_thread_wait`, `CROSS_MODEL_HARD_SECS`, `timeoutMs`, `childRunId`, and
    `t3_thread_read` appear only inside `# T3 Code` and `# Compound
    Engineering`, where every sentence is pinned, so a rule elsewhere cannot
    restore the blocking wait for a run with a person present or change when
    a result is taken from a task's session.
  - the file names no removed section, harness, model, or rule, matched
    without regard to case, carries no unescaped tilde outside a code span,
    and carries no template action (`{{`, `}}`, `<no value>`) or unrendered
    `@name@` placeholder.

  The expected sentences and the peer literals are written here, not read from
  the module, so a mutation of the instruction file turns this red.

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

  template = builtins.readFile ../home/h82/agents/instructions/instructions.md.tmpl;

  # Peer literals live here on purpose. Importing them from
  # home/h82/agents/instructions/default.nix would let that module and this
  # check drift together and stay green.
  peerClaudeCode = {
    name = "Claude Code";
    instance = "claudeAgent";
    model = "`claude-opus-5-5`";
    provider = "Anthropic";
  };
  peerAntigravity = {
    name = "Antigravity";
    instance = "antigravity";
    model = "`gemini-4-argon-medium`";
    provider = "Google";
  };
  peerGrok = {
    name = "Grok";
    instance = "grok";
    model = "its default model";
    provider = "xAI";
  };

  harnessPaths = {
    claude-code = [
      ".claude/CLAUDE.md"
      ".config/opencode/AGENTS.md"
    ];
    antigravity = [ ".gemini/config/AGENTS.md" ];
    grok = [ ".grok/rules/instructions.md" ];
  };
  harnessPeers = {
    claude-code = {
      first = peerAntigravity;
      second = peerGrok;
    };
    antigravity = {
      first = peerClaudeCode;
      second = peerGrok;
    };
    grok = {
      first = peerClaudeCode;
      second = peerAntigravity;
    };
  };
  harnessNames = lib.attrNames harnessPaths;

  actionValues = key: peers: {
    "{{ .user.gpgKey }}" = key;
    "{{ .peers.first.name }}" = peers.first.name;
    "{{ .peers.first.instance }}" = peers.first.instance;
    "{{ .peers.first.model }}" = peers.first.model;
    "{{ .peers.first.provider }}" = peers.first.provider;
    "{{ .peers.second.name }}" = peers.second.name;
    "{{ .peers.second.instance }}" = peers.second.instance;
    "{{ .peers.second.model }}" = peers.second.model;
    "{{ .peers.second.provider }}" = peers.second.provider;
  };
  knownActions = lib.attrNames (actionValues fakeKey harnessPeers.claude-code);

  extractActions =
    text:
    map (
      piece:
      let
        closed = lib.splitString "}}" piece;
      in
      if lib.length closed < 2 then null else "{{${lib.head closed}}}"
    ) (lib.tail (lib.splitString "{{" text));

  templateActions = extractActions template;
  unknownActions = lib.filter (
    action: action != null && !(lib.elem action knownActions)
  ) templateActions;
  malformedAction = lib.any (action: action == null) templateActions;

  expectedFile =
    harness: key:
    let
      values = actionValues key harnessPeers.${harness};
    in
    pkgs.writeText "expected-instructions-${harness}.md" (
      lib.replaceStrings (lib.attrNames values) (lib.attrValues values) template
    );
  fakeKey = "0123456789ABCDEF0123456789ABCDEF01234567";

  recipientSentence =
    key:
    "For a new SOPS setup or secret file, use the card key `${key}` as the user's recipient, plus a machine's own recipient when it must decrypt without the card.";

  gpgHeading = "# GPG and encryption";

  # In section order, like `reviewFindingsSentences`. The recipient sentence
  # names each entry's own key, so the list is a function of that key.
  gpgSentences = key: [
    "The user's GPG key is on a YubiKey that stays connected, and its PIN is usually cached."
    "Run GPG signing, decryption, and encryption yourself, including SOPS re-encryption and edits; when a pinentry dialog appears, let it reach the user."
    "Stop and report only when the PIN is rejected, the prompt times out, or the card is missing."
    "Never print decrypted values, pass them as arguments, or open decrypted files with the file tools; pipe decrypted output straight into the command that consumes it."
    "Leave card administration and key management to the user."
    (recipientSentence key)
    "Keep the existing method in a project that already has one."
  ];

  gitHeading = "# Git";

  gitSentences = [
    "Before the first push, rename a branch whose name does not describe the change, such as a worktree codename or random hex, with `git branch -m`."
    "Follow the project's documented naming rule; otherwise name it `<kind>/short-kebab-slug` with a full-word GitHub Flow kind: `feature/`, `fix/`, `docs/`, `chore/`, or `refactor/`."
    "Never rename onto or push over an existing branch."
    "When a commit hook fails because mise does not trust a `mise.toml` in a temporary copy the hook made, retry that commit once with `MISE_TRUSTED_CONFIG_PATHS=\"$(cd \"\${TMPDIR:-/tmp}\" && pwd -P)\"`."
    "Do not run `mise trust` on the copy or skip the hook with `--no-verify`."
    "Before each push, find the learnings under the project's Compound Engineering `solutions/` directory that cite a path or name the pushed commits delete, move, or rename."
    "Refresh each with `ce-compound-refresh`, commit each refresh separately on the current branch, then push once."
  ];

  pullRequestsHeading = "# Pull and merge requests";

  pullRequestsSentences = [
    "Treat GitLab like GitHub: when a Compound Engineering skill speaks only GitHub, do the same steps with `glab`, and skip only a step with no GitLab counterpart, naming it in your report."
    "After you open or push to a pull or merge request, babysit it until it looks ready to merge, then leave the merge to the user."
    "Babysit a draft only when asked."
    "On GitLab, call it ready only when `head_pipeline` passed on the current `sha`, `detailed_merge_status` is `mergeable`, and no discussion is unresolved; never rebase."
    "Attach the screenshots or recordings a reader needs to see the change."
    "Before uploading, cover secrets, personal data, and internal hosts with opaque boxes, never blur, and strip metadata with `ffmpeg -map_metadata -1`."
    "Upload through `gh --attach` or the GitLab uploads API, never a browser."
  ];

  markdownHeading = "# Markdown";

  # Each `\\~` is one literal backslash and tilde: Nix drops the backslash of
  # an unknown escape in a double-quoted string.
  markdownSentences = [
    "When you write a range in text that renders as Markdown, in any language, write it in prose, not in a code span, with a dash, as in `1-3` or `10:00-12:00`, or an escaped tilde, as in `1\\~3`, and never with a bare `~` or `~~`, so tildes never render as strikethrough."
    "Treat a tilde that marks an approximation, such as `~5 min`, the same way: write \"about 5 min\" or `\\~5 min` in prose, not in a code span."
    "This covers chat replies, pull request and issue bodies and comments, and Markdown documents; put any other tilde, such as a path like `~/.config` or a Git revision like `HEAD~1`, in a code span, and leave a tilde inside a code span or code block as it is."
    "In text that does not render as Markdown, such as commit messages, code comments, and plain-text or config files, write a range with a dash or a word, and an approximation with a word, and never with `\\~`."
  ];

  koreanTextHeading = "# Korean text";

  koreanTextSentences = [
    "Korean text that outlasts the conversation is covered text: commit messages, pull and merge request bodies and comments, issue bodies and comments, documents, Korean inside code such as comments, string literals, user-facing messages, logs, and localization resources, and a closing report, summary, or handoff to the user."
    "A short conversational chat reply is not covered text."
    "Before you write covered text, load the `humanizer`, `grammar-checker`, and `style-guide` skills, once per session."
    "Write covered text by those skills' rules, check it with all three before you publish it, and apply every correction you find."
    "Apply them silently: do not paste their analysis tables, grades, or change summaries into the text or the conversation."
    "These instructions outrank those skills' own procedures: publish only the corrected text, never call `AskUserQuestion` or stop for confirmation on their behalf, and infer the closest document type when it is unclear."
    "Where those skills' rules conflict with the Markdown section above, such as a bare tilde in a range, follow the Markdown section."
    "Leave text the user asks you to post as written, and verbatim quotes, unchanged."
    "When a report also goes through `ce-noslop`, run `ce-noslop` first, then `humanizer`, `grammar-checker`, and `style-guide` in that order."
    "When `ce-code-review`, `ce-doc-review`, or `ce-simplify-code` meets Korean text in the diff or document under review, audit that text with all three skills and report each problem as a finding of that review, whoever wrote the text."
    "Put that audit rule in the task prompt of every reviewer or cross-model peer you delegate the review to, because a delegated agent does not see these instructions."
  ];

  reviewFindingsHeading = "# Review findings";

  # In section order: `sentencesInOrder` compares the section to this list.
  reviewFindingsSentences = [
    "Apply every finding that `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` report in the same change, whatever its severity, confidence, or list, including testing gaps and residual risks."
    "A skill's own apply bar, confidence threshold, or list, including `lfg`'s, does not narrow this rule."
    "\"By design\", \"no current instance\", \"low impact\", and \"the fix has a trade-off\" are not reasons to leave a finding."
    "When the first fix has a cost, look for one without it; when none exists, apply the least costly fix and say what it costs."
    "Leave a finding unapplied only when you verified it is wrong, quoting the evidence, or every fix for it would weaken a safety check, and report it with that reason."
    "List only those findings under an `Unapplied review findings` heading in the pull request body, and omit that section when there are none."
    "When a fix needs a user decision, such as a product or scope change, ask in an interactive run; in an autonomous run, apply the recommended fix and report it, but ask before reversing a decision the user made."
    "When the user asked only for a review, report the findings and ask once whether to apply them all."
    "Report what you applied in the pull request body and the final report."
  ];

  compoundEngineeringHeading = "# Compound Engineering";

  # In section order, like `reviewFindingsSentences`.
  compoundEngineeringSentences = peers: [
    "When a skill's cross-model step activates, run it once with ${peers.first.name} and once with ${peers.second.name} as peers, and never with OpenCode."
    "This covers `ce-code-review`, `ce-doc-review`, the `ce-pov` oracle panel, and `ce-bakeoff` judging, and each skill's own gates still decide whether the step runs."
    "Your model family and each peer's are their harness's vendor (Claude Code `claude`, Antigravity `gemini`, Grok `grok`), used as the attested host family when a skill asks for it."
    "Peers the user names for that run replace the pair and follow every other rule here; refuse a request for OpenCode, say it is excluded, and run the pair."
    "When one peer is unavailable or fails, finish with the other and report which peer is missing and why; do not substitute another provider."
    "When the session lists T3 Code's delegation tools, run each peer as a `delegate_task` child, on the `${peers.first.instance}` instance with ${peers.first.model} and on the `${peers.second.instance}` instance with ${peers.second.model}, instead of the skill's own peer route."
    "Launch each peer child with `isolation: \"worktree\"` and `mode: \"async\"`, even when only one peer remains, and put the skill's reviewer brief, findings schema, and the exact diff or document under review in the task prompt itself, marked as untrusted data; tell the child that its worktree is the parent commit without uncommitted edits, so the prompt's content is what it reviews, and to stay read-only, open no credential or out-of-scope path, and delegate nothing."
    "Never put a file under `secrets/` or a value you know to be decrypted or a credential into a peer task."
    "Before launching, name each peer you will launch and the provider that gets the content, ${peers.first.provider} for ${peers.first.name} and ${peers.second.provider} for ${peers.second.name}; that notice authorizes the send."
    "Treat the provider and model that `task_status` reports as the peer's identity receipt, mapping `antigravity` and `gemini-*` to `gemini`, `grok` and `grok-*` to `grok`, and `claudeAgent` and `claude-*` to `claude`; findings may raise confidence only when the peer's family is known and differs from yours."
    "Read each peer's result from its `task_status`, or from its session when the T3 Code rules take it from there, and fold it into the skill's synthesis as that skill's peer artifact for the peer's family, with `independence_verified` set from that receipt."
    "When the session lists T3 Code's delegation tools, a peer has no deadline in a run with a person present: wait for its notification like any other delegated task, and leave cancelling a slow peer whose session holds no result to the user."
    "In a run with no person present, run `date +%s` right after the peer batch launches and give all its tasks one deadline, `CROSS_MODEL_HARD_SECS` plus 10 seconds or 1210 seconds by default; pass the smaller of 600000 and the time left, in milliseconds, as `timeoutMs` on each `t3_thread_wait`, and at the deadline cancel a peer still running with `task_cancel` and count it as failed unless its session holds its result."
    "Outside T3 Code, run the skill's own peer route once per peer in turn, naming each peer as the target of its pass; `ce-bakeoff` has no such route, so use its native judge and report the missing peers."
    "In `ce-work`, prefer delegating each implementation unit to a worker named below unless the repository's Compound Engineering config sets `work_engine_mode: off`."
    "Never delegate an implementation unit to Grok or OpenCode, inside or outside T3 Code."
    "In a Grok or OpenCode session, delegate every implementation unit to a worker named below instead of writing it yourself."
    "When the config sets `work_engine_mode: off`, a Grok or OpenCode session implements no unit itself: it stops and tells the user that delegation is off."
    "A unit is harder when its own design is hard, such as a new interface, data format, or concurrency rule, when it carries a security or data-loss risk, even when its edit is mechanical, or when it changes many modules in a way that is not a mechanical edit."
    "Otherwise a unit is lighter when it is a mechanical edit, such as a rename, a pinned-text update, or a one-file docs change, even across files; every other unit is a default unit."
    "A default unit goes to `claude-sonnet-5-5` on the `claudeAgent` instance with `effort` set to the value `orchestrator_capabilities` marks as its default, or to `gemini-3.8-flash-high` on the `antigravity` instance."
    "A harder unit goes to `claude-opus-5-5` on the `claudeAgent` instance with `effort` set to the value `orchestrator_capabilities` marks as that model's default, or to `gemini-4-argon-medium` on the `antigravity` instance."
    "A lighter unit goes to `claude-haiku-5-5` on the `claudeAgent` instance with `effort` `xhigh`, or `max` when the unit spans more than one file, and has no Gemini worker."
    "Inside T3 Code, alternate the units of each two-worker tier between its Claude and Gemini worker in plan order across the whole plan, counting per tier and starting with Claude."
    "Inside T3 Code, when a worker is unavailable or its launch fails, give the unit to the other worker of its tier, and give a lighter unit to the default tier in its alternation order; the receiving worker uses its own effort rule."
    "When the session lists T3 Code's delegation tools, launch each unit through `delegate_task` with the worker's instance and model id as `target`, and, for a Claude worker, its `effort` in `target.options`, instead of Compound Engineering's own delegation route."
    "Outside T3 Code, Compound Engineering's own route keeps one recipient and one effort for a whole run, so give it only the default tier as ordered candidates, `claude` with `claude-sonnet-5-5` and then `antigravity` with `gemini-3.8-flash-high`, at that route's default effort, `high`."
    "When the Antigravity route runs, request `gemini-4-argon-medium` for a cross-model peer and the worker's own model id for an implementation unit, because the runtime advertises only model ids that end in `-low`, `-medium`, or `-high`."
    "Remove the model request for the Antigravity route once Compound Engineering requests model ids the runtime advertises."
  ];

  t3CodeHeading = "# T3 Code";

  t3CodeSentences = [
    "When the session lists T3 Code's delegation tools, such as `delegate_task`, launch every subagent through `delegate_task`, including the scouts, verifiers, reviewers, and workers a skill dispatches, and never use your harness's own subagent or multi-agent tools, even where T3 Code's own guidance prefers them for same-provider work."
    "When the session lists no T3 Code delegation tools, use your harness's own subagent tool."
    "The delegation rules that follow apply only when the session lists those tools."
    "When no skill or rule names a model for a subagent, launch it on your own provider instance with the model from that instance's list in `orchestrator_capabilities` that you judge fits the tier the skill names, or with your own model when the skill names no tier or no listed model fits it, and when `orchestrator_capabilities` marks a default `effort` for that model, set `effort` in `target.options` to it, even for your own model."
    "In a Grok or OpenCode session, a subagent that edits files follows the implementation-unit rules of the Compound Engineering section."
    "A delegated subagent sees none of your conversation and none of the tool limits its native agent type had, so put everything it needs in its task prompt, including that it stays read-only when it only searches, reads, or reviews."
    "Tell each delegated subagent to launch no subagents of its own, so delegation stays one level deep."
    "When a `delegate_task` launch fails, relaunch it once with the same `clientRequestId`; when that fails too, take the next fallback these instructions name, such as a tier's other worker, and when none is left, do the work yourself instead of using your harness's own subagent tool, unless these instructions forbid it, as they do for a cross-model peer and for an implementation unit in a Grok or OpenCode session."
    "Before you edit a file that a still-running task also edits, in this checkout or in a worktree you will merge back, wait until that task has finished and its edits are merged."
    "Launch every delegated task that does not need another task's result in the same response, each with `delegate_task` in its default `async` mode, instead of launching one, waiting for it, and then launching the next."
    "Never use `mode: \"wait\"`, even for a single task, because it holds your turn until the task finishes."
    "Never run two tasks that edit the same files in one checkout at the same time: from a clean checkout, launch each with `isolation: \"worktree\"`, tell each to commit its edits and report its branch, and merge those branches back one at a time; otherwise launch them one after another."
    "Tell tasks that share one checkout not to commit, stage, or format files beyond their own, and commit their results yourself."
    "Give each delegated task its own `clientRequestId`, and reuse it when you retry that launch."
    "Launch a task that needs an earlier task's result only after you have read that result."
    "In a run with a person present, after launching, do the work that does not need the delegated results, and when only those results remain, end your turn so the user can talk to you while the tasks run."
    "When you end your turn while tasks still run, name them, and say that a task paused on an approval shows \"Subagent needs approval\" in its thread and waits for the user, because T3 Code sends no notification for it."
    "Each notification T3 Code delivers, whether it starts your turn or arrives with a user message, names the tasks that reached a terminal state or have a question; read each finished task's result with one `task_status` call."
    "While another task the waiting step needs is still running, end your turn again without cancelling it, and continue that step once every result it needs has arrived through a notification or from the task's session."
    "When a notification says a delegated task has a question, read it with `t3_pending_request_read`, then answer it with `t3_pending_request_respond` or ask the user, and end your turn again."
    "When the user writes while delegated tasks are running, send any answer they give to a pending question to its task with `t3_pending_request_respond`, answer the rest, keep the tasks and the waiting step, and end your turn again unless they redirect the work."
    "On every turn you get while a task the waiting step needs has not reached a terminal state, whether a notification, a user message, a background wait, or a `t3_thread_wait` timeout started it, read that task's session with `t3_thread_read` on its `childThreadId` in the `activity` view, paging with `afterPosition` to the end and reading the full text of its latest assistant message with `itemId` and `textOffset`, because a task, such as a Grok cross-model peer, can write its result and never finish."
    "When that latest assistant message is finished and holds the whole result the task prompt asked for, and no item in the session is still running, use the message as the task's result, read its `task_status` once, stop it with `task_cancel`, and say that you took its result from the session; when `task_cancel` leaves it running, keep the result and tell the user the task still runs so they can stop it."
    "In a run with a person present, while a task the waiting step needs still runs when you end your turn, keep exactly one background command pending that waits 10 minutes, such as `sleep 600`, started through your harness's own way of running a command in the background that wakes you when it exits; when it wakes you, check the sessions as above, and start the next one while such a task still runs."
    "When your harness has no such way, say so when you end your turn, so the user can write to you to have you check the sessions."
    "In a run with a person present, never wait for a delegated task with `t3_thread_wait`; in any run, never call `task_status` in a loop, and never start a sleep, timer, or background command to wake yourself other than the one 10-minute background wait above."
    "Ending your turn to wait for a delegated task is allowed even where a skill says not to end the turn or to fail when no blocking wait exists, such as `lfg`'s rule not to end the turn before `<promise>DONE</promise>` or `ce-code-review`'s reviewer collection; when the results arrive, continue the same run from the step that waited."
    "For such a skill, a completion notification and one `task_status` read, or a result taken from the task's session, are the task's terminal outcome, and a task the skill bounds by time counts as failed when you resume after that bound has passed and its session holds no result."
    "In a run with no person present, such as a headless, scheduled, or pipeline run, wait inside the turn instead: once every task is launched, call `t3_thread_wait` on each task's `childThreadId` with its `childRunId` as `runId` and the smaller of 600000 and the time left before any bound on that task as `timeoutMs`, then read each result with one `task_status` call."
    "When that wait returns `timedOut: true`, read the task's `task_status` once, answer a pending question with `t3_pending_request_respond` from the task and your instructions, check its session as above, and wait again with the same `runId` unless you took its result."
    "When a skill bounds a delegated task by time and the bound passes while it still runs, check its session as above, and cancel it with `task_cancel` and count it as failed only when its session holds no result."
    "When `task_status` shows `workState` `working` or `hasPendingChildRuns` true, call `t3_thread_wait` on that thread again without `runId` and with `timeoutMs` as above; when `childRunId` is null, or the task shows `waiting_for_children` with `hasPendingChildRuns` false, there is no run to block on, so read the other results, end your turn, and resume on that task's notification."
    "When the session lists T3 Code's pull request tools, such as `watch_pull_request`, use them to watch a request you babysit instead of your own background wait."
    "When the session lists T3 Code's preview tools, such as `preview_open`, show any local HTML file you open for the user in a T3 Code browser tab instead of running `xdg-open` or `open`: run `serve-html <file>`, open a new tab with `preview_open` and `reuseExistingTab` set to false so the user's own tab stays as it is, then call `preview_navigate` with that tab's `tabId` and the line `serve-html` printed as `target`."
    "Pass `--root <dir>` to `serve-html` when the page loads sibling files from a report directory."
    "When the user asks to see a page again, or says its tab no longer loads, run `serve-html` again instead of reusing an earlier target, and navigate the same tab to the new target."
    "A run with no person present, such as a headless or pipeline run, still opens nothing."
    "When the session lists no T3 Code preview tools, or `serve-html`, `preview_open`, or `preview_navigate` fails, keep the skill's own way of opening the file and print the file's absolute path."
  ];

  # A separate contradicting sentence could defeat a pinned rule in any
  # section, so every section gets the allowlist, membership, and order checks.
  checkedSections = key: compoundSentences: [
    {
      name = "GPG and encryption";
      heading = gpgHeading;
      sentences = gpgSentences key;
    }
    {
      name = "Git";
      heading = gitHeading;
      sentences = gitSentences;
    }
    {
      name = "pull and merge requests";
      heading = pullRequestsHeading;
      sentences = pullRequestsSentences;
    }
    {
      name = "Markdown";
      heading = markdownHeading;
      sentences = markdownSentences;
    }
    {
      name = "Korean text";
      heading = koreanTextHeading;
      sentences = koreanTextSentences;
    }
    {
      name = "review-findings";
      heading = reviewFindingsHeading;
      sentences = reviewFindingsSentences;
    }
    {
      name = "Compound Engineering";
      heading = compoundEngineeringHeading;
      sentences = compoundSentences;
    }
    {
      name = "T3 Code";
      heading = t3CodeHeading;
      sentences = t3CodeSentences;
    }
  ];

  pinnedSentences =
    compoundSentences:
    [
      gpgHeading
    ]
    ++ lib.filter (sentence: sentence != recipientSentence fakeKey) (gpgSentences fakeKey)
    ++ [ gitHeading ]
    ++ gitSentences
    ++ [ pullRequestsHeading ]
    ++ pullRequestsSentences
    ++ [ markdownHeading ]
    ++ markdownSentences
    ++ [ koreanTextHeading ]
    ++ koreanTextSentences
    ++ [ reviewFindingsHeading ]
    ++ reviewFindingsSentences
    ++ [ compoundEngineeringHeading ]
    ++ compoundSentences
    ++ [ t3CodeHeading ]
    ++ t3CodeSentences;

  # In file order. A heading outside this list would end the section above it,
  # so a contradicting rule under it would escape every section check.
  topLevelHeadings = [
    "# GPG and encryption"
    "# Git"
    "# Pull and merge requests"
    "# Markdown"
    "# Korean text"
    "# Review findings"
    "# Compound Engineering"
    "# T3 Code"
  ];

  # Terms of the in-turn delegated wait and the peer deadline, which apply
  # only to a run with no person present, and of the session check that takes
  # a stalled task's result. They may appear only inside the checked
  # `# T3 Code` and `# Compound Engineering` sections, where every sentence is
  # pinned, so a rule added elsewhere cannot bring the blocking wait back for
  # a run with a person present or change when a session result is taken.
  confinedTerms = [
    "t3_thread_wait"
    "CROSS_MODEL_HARD_SECS"
    "timeoutMs"
    "childRunId"
    "t3_thread_read"
  ];

  removedTerms = [
    "# Tool use"
    "# Cross-model review"
    "# Delegation"
    "type/short-kebab-slug"
    "Conventional Commits type"
    "Flash low"
    "Flash medium"
    "Flash high"
    "Flash Lite"
    "flash-low"
    "flash-medium"
    "flash-lite"
    "flash-free"
    "gemini-4-argon-high"
    "Pick the model by harness"
    "another harness"
    "Codex"
    "Zen"
    "Model routing"
    "receives the reviewed content"
    "data terms"
    "leaves out Antigravity"
    "for that pass only"
  ];

  # Fails the build, naming each sentence, unless `$file` holds it exactly
  # once and that occurrence starts where a sentence starts: at the start of
  # a line, after a list marker, or after the previous sentence's full stop.
  # A substring match would accept the sentence inside its own negation
  # ("Do not Apply every..."). The sentence reaches awk through the
  # environment, because `awk -v` processes escape sequences and turns a
  # pinned `\~` into `~`.
  requireSentences = message: sentences: ''
    for sentence in ${lib.escapeShellArgs sentences}; do
      if ! s="$sentence" awk '
        BEGIN { s = ENVIRON["s"] }
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

  # Prints the section under `heading` one sentence per line, list markers
  # dropped, splitting after each full stop. A pinned sentence must not hold
  # a full stop followed by a space, such as "e.g. ".
  sectionSentences = heading: ''
    h=${esc heading} awk '
      BEGIN { h = ENVIRON["h"] }
      $0 == h { inside = 1; next }
      /^# / { inside = 0 }
      inside { sub(/^ *- /, ""); gsub(/\. /, ".\n"); print }
    ' "$file"'';

  # Fails the build, naming each sentence, when the section under `heading`
  # carries a sentence that is not one of `sentences`. A required-sentence
  # check cannot see a separate sentence that reverses a pinned rule.
  onlyPinnedSentences = message: heading: sentences: ''
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
      ${sectionSentences heading} | grep -E -- . || true
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
  # duplicated sentence, or one moved away from the sentence it leans on.
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

  # The pinned sentences and checked sections of one harness's rendering.
  rulesFor =
    key: peers:
    let
      compoundSentences = compoundEngineeringSentences peers;
    in
    {
      pinned = pinnedSentences compoundSentences;
      sections = checkedSections key compoundSentences;
    };

  fileRules = label: key: absentKeys: rules: ''
    if [ ! -s "$file" ]; then
      echo ${esc "${label} is missing or empty"} >&2
      failed=1
    else
      ${requireSentences "${label} does not hold this sentence exactly once, where a sentence starts:" (
        rules.pinned ++ [ (recipientSentence key) ]
      )}
      ${lib.concatMapStrings (section: ''
        ${onlyPinnedSentences "${label} carries an unpinned ${section.name} sentence:" section.heading
          section.sentences
        }
        ${sentencesInSection "${label} moves a ${section.name} sentence out of its section:" section.heading
          section.sentences
        }
        ${sentencesInOrder "${label} reorders or duplicates a ${section.name} sentence:" section.heading
          section.sentences
        }
      '') rules.sections}
      expected=$(mktemp)
      actual=$(mktemp)
      printf '%s\n' ${lib.escapeShellArgs topLevelHeadings} > "$expected"
      grep -E -- '^# ' "$file" > "$actual" || true
      if ! cmp -s "$expected" "$actual"; then
        echo ${esc "${label} carries top-level headings other than the expected list:"} >&2
        diff "$expected" "$actual" >&2 || true
        failed=1
      fi
      # No section check sees text above the first heading.
      if awk '/^# / { exit } NF { found = 1 } END { exit !found }' "$file"; then
        echo ${esc "${label} carries text before its first top-level heading"} >&2
        failed=1
      fi
      for term in ${lib.escapeShellArgs removedTerms}; do
        if grep -qiF -- "$term" "$file"; then
          echo ${esc "${label} names something the instructions no longer carry:"} "$term" >&2
          failed=1
        fi
      done
      outside=$(mktemp)
      t=${esc t3CodeHeading} c=${esc compoundEngineeringHeading} awk '
        BEGIN { t = ENVIRON["t"]; c = ENVIRON["c"] }
        /^# / { inside = ($0 == t || $0 == c) }
        !inside { print }
      ' "$file" > "$outside"
      for term in ${lib.escapeShellArgs confinedTerms}; do
        if grep -qiF -- "$term" "$outside"; then
          echo ${esc "${label} names a delegated-wait term outside the T3 Code and Compound Engineering sections:"} "$term" >&2
          failed=1
        fi
      done
      for key in ${lib.escapeShellArgs absentKeys}; do
        if grep -qF -- "$key" "$file"; then
          echo ${esc "${label} names a key other than the host's my.user.gpgKey:"} "$key" >&2
          failed=1
        fi
      done
      if awk '
        {
          line = $0
          gsub(/`[^`]*`/, "", line)
          if (line ~ /(^|[^\\])~/) {
            print $0
            found = 1
          }
        }
        END { exit !found }
      ' "$file" >&2; then
        echo ${esc "${label} carries an unescaped tilde outside a code span"} >&2
        failed=1
      fi
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
      ${lib.concatMapStrings (
        harness: lib.concatMapStrings (target: homeFile label user target 1) harnessPaths.${harness}
      ) harnessNames}
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
      ${lib.concatMapStrings (
        harness:
        let
          expected = expectedFile harness key;
          rules = rulesFor key harnessPeers.${harness};
          # Every path of a harness must equal one expected file, so the
          # sentence rules need to read only its first path.
          firstTarget = lib.head harnessPaths.${harness};
        in
        lib.concatMapStrings (target: ''
          file=${homeFiles}/${target}
          if [ ! -s "$file" ]; then
            echo ${esc "~/${target} on ${label} is missing or empty in home-files"} >&2
            failed=1
          else
            if ! cmp -s "$file" ${expected}; then
              echo ${esc "the ${harness} instructions at ~/${target} on ${label} are not the template with the known actions replaced by this check's literals:"} >&2
              diff ${expected} "$file" >&2 || true
              failed=1
            fi
            ${lib.optionalString (target == firstTarget) (
              fileRules "the ${harness} instructions at ~/${target} on ${label}" key (lib.optional fake cardKey)
                rules
            )}
          fi
        '') harnessPaths.${harness}
      ) harnessNames}

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

  ${lib.optionalString (unknownActions != [ ] || malformedAction) ''
    echo ${
      esc (
        "instructions.md.tmpl holds an action this check does not know: "
        + (
          if unknownActions != [ ] then
            lib.concatStringsSep ", " unknownActions
          else
            "a {{ that is not a complete action"
        )
      )
    } >&2
    failed=1
  ''}

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
