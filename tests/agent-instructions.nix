/*
  Check interface:

    import ./tests/agent-instructions.nix { inherit pkgs self fixtures; }

  Asserts that the shared agent instructions, two Go templates rendered over
  the host facts and the Synthetic model source, reach every installed
  harness for user `h82` on every host this flake declares. Pi reads the
  shared rendering of instructions.md.tmpl alone; every other harness reads
  it, a blank line, and the `# Pi over ACP` section from acp.md.tmpl:

    Pi                ~/.pi/agent/AGENTS.md, shared rendering only
    Claude Code       ~/.claude/CLAUDE.md, which T3 Code's Claude sessions read
    OpenCode          ~/.config/opencode/AGENTS.md, which every run loads
    Antigravity CLI   ~/.gemini/config/AGENTS.md

  The user list is `userEntries` from `tests/lib/configurations.nix`.

  Verifies, per Home Manager user:
  - exactly one enabled Home Manager file resolves to each delivery path, and
    none to the retired ~/.t3/instructions/claude-code/CLAUDE.md, Codex's
    ~/.codex/AGENTS.md, Gemini's ~/.gemini/GEMINI.md, or the retired
    ~/.grok/rules/instructions.md, none of which is installed. The lookup
    compares each entry's resolved `target` rather than its attribute name,
    and reads `enable`, because either can move the file without changing its
    text.
  - each delivery path exists in the materialized `home-files` and equals its
    expected file byte for byte, and every path passes the per-file rules
    for its copy. See
    .compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md
  - every pinned sentence appears exactly once and starts where a sentence
    starts, so a dropped, doubled, or negated ("Do not ...") rule fails. See
    .compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md
  - every section holds only its pinned sentences, each once and in order,
    so a separate sentence that reverses a pinned rule fails wherever it is
    added.
  - the repository's AGENTS.md holds every pinned review-findings sentence
    where a sentence starts and neither retired three-skill lead, and the
    review finding entry in CONCEPTS.md names the Compound Engineering scope
    and the five reason tags, so neither copy drifts back unseen.
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
  - Pi's copy carries no `# Pi over ACP` heading and none of the ACP
    section's terms (`acpx`, `pi-readonly`, `thought_level`), and every other
    copy carries that heading once, after `# T3 Code`, holding only its
    pinned sentences in order.
  - the expected file is the templates with the known actions replaced:
    `{{ .user.gpgKey }}` by the entry's key, each `{{ .models.<name>.id }}`
    by that entry's `id` in home/h82/agents/synthetic-models.nix, and each
    `{{ index .models.<name>.roles "<role>" }}` by that role's effort there.
    Any other action in the template, such as `range` or `if`, turns the
    check red. The byte comparison stays green across a prose edit of the
    template; the pinned sentences do not.
  - every Pi assignment's `thinking` or `thought_level` is the effort its
    role carries in the model source: the pinned sentences read each one
    from there, so an effort the template writes as a literal, or reads from
    another role, turns this red once the source role moves.
  - every assignment written as "`<model>` on the `<instance>` instance with
    `<knob>` `<value>`" pairs `claudeAgent` with `effort` and `pi` with
    `thinking`, and every one written as "`<model>` on the `<agent>` agent
    with `thought_level` `<value>`" names the `pi` ACP agent. Each gives
    `claude-opus-5-5` only `low` or `medium`, any other Claude model `low`,
    `medium`, or `high`, and a Synthetic model `low`, `high`, or `max`, never
    `medium`, which Synthetic's models do not offer.
    The file must carry at least one such assignment, so a rephrasing that
    the pattern no longer matches turns this red.
  - `t3_thread_wait`, `CROSS_MODEL_HARD_SECS`, `CROSS_MODEL_MODEL_OVERRIDE`,
    `timeoutMs`, `childRunId`, `t3_thread_read`, `runtimeMode`,
    `full-access`, `full access`,
    `approval-required`, `auto-accept-edits`, and `pendingApproval` appear
    only inside `# T3 Code` and `# Compound Engineering`, where every
    sentence is pinned, so a rule elsewhere cannot restore the blocking wait
    for a run with a person present, change when a result is taken from a
    task's session, restore inheritance of the thread's mode, request a
    supervised mode, or change how a paused approval is handled.
  - the file names no removed section, harness, model, or rule, matched
    without regard to case, carries no unescaped tilde outside a code span,
    and carries no template action (`{{`, `}}`, `<no value>`) or unrendered
    `@name@` placeholder.
  - the per-file rules fire: the rendering for the fake key passes them, and
    each mutant in `selfTestMutants` (a removed, a negated, an inverted, and
    an out-of-section rule, for the wait, the launch mode, the rejected-mode
    relaunch, the approval note, and the confined terms; a retired peer rule,
    a removed peer safeguard, a removed, negated, or reworded scout rule,
    a removed, negated, or moved shared-checkout default, worktree trigger, or
    worktree fallback clause, an added worktree rule for every task,
    a removed or negated session_info-first or Pi model-ID fallback rule,
    a review-findings sentence added, reordered, removed, or negated, a Pi
    `thinking` that differs from its source role, an effort or instance the
    assignment rule forbids, a worker sent back to the `opencode` instance,
    each Pi peer candidate at `medium`, each ACP sentence removed or
    negated, a review peer sent to the `pi` agent, an ACP worker at
    `medium`, the ACP `quick` rule collapsed into the `unspecified-low`
    effort or rule, an ACP fallback given another category's effort or
    model, a fallback category dropped, a scout added to the ACP section, the ACP heading dropped, the
    ACP section or an `acpx` rule leaked into Pi's copy, each
    host family's default-peer sentence removed, negated, or swapped to
    another candidate, a default of three peers, and the left-out named peer
    and outside-T3 Synthetic peer rules removed or negated) fails them with its own
    message, so a guard that stops failing turns this red. See
    .compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md

  The sentences, instances, and Claude efforts are written here, not read
  from the module, so a mutation of the instruction file turns this red. Only
  the model IDs and the Synthetic role efforts come from the model source, so a
  changed ID or role reaches the expected file and the pinned sentences
  together.

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
  acpTemplate = builtins.readFile ../home/h82/agents/instructions/acp.md.tmpl;

  # Only the model IDs and each Synthetic role's effort come from the module
  # side, through the source every consumer reads; instances, Claude efforts,
  # and sentences stay written here. A role read here that the source lacks
  # fails evaluation, as the template's strict `index` fails the render.
  models = import ../home/h82/agents/synthetic-models.nix;
  glmId = models.glm.id;
  glmFlashId = models.glmFlash.id;
  kimiId = models.kimi.id;
  deepseekId = models.deepseek.id;
  role = name: role: models.${name}.roles.${role};
  modelNames = [
    "glm"
    "glmFlash"
    "kimi"
    "deepseek"
  ];

  # Pi reads the shared rendering alone; every other harness reads it
  # followed by the ACP section.
  piPath = ".pi/agent/AGENTS.md";
  acpPaths = [
    ".claude/CLAUDE.md"
    ".config/opencode/AGENTS.md"
    ".gemini/config/AGENTS.md"
  ];
  deliveryPaths = [ piPath ] ++ acpPaths;

  actionValues =
    key:
    {
      "{{ .user.gpgKey }}" = key;
      "{{ .models.glm.id }}" = glmId;
      "{{ .models.glmFlash.id }}" = glmFlashId;
      "{{ .models.kimi.id }}" = kimiId;
      "{{ .models.deepseek.id }}" = deepseekId;
    }
    // lib.listToAttrs (
      lib.concatMap (
        name:
        lib.mapAttrsToList (
          roleName: effort: lib.nameValuePair "{{ index .models.${name}.roles \"${roleName}\" }}" effort
        ) (models.${name}.roles or { })
      ) modelNames
    );
  knownActions = lib.attrNames (actionValues fakeKey);

  extractActions =
    text:
    map (
      piece:
      let
        closed = lib.splitString "}}" piece;
      in
      if lib.length closed < 2 then null else "{{${lib.head closed}}}"
    ) (lib.tail (lib.splitString "{{" text));

  templateActions = extractActions template ++ extractActions acpTemplate;
  unknownActions = lib.filter (
    action: action != null && !(lib.elem action knownActions)
  ) templateActions;
  malformedAction = lib.any (action: action == null) templateActions;

  renderExpected =
    key: text:
    let
      values = actionValues key;
    in
    lib.replaceStrings (lib.attrNames values) (lib.attrValues values) text;
  # The module joins the two renderings with one blank line.
  expectedShared =
    key: pkgs.writeText "expected-instructions-shared.md" (renderExpected key template);
  expectedFile =
    key:
    pkgs.writeText "expected-instructions.md" (
      renderExpected key template + "\n" + renderExpected key acpTemplate
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
    "When you run `gh`, `glab`, or another CLI that reads the host and repository from the current Git checkout in a directory whose remotes do not name the target repository, such as a temporary directory or a clone whose `origin` is a local path, pass the host and repository explicitly."
    "Read them from the target project's own checkout, from its `upstream` remote when that points at a server and otherwise from `origin`, never from a default such as `github.com` or `gitlab.com`."
    "Pass `--repo HOST/OWNER/REPO` to a `gh` subcommand that takes `--repo`, and pass `HOST/OWNER/REPO` as the argument of one that takes the repository as an argument, such as `gh repo view`."
    "Give `glab` the repository's full URL instead, through `--repo` or as the argument, because it can read a bare `HOST/OWNER/REPO` as a project on `gitlab.com`."
    "Prefix any other `gh` command, `gh api` included, with `GH_REPO=HOST/OWNER/REPO` and any other `glab` command, `glab api` included, with `GITLAB_REPO` set to the full URL, for that one command and never exported, and also pass `--hostname HOST` to `gh api`, which ignores the host in `GH_REPO`."
    "In the same way, prefix every `glab` command with `GITLAB_HOST=HOST`, because `glab repo clone` and `glab repo delete` send their requests to `gitlab.com` without it, even with a full URL or `GITLAB_REPO`."
    "Write a branch into an API endpoint yourself, because `{branch}` and `:branch` still come from the current checkout."
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
    "Apply every finding that a review, verification, or check step of any Compound Engineering skill reports about the work the workflow produces or changes, such as `ce-code-review`, `ce-simplify-code`, and `ce-doc-review`, in the same change, whatever its severity, confidence, or list, including testing gaps and residual risks."
    "A verdict that chooses among alternatives, such as an adoption grade, a judgment between competing solutions, or a candidate verdict, is not a finding."
    "No skill's own disposition narrows this rule: a dismissal, rejection, low-value skip, deferral, log-and-continue, `Deferred to Planning` question, apply bar, confidence threshold, or list, including `lfg`'s, does not leave a finding unapplied."
    "\"By design\", \"no current instance\", \"low impact\", and \"the fix has a trade-off\" are not reasons to leave a finding, and neither is a rewording of them, such as \"hides nothing visible\", \"mitigated, not removed\", or \"the current configuration never triggers it\"."
    "A fix that reaches outside the diff or the change's scope, such as existing behavior or helpers the change did not touch, is made in the same change."
    "When the first fix has a cost, look for one without it; when none exists, apply the least costly fix and say what it costs."
    "Leave a finding unapplied only in these cases: you verified it is wrong, quoting the evidence; every fix for it would weaken a safety check; the user declined its fix when asked; its fix would reverse a decision the user made and no person is present to ask; or no change in this repository can fix it."
    "List only those findings under an `Unapplied review findings` heading in the pull request body, start each entry with exactly one of the tags `verified wrong`, `weakens a safety check`, `declined by you`, `awaits your decision`, or `no fix in this repository` followed by its evidence or reason, apply a finding whose entry cannot take one of those tags instead of listing it, and omit that section when there are none."
    "A fix that would reverse a decision the user made, a brainstorm Scope Boundary or `session-settled` entry included, is asked in every run with a person present, autonomous runs included, and listed as `awaits your decision` in a run with no person present."
    "When any other fix needs a user decision, such as a product or scope change, ask in an interactive run; in an autonomous run, apply the recommended fix and report it."
    "When the user asked only for a review, report the findings and ask once whether to apply them all."
    "Report what you applied in the pull request body and the final report."
  ];

  # The section is one paragraph, so its mutants edit this one line.
  reviewFindingsLine = lib.concatStringsSep " " reviewFindingsSentences;
  reviewFindingsExceptionSentence = lib.elemAt reviewFindingsSentences 6;
  reviewFindingsTagSentence = lib.elemAt reviewFindingsSentences 7;

  # The repository's own copy of the rule in AGENTS.md carries every pinned
  # sentence, and the glossary entry in CONCEPTS.md carries the scope and the
  # tags, so neither copy can drift back to the narrower rule unseen.
  repoAgentsFile = ../AGENTS.md;
  repoConceptsFile = ../CONCEPTS.md;
  retiredReviewLeads = [
    "Apply every finding that `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` report"
    "This covers every finding from `ce-code-review`, `ce-simplify-code`, and `ce-doc-review`"
  ];
  conceptsReviewFindingPhrases = [
    "**Review finding** — any item a review, verification, or check step of a Compound Engineering workflow reports"
    "verified wrong, weakens a safety check, declined by you, awaits your decision, or no fix in this repository."
  ];
  repoCopyRules = ''
    ${lib.concatMapStrings (sentence: ''
      if ! s=${esc sentence} awk 'index($0, ENVIRON["s"]) == 1 || index($0, ". " ENVIRON["s"]) { found = 1 } END { exit !found }' ${repoAgentsFile}; then
        echo ${esc "AGENTS.md does not hold this review-findings sentence where a sentence starts: ${sentence}"} >&2
        failed=1
      fi
    '') reviewFindingsSentences}
    ${lib.concatMapStrings (term: ''
      if grep -qiF -- ${esc term} ${repoAgentsFile}; then
        echo ${esc "AGENTS.md carries the retired review-findings lead: ${term}"} >&2
        failed=1
      fi
    '') retiredReviewLeads}
    ${lib.concatMapStrings (phrase: ''
      if ! grep -qF -- ${esc phrase} ${repoConceptsFile}; then
        echo ${esc "CONCEPTS.md's review finding entry lacks: ${phrase}"} >&2
        failed=1
      fi
    '') conceptsReviewFindingPhrases}
  '';

  compoundEngineeringHeading = "# Compound Engineering";

  # The self-test below mutates these sentences, so they are named once.
  firstPeerSentence = "When a skill's cross-model step activates, run it with the peers these rules pick from the candidates below, leaving out every candidate whose model family matches yours.";
  claudeCandidateSentence = "The first default candidate is Claude Code, `claude-opus-5-5` on the `claudeAgent` instance with `effort` `medium`, of family `claude`.";
  glmFlashCandidateSentence = "The second default candidate, the GLM Flash candidate, is Pi, `synthetic/${glmFlashId}` on the `pi` instance with `thinking` `${role "glmFlash" "reviewer"}`, of family `glm`.";
  kimiCandidateSentence = "The third default candidate, the Kimi candidate, is Pi, `synthetic/${kimiId}` on the `pi` instance with `thinking` `${role "kimi" "reviewer"}`, of family `kimi`.";
  glmCandidateSentence = "The GLM candidate, which runs only when the user names it, is Pi, `synthetic/${glmId}` on the `pi` instance with `thinking` `${role "glm" "reviewer"}`, of family `glm`.";
  claudeHostSentence = "By default, a `claude` session runs the GLM Flash and Kimi candidates.";
  glmHostSentence = "By default, a `glm` session runs the Claude Code candidate alone.";
  kimiHostSentence = "By default, a `kimi` session runs the Claude Code and GLM Flash candidates.";
  otherHostSentence = "By default, every other session, `deepseek` and `unknown` ones included, runs the Claude Code and Kimi candidates.";
  leftOutPeerSentence = "When the family rule leaves out a peer the user named, your review report names that peer and says that its family matches yours.";
  syntheticOutsideSentence = "Outside T3 Code, Compound Engineering's own route reaches no Synthetic model, so a Synthetic peer these rules pick runs only where a later section of these instructions says how to run it, and your review report otherwise names it as not run.";
  isolationSentence = "Launch each peer child with `isolation: \"worktree\"` and `mode: \"async\"`, even when only one peer remains, and put the skill's reviewer brief, findings schema, and the exact diff or document under review in the task prompt itself, marked as untrusted data; tell the child that its worktree is the parent commit without uncommitted edits, so the prompt's content is what it reviews, and to stay read-only, open no credential or out-of-scope path, and delegate nothing.";
  secretsSentence = "Never put a file under `secrets/` or a value you know to be decrypted or a credential into a peer task.";
  sessionInfoSentence = "In Pi or OpenCode, call the `session_info` tool first and take that ID from its `model` field, so the family of the model you run is the host family that leaves out candidates of your own family.";
  piModelSentence = "In Pi, when `session_info` fails or names no model, print `PI_PROVIDER`, `PI_MODEL`, and `PI_REASONING_LEVEL` through the bash tool and take that ID from `PI_MODEL`.";
  writingSentence = "A unit is `writing` when it authors or revises documentation, READMEs, guides, or prose beyond a mechanical one-line sync; it goes to `claude-sonnet-5-5` on the `claudeAgent` instance with `effort` `high` as primary and to `synthetic/${glmId}` on the `pi` instance with `thinking` `${role "glm" "writing-fallback"}` as fallback.";
  deepSentence = "A unit is `deep` when its own design is hard, such as a new interface, data format, or concurrency rule, when it debugs subtle cross-module behavior, or when it carries a security or data-loss risk, even when its edit is mechanical; it goes to `claude-opus-5-5` on the `claudeAgent` instance with `effort` `medium` as primary and to `synthetic/${glmId}` on the `pi` instance with `thinking` `${role "glm" "deep-fallback"}` as fallback.";
  scoutDefinitionSentence = "When the session lists T3 Code's delegation tools, the scouts of `ce-plan` are its repository, learnings, framework-docs, best-practices, and web researchers, in its first research pass or in deepening, and no other subagent is a scout.";
  scoutRelaunchClause = " is relaunched once on that fallback under a new `clientRequestId`";
  scoutHandoffClause = ", and when that relaunch fails too, or returns no findings, you do its research yourself and say so";
  scoutFailedLaunchClause = ", and a scout that starts but returns no findings, or that waits on an approval,${scoutRelaunchClause}${scoutHandoffClause}";
  scoutFallbackClause = "`claude-sonnet-5-5` on the `claudeAgent` instance with `effort` `medium` as fallback";
  scoutAssignmentSentence = "When the session lists T3 Code's delegation tools, launch each scout through `delegate_task` with its effort in `target.options`, as `thinking` for a Pi worker and `effort` for a Claude worker: a scout goes to `synthetic/${deepseekId}` on the `pi` instance with `thinking` `${role "deepseek" "scout"}` as primary and to ${scoutFallbackClause}${scoutFailedLaunchClause}.";
  scoutUntrackedClause = ", and an untracked file only when the task prompt names it";
  scoutSafeguardSentence = "When the session lists T3 Code's delegation tools, tell each scout to open no credential, nothing under `secrets/`, no gitignored file${scoutUntrackedClause}, and before launching, name each scout and the provider that gets its prompt, Synthetic for Pi and Anthropic for Claude Code; that notice authorizes the send.";

  # In section order, like `reviewFindingsSentences`.
  compoundEngineeringSentences = [
    firstPeerSentence
    "This covers `ce-code-review`, `ce-doc-review`, the `ce-pov` oracle panel, and `ce-bakeoff` judging, and each skill's own gates still decide whether the step runs."
    claudeCandidateSentence
    glmFlashCandidateSentence
    kimiCandidateSentence
    glmCandidateSentence
    "Map a model ID to its family after removing one leading provider prefix such as `synthetic/`: `claude-*` to `claude`, `gemini-*` to `gemini`, an `hf:<org>/<name>` ID by its org, with `zai-org` to `glm`, `moonshotai` to `kimi`, `deepseek-ai` to `deepseek`, and `Qwen` to `qwen`, and a `syn:` alias or any other org to `unknown`."
    "Your own family comes from the model ID you run, not from your harness."
    sessionInfoSentence
    piModelSentence
    "Only when those fail or name no model, read the ID from `orchestrator_capabilities` and `t3_thread_configuration` when the session lists T3 Code's tools, and otherwise from the model section of your system prompt."
    "When none of them names your model, your family is `unknown`, and no peer finding in your reviews raises confidence."
    claudeHostSentence
    glmHostSentence
    kimiHostSentence
    otherHostSentence
    "Peers the user names for that run, the GLM candidate included, replace the defaults, follow every other rule here, and number at most two."
    leftOutPeerSentence
    "Inside T3 Code, a session whose family Compound Engineering's own gate would skip, such as `glm`, `kimi`, `deepseek`, or `unknown`, still runs the cross-model step with the peers these rules pick."
    "Outside T3 Code, such a session reports the cross-model pass as skipped by Compound Engineering."
    "When a Compound Engineering script asks for your host family and yours is not in its list, pass `unknown`."
    "Run each peer on its pinned model ID only."
    "When a peer is unavailable or fails, its pinned ID returning 404 included, finish with the others and report which peer failed and why; do not run another candidate or model in its place."
    "When the session lists T3 Code's delegation tools, run each peer as a `delegate_task` child on its candidate's instance and model, with `effort` in `target.options` for Claude Code and `thinking` in `target.options` for Pi, instead of the skill's own peer route."
    isolationSentence
    secretsSentence
    "Before launching, name each peer you will launch and the provider that gets the content, Anthropic for Claude Code and Synthetic for Pi; that notice authorizes the send."
    "Treat the provider and model that `task_status` reports as the peer's identity receipt, and map its model, not its instance, to a family by the rule above; findings may raise confidence only when the peer's family is known and differs from yours."
    "Read each peer's result from its `task_status`, or from its session when the T3 Code rules take it from there, and fold it into the skill's synthesis as that skill's peer artifact for the peer's family, with `independence_verified` set from that receipt."
    "When the session lists T3 Code's delegation tools, a peer has no deadline in a run with a person present: wait for its notification like any other delegated task, and leave cancelling a slow peer whose session holds no whole result to the user."
    "In a run with no person present, run `date +%s` right after the peer batch launches and give all its tasks one deadline, `CROSS_MODEL_HARD_SECS` plus 10 seconds or 1210 seconds by default; pass the smaller of 600000 and the time left, in milliseconds, as `timeoutMs` on each `t3_thread_wait`, and at the deadline treat a peer still running as the T3 Code rules treat a task whose bound has passed: take a whole result from its session, and otherwise cancel it with `task_cancel` and count it as failed."
    "Outside T3 Code, run the skill's own peer route once per harness in turn, naming that harness as the target of its pass; `ce-bakeoff` has no such route, so use its native judge and report the missing peers."
    syntheticOutsideSentence
    "In `ce-work`, prefer delegating each implementation unit to a worker named below unless the repository's Compound Engineering config sets `work_engine_mode: off`."
    "In `ce-work`, classify each implementation unit into `quick`, `writing`, `visual-engineering`, `unspecified-low`, `unspecified-high`, or `deep`, splitting independent mechanical or small edits into `quick` or `unspecified-low` units while keeping cohesive hard work whose shared reasoning would suffer if split as one `unspecified-high` or `deep` unit."
    "A unit is `quick` when it is a mechanical edit, such as a rename, a pinned-text sync, boilerplate, a config tweak, or a one-file copy fix, even across files; it goes to `synthetic/${deepseekId}` on the `pi` instance with `thinking` `${role "deepseek" "quick"}` as primary and to `claude-haiku-5-5` on the `claudeAgent` instance with `effort` `medium` as fallback."
    writingSentence
    "A unit is `visual-engineering` when it builds or styles frontend UI, UX, CSS, layouts, animation, or design-system components; it goes to `claude-sonnet-5-5` on the `claudeAgent` instance with `effort` `high` as primary and to `synthetic/${kimiId}` on the `pi` instance with `thinking` `${role "kimi" "visual-engineering-fallback"}` as fallback."
    deepSentence
    "A unit is `unspecified-high` when it changes several modules across known patterns; it goes to `claude-sonnet-5-5` on the `claudeAgent` instance with `effort` `high` as primary and to `synthetic/${glmId}` on the `pi` instance with `thinking` `${role "glm" "unspecified-high-fallback"}` as fallback."
    "Every other unit is `unspecified-low`, which goes to `synthetic/${deepseekId}` on the `pi` instance with `thinking` `${role "deepseek" "unspecified-low"}` as primary and to `claude-sonnet-5-5` on the `claudeAgent` instance with `effort` `medium` as fallback."
    "These per-category efforts apply inside T3 Code, where every task carries its own effort."
    "Inside T3 Code, launch each unit on its category's primary worker first, and when that worker is unavailable or its launch fails, give the unit to its category's fallback worker with that worker's own effort rule."
    "When the session lists T3 Code's delegation tools, launch each unit through `delegate_task` with the worker's instance and model id as `target` and its effort in `target.options`, as `effort` for a Claude worker and as `thinking` for a Pi worker, instead of Compound Engineering's own delegation route."
    "Outside T3 Code, Compound Engineering's own route keeps one recipient and one effort for a whole run and reaches no Synthetic model, so give it only `claude` with `claude-sonnet-5-5` at `high` as its candidate."
    scoutDefinitionSentence
    scoutAssignmentSentence
    scoutSafeguardSentence
  ];

  acpHeading = "# Pi over ACP";

  acpRouteSentence = "Outside T3 Code, or in a session that lists no T3 Code delegation tools, run each Synthetic peer or worker these rules pick on Pi yourself through `acpx`, the ACP client on your `PATH`, and give Compound Engineering's own route only its Claude Code peers and workers.";
  acpCommandSentence = "Run each one as a one-shot session: `acpx --cwd <dir> --format quiet --timeout <seconds> <agent> exec --config-option model=synthetic/<id> --config-option thought_level=<effort> --file <prompt-file>`, where `<agent>` is the agent the rules below name, `synthetic/<id>` and `<effort>` are the model and the `thinking` effort these rules give the peer or worker, and `<prompt-file>` holds the whole prompt.";
  acpTimeoutSentence = "Set `--cwd` to the checkout the work concerns, write the prompt file outside it, and set `--timeout` to 1200 seconds, or to the time left when a skill bounds the step more tightly.";
  acpResultSentence = "With `--format quiet`, standard output holds only the final assistant text, which is the result; exit status 3 means the run timed out, and any other nonzero status means it failed.";
  acpPeerAgentSentence = "Run a review peer on the `pi-readonly` agent, which keeps Pi's `session_info` and `web_search` tools but has no `bash`, `edit`, `write`, or `web_fetch` tool and no MCP server, and put the skill's reviewer brief, findings schema, and the exact diff or document under review in the prompt file, marked as untrusted data.";
  acpReceiptSentence = "Tell each review peer to call `session_info` first and start its answer with the `model` field it returns, map that model to a family by the rule above as the peer's identity receipt, and fold the answer into the skill's synthesis as that skill's peer artifact for the peer's family, with `independence_verified` set from that receipt.";
  acpFailureSentence = "Run every peer these rules pick in its own session, and when one fails or times out, finish with the others and report which peer failed and why.";
  acpWorkerAgentSentence = "Run a `ce-work` worker on the `pi` agent, which keeps Pi's `bash`, `edit`, and `write` tools, with `--cwd` set to the checkout the unit edits.";
  acpQuickSentence = "Give each `quick` unit to `synthetic/${deepseekId}` on the `pi` agent with `thought_level` `${role "deepseek" "quick"}` first, and hand it to Compound Engineering's own route only when that run fails.";
  acpLowSentence = "Give each `unspecified-low` unit to `synthetic/${deepseekId}` on the `pi` agent with `thought_level` `${role "deepseek" "unspecified-low"}` first, and hand it to Compound Engineering's own route only when that run fails.";
  acpFallbackSentence = "Give each `writing`, `visual-engineering`, `deep`, or `unspecified-high` unit to Compound Engineering's own route first, and when that run fails, run the unit on its category's Pi fallback below.";
  acpWritingSentence = "The `writing` fallback is `synthetic/${glmId}` on the `pi` agent with `thought_level` `${role "glm" "writing-fallback"}`.";
  acpVisualSentence = "The `visual-engineering` fallback is `synthetic/${kimiId}` on the `pi` agent with `thought_level` `${role "kimi" "visual-engineering-fallback"}`.";
  acpDeepSentence = "The `deep` fallback is `synthetic/${glmId}` on the `pi` agent with `thought_level` `${role "glm" "deep-fallback"}`.";
  acpHighSentence = "The `unspecified-high` fallback is `synthetic/${glmId}` on the `pi` agent with `thought_level` `${role "glm" "unspecified-high-fallback"}`.";

  # In section order. The section names no scout: scouts run only as T3 Code
  # delegated tasks.
  acpSentences = [
    acpRouteSentence
    acpCommandSentence
    acpTimeoutSentence
    acpResultSentence
    acpPeerAgentSentence
    acpReceiptSentence
    acpFailureSentence
    acpWorkerAgentSentence
    acpQuickSentence
    acpLowSentence
    acpFallbackSentence
    acpWritingSentence
    acpVisualSentence
    acpDeepSentence
    acpHighSentence
  ];

  # Text only the ACP section carries, matched without regard to case, which
  # Pi's copy must not hold: it tells an agent how to start Pi.
  acpOnlyTerms = [
    "Pi over ACP"
    "acpx"
    "pi-readonly"
    "thought_level"
  ];

  t3CodeHeading = "# T3 Code";

  # The self-test below mutates these sentences, so they are named once.
  takeFromSessionSentence = "Otherwise, when the latest assistant message is finished, holds the whole result the task prompt asked for, and nothing in the session has changed since your previous check of it, use the message as the task's result, stop the task with `task_cancel`, and say that you took its result from the session.";
  prohibitionSentence = "In a run with a person present, never wait for a delegated task with `t3_thread_wait`; in any run, never call `task_status` in a loop, and never start a sleep, timer, or background command whose only purpose is to wake yourself later.";
  allowedWaitsSentence = "A delay a test must reproduce, a retry interval, a wait the user asked for, and a wait that blocks on the task's own run stay allowed.";
  fullAccessSentence = "Launch every delegated task, cross-model peers and implementation units included, with `runtimeMode: \"full-access\"`, even though `delegate_task`'s own description says to leave it unset, so the task never pauses on an approval nobody sees.";
  rejectionSentence = "When `delegate_task` rejects that launch with an error about the requested runtime mode, such as one saying the target provider does not offer it or that it ranks above your thread's mode, relaunch the task once without `runtimeMode`, so it inherits your thread's mode, under a new `clientRequestId`; that rejection itself is not a failed or unavailable launch under any rule in these instructions, including the launch-failure retry below, a category's fallback worker, and a failed cross-model peer, but a failure of the relaunch is one.";
  noteSentence = "When you end your turn while tasks still run, name them, and when one of them runs without `runtimeMode: \"full-access\"`, also say that such a task can pause on an approval, which shows \"Subagent needs approval\" in its thread and waits for the user, because T3 Code sends no notification for it.";
  oldNoteSentence = "When you end your turn while tasks still run, name them, and say that a task paused on an approval shows \"Subagent needs approval\" in its thread and waits for the user, because T3 Code sends no notification for it.";
  worktreeFallbackRewriteCase = " or must rewrite files beyond its own";
  worktreeFallbackClause = "; a worktree launch of a task other than a cross-model peer that still fails after that relaunch is skipped and reported with the reason when the task needed the committed state${worktreeFallbackRewriteCase}, and runs in your checkout once every other task there has finished only when it got its worktree for parallel edits of one file";
  launchFailureSentence = "When a `delegate_task` launch fails, relaunch it once with the same `clientRequestId`; when that fails too, take the next fallback these instructions name, such as a category's fallback worker, and when none is left, do the work yourself instead of using your harness's own subagent tool, unless these instructions forbid it, as they do for a cross-model peer${worktreeFallbackClause}.";
  sharedCheckoutDefaultPeerClause = "; a cross-model peer is the one task that always gets a worktree, as the peer rule above says";
  sharedCheckoutDefaultSentence = "Launch every delegated task other than a cross-model peer in the checkout you work in, with no `isolation` argument, and give a task its own worktree only in the three cases below${sharedCheckoutDefaultPeerClause}.";
  parallelEditsSentence = "Never run two tasks that edit the same files in one checkout at the same time: from a clean checkout, launch each with `isolation: \"worktree\"`, tell each to commit its edits and report its branch, and merge those branches back one at a time; otherwise launch them one after another.";
  rewriteTriggerExamples = "a formatter, a code generator, a dependency update, a branch switch, or a mutation test run inside the checkout";
  rewriteTriggerSentence = "Launch a task with `isolation: \"worktree\"` when it runs a command that rewrites files beyond the task's own, such as ${rewriteTriggerExamples}, tell it to commit its edits and report its branch, and merge that branch back once it has finished.";
  committedStateTriggerSentence = "Launch a task with `isolation: \"worktree\"` when it needs the committed state while your checkout holds uncommitted edits it must not see, such as a baseline build or a test run against the last commit.";
  sharedCheckoutLeaveClause = ", and, while another task edits there, to leave formatting, builds, and checks to you";
  sharedCheckoutSentence = "Tell tasks that share one checkout not to commit, stage, or format files beyond their own${sharedCheckoutLeaveClause}; commit their results yourself.";

  t3CodeSentences = [
    "When the session lists T3 Code's delegation tools, such as `delegate_task`, launch every subagent through `delegate_task`, including the scouts, verifiers, reviewers, and workers a skill dispatches, and never use your harness's own subagent or multi-agent tools, even where T3 Code's own guidance prefers them for same-provider work."
    "When the session lists no T3 Code delegation tools, use your harness's own subagent tool."
    "The delegation rules that follow apply only when the session lists those tools."
    "When no skill or rule names a model for a subagent, launch it on your own provider instance with the model from that instance's list in `orchestrator_capabilities` that you judge fits the tier the skill names, or with your own model when the skill names no tier or no listed model fits it, and when `orchestrator_capabilities` marks a default `effort` for that model, set `effort` in `target.options` to it, even for your own model."
    "A delegated subagent sees none of your conversation and none of the tool limits its native agent type had, so put everything it needs in its task prompt, including that it stays read-only when it only searches, reads, or reviews."
    "Tell each delegated subagent to launch no subagents of its own, so delegation stays one level deep."
    fullAccessSentence
    rejectionSentence
    launchFailureSentence
    "Before you edit a file that a still-running task also edits, in this checkout or in a worktree you will merge back, wait until that task has finished and its edits are merged."
    "Launch every delegated task that does not need another task's result in the same response, each with `delegate_task` in its default `async` mode, instead of launching one, waiting for it, and then launching the next."
    "Never use `mode: \"wait\"`, even for a single task, because it holds your turn until the task finishes."
    sharedCheckoutDefaultSentence
    parallelEditsSentence
    rewriteTriggerSentence
    committedStateTriggerSentence
    sharedCheckoutSentence
    "Give each delegated task its own `clientRequestId`, and reuse it when you retry that launch, except for the relaunch without `runtimeMode` after a rejected runtime mode, which takes a new one."
    "Launch a task that needs an earlier task's result only after you have read that result."
    "In a run with a person present, after launching, do the work that does not need the delegated results, and when only those results remain, end your turn so the user can talk to you while the tasks run."
    noteSentence
    "Each notification T3 Code delivers, whether it starts your turn or arrives with a user message, names the tasks that reached a terminal state or have a question; read each finished task's result with one `task_status` call."
    "While another task the waiting step needs is still running, end your turn again without cancelling it, and continue that step once every result it needs has arrived through a notification or from the task's session."
    "When a notification says a delegated task has a question, read it with `t3_pending_request_read`, then answer it with `t3_pending_request_respond` or ask the user, and end your turn again."
    "When the user writes while delegated tasks are running, send any answer they give to a pending question to its task with `t3_pending_request_respond`, answer the rest, keep the tasks and the waiting step, and end your turn again unless they redirect the work."
    "On every turn you get while a task the waiting step needs has not reached a terminal state and you have not taken its result, whether a notification, a user message, a background wait, or a `t3_thread_wait` timeout started it, read its `task_status` once, then read its session with `t3_thread_read` on its `childThreadId` in the `activity` view, paging with `afterPosition` until no `nextPosition` remains, and read its latest assistant message by `itemId`, repeating with `textOffset` set to `nextTextOffset` until `nextTextOffset` is null, because a task can write its result and never finish."
    "When that `task_status` is terminal, use its result as usual; when it shows a pending question or `hasPendingChildRuns` true, keep waiting."
    takeFromSessionSentence
    "When `task_cancel` leaves that task running, keep the result, tell the user once that it still runs so they can stop it, and count its result as taken."
    prohibitionSentence
    allowedWaitsSentence
    "Ending your turn to wait for a delegated task is allowed even where a skill says not to end the turn or to fail when no blocking wait exists, such as `lfg`'s rule not to end the turn before `<promise>DONE</promise>` or `ce-code-review`'s reviewer collection; when the results arrive, continue the same run from the step that waited."
    "For such a skill, a completion notification and one `task_status` read, or a result taken from the task's session, are the task's terminal outcome, and a task the skill bounds by time counts as failed when you resume after that bound has passed and its session holds no whole result."
    "In a run with no person present, such as a headless, scheduled, or pipeline run, wait inside the turn instead: once every task is launched, call `t3_thread_wait` on each task's `childThreadId` with its `childRunId` as `runId` and, as `timeoutMs`, the smaller of 600000 and the time left before any bound on that task, then read each result with one `task_status` call; when no time is left before that bound, skip the wait and apply the bound rule below."
    "When that wait returns `timedOut: true`, answer a pending question with `t3_pending_request_respond` from the task and your instructions, check the task as above, and wait again with the same `runId` unless you took its result or its bound has passed."
    "In a run with no person present, when a task's `task_status` shows `pendingApproval`, nobody can approve it, so cancel it with `task_cancel` and count it as failed."
    "When a skill bounds a delegated task by time and the bound passes while it still runs, check it as above, and when its latest finished assistant message holds the whole result, take it as above even if the session changed since your previous check; otherwise cancel it with `task_cancel` and count it as failed."
    "When `task_status` shows `workState` `working` or `hasPendingChildRuns` true, call `t3_thread_wait` on that thread again without `runId` and with `timeoutMs` as above; when `childRunId` is null, or the task shows `waiting_for_children` with `hasPendingChildRuns` false, there is no run to block on, so check it as above, take a finished message that holds the whole result, count the task failed only when the bound has already passed at that check and the session holds no whole result, and otherwise end your turn with no timer and no further check, and name the tasks when a person is present."
    "When the session lists T3 Code's pull request tools, such as `watch_pull_request`, use them to watch a request you babysit instead of your own background wait."
    "When the session lists T3 Code's preview tools, such as `preview_open`, show any local HTML file you open for the user in a T3 Code browser tab instead of running `xdg-open` or `open`: run `serve-html <file>`, open a new tab with `preview_open` and `reuseExistingTab` set to false so the user's own tab stays as it is, then call `preview_navigate` with that tab's `tabId` and the line `serve-html` printed as `target`."
    "Pass `--root <dir>` to `serve-html` when the page loads sibling files from a report directory."
    "When the user asks to see a page again, or says its tab no longer loads, run `serve-html` again instead of reusing an earlier target, and navigate the same tab to the new target."
    "A run with no person present, such as a headless or pipeline run, still opens nothing."
    "When the session lists no T3 Code preview tools, or `serve-html`, `preview_open`, or `preview_navigate` fails, keep the skill's own way of opening the file and print the file's absolute path."
  ];

  # A separate contradicting sentence could defeat a pinned rule in any
  # section, so every section gets the allowlist, membership, and order checks.
  checkedSections = key: [
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
      sentences = compoundEngineeringSentences;
    }
    {
      name = "T3 Code";
      heading = t3CodeHeading;
      sentences = t3CodeSentences;
    }
  ];

  acpSection = {
    name = "Pi over ACP";
    heading = acpHeading;
    sentences = acpSentences;
  };

  pinnedSentences = [
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
  ++ compoundEngineeringSentences
  ++ [ t3CodeHeading ]
  ++ t3CodeSentences;

  acpPinnedSentences = [ acpHeading ] ++ acpSentences;

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
  # only to a run with no person present, of the retired OpenCode pass's
  # pinned model outside T3 Code, of the session check that takes
  # a stalled task's result, and of the launch mode and approvals. They may appear only
  # inside the checked `# T3 Code` and `# Compound Engineering` sections,
  # where every sentence is pinned, so a rule added elsewhere cannot bring the
  # blocking wait back for a run with a person present, change when a session
  # result is taken, restore inheritance of the thread's mode, or request a
  # supervised mode.
  confinedTerms = [
    "t3_thread_wait"
    "CROSS_MODEL_HARD_SECS"
    "CROSS_MODEL_MODEL_OVERRIDE"
    "timeoutMs"
    "childRunId"
    "t3_thread_read"
    "runtimeMode"
    "full-access"
    "full access"
    "approval-required"
    "auto-accept-edits"
    "pendingApproval"
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
    "flash-medium"
    "flash-lite"
    "flash-free"
    "gemini-4-argon-high"
    "gemini-4-argon-low"
    "gemini-4-argon-medium"
    "gemini-3.8-flash-low"
    "gemini-3.8-flash-high"
    "Pick the model by harness"
    "another harness"
    "Codex"
    "Zen"
    "Model routing"
    "receives the reviewed content"
    "data terms"
    "leaves out Antigravity"
    "for that pass only"
    "never with OpenCode"
    "Grok"
    "gemini-4-argon"
    "gemini-3.8-flash"
    "thinking level"
    "`max` for `deep`"
    "CROSS_MODEL_EFFORT_OVERRIDE"
    "Apply every finding that `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` report"
    "OpenCode pass"
    "OpenCode's family"
    "Synthetic for OpenCode"
    "`opencode` instance"
    "CROSS_MODEL_MODEL_OVERRIDE"
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

  # The pinned sentences, checked sections, top-level headings, and
  # forbidden terms of one entry's rendering: the full copy every harness but
  # Pi reads, and Pi's shared-only copy.
  rulesFor = key: {
    pinned = pinnedSentences ++ acpPinnedSentences;
    sections = checkedSections key ++ [ acpSection ];
    headings = topLevelHeadings ++ [ acpHeading ];
    forbidden = [ ];
  };
  piRulesFor = key: {
    pinned = pinnedSentences;
    sections = checkedSections key;
    headings = topLevelHeadings;
    forbidden = acpOnlyTerms;
  };

  # Fails the build, naming each assignment, when a model is put on an
  # instance or ACP agent with a knob or effort it must not take. Synthetic's
  # models offer no `medium`, and `claude-opus-5-5` stays at `medium` or
  # lower. Finding no assignment fails too, so a rewording the pattern misses
  # cannot pass.
  assignmentRules = label: ''
    assignments=0
    while IFS=$'\t' read -r model instance kind knob value; do
      assignments=$((assignments + 1))
      case "$kind:$instance:$knob:$model:$value" in
        instance:claudeAgent:effort:claude-opus-5-5:low | instance:claudeAgent:effort:claude-opus-5-5:medium) ;;
        instance:claudeAgent:effort:claude-opus-5-5:*)
          echo ${esc "${label} runs claude-opus-5-5 above effort medium:"} "$value" >&2
          failed=1
          ;;
        instance:claudeAgent:effort:claude-*:low | instance:claudeAgent:effort:claude-*:medium | instance:claudeAgent:effort:claude-*:high) ;;
        instance:pi:thinking:synthetic/*:low | instance:pi:thinking:synthetic/*:high | instance:pi:thinking:synthetic/*:max) ;;
        agent:pi:thought_level:synthetic/*:low | agent:pi:thought_level:synthetic/*:high | agent:pi:thought_level:synthetic/*:max) ;;
        *)
          echo ${esc "${label} assigns a model an instance, knob, or effort it does not take:"} "$model on $instance with $knob $value" >&2
          failed=1
          ;;
      esac
    done < <(
      grep -oE -- '`[^`]+` on the `[^`]+` (instance|agent) with `[^`]+` `[^`]+`' "$file" \
        | sed -E 's/^`([^`]+)` on the `([^`]+)` (instance|agent) with `([^`]+)` `([^`]+)`$/\1\t\2\t\3\t\4\t\5/' \
        || true
    )
    if [ "$assignments" = "0" ]; then
      echo ${esc "${label} carries no model assignment the effort rules can read"} >&2
      failed=1
    fi
  '';

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
      printf '%s\n' ${lib.escapeShellArgs rules.headings} > "$expected"
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
      for term in ${lib.escapeShellArgs rules.forbidden}; do
        if grep -qiF -- "$term" "$file"; then
          echo ${esc "${label} carries text of the ACP section, which Pi's copy must not hold:"} "$term" >&2
          failed=1
        fi
      done
      for term in ${lib.escapeShellArgs removedTerms}; do
        if grep -qiF -- "$term" "$file"; then
          echo ${esc "${label} names something the instructions no longer carry:"} "$term" >&2
          failed=1
        fi
      done
      ${assignmentRules label}
      outside=$(mktemp)
      t=${esc t3CodeHeading} c=${esc compoundEngineeringHeading} awk '
        BEGIN { t = ENVIRON["t"]; c = ENVIRON["c"] }
        /^# / { inside = ($0 == t || $0 == c) }
        !inside { print }
      ' "$file" > "$outside"
      for term in ${lib.escapeShellArgs confinedTerms}; do
        if grep -qiF -- "$term" "$outside"; then
          echo ${esc "${label} names a delegation term outside the T3 Code and Compound Engineering sections:"} "$term" >&2
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
    ".grok/rules/instructions.md"
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
      ${
        let
          isPi = target: target == piPath;
        in
        lib.concatMapStrings (
          target:
          let
            expected = if isPi target then expectedShared key else expectedFile key;
            rules = if isPi target then piRulesFor key else rulesFor key;
          in
          ''
            file=${homeFiles}/${target}
            if [ ! -s "$file" ]; then
              echo ${esc "~/${target} on ${label} is missing or empty in home-files"} >&2
              failed=1
            else
              if ! cmp -s "$file" ${expected}; then
                echo ${esc "the instructions at ~/${target} on ${label} are not the template with the known actions replaced:"} >&2
                diff ${expected} "$file" >&2 || true
                failed=1
              fi
              ${fileRules "the instructions at ~/${target} on ${label}" key (lib.optional fake cardKey) rules}
            fi
          ''
        ) deliveryPaths
      }

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

  # Each mutant is the rendering for the fake key with one edit
  # that `fileRules` must reject, and the message that rejection must print.
  # The edit is a shell filter from the original on stdin to the mutant on
  # stdout, and it reads its line from the environment, like the rules do.
  # Replaces `from` with `to` in the line equal to `line`.
  replaceInLine =
    from: to:
    ''from=${esc from} to=${esc to} awk '$0 == ENVIRON["line"] { i = index($0, ENVIRON["from"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["to"] substr($0, i + length(ENVIRON["from"])) } { print }' '';
  ceLineAdded = ''awk '{ print } $0 == "# Compound Engineering" { print ENVIRON["line"] }' '';
  lineRemoved = ''awk '$0 != ENVIRON["line"]' '';
  lineNegated = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';

  # Each Pi peer candidate at `thinking` `medium`, which no Synthetic model
  # offers.
  candidateAtMedium = name: id: sentence: {
    name = "${name} candidate lowered to medium";
    line = "- ${sentence}";
    edit = replaceInLine "`thinking` `${role id "reviewer"}`" "`thinking` `medium`";
    expect = "assigns a model an instance, knob, or effort it does not take: synthetic/${models.${id}.id} on pi with thinking medium";
  };

  # Each sentence removed, then negated, must fail the check on its own.
  removedAndNegatedIn = section: name: sentence: [
    {
      name = "${name} removed";
      line = "- ${sentence}";
      edit = lineRemoved;
      expect = "moves a ${section} sentence out of its section: ${sentence}";
    }
    {
      name = "${name} negated";
      line = "- ${sentence}";
      edit = lineNegated;
      expect = "does not hold this sentence exactly once, where a sentence starts: ${sentence}";
    }
  ];
  removedAndNegated = removedAndNegatedIn "Compound Engineering";

  # A mutant runs on the full rendering unless it names Pi's copy.
  selfTestMutants = [
    {
      name = "OpenCode peer refusal reinserted";
      line = "- ${firstPeerSentence}";
      edit = replaceInLine "matches yours." "matches yours, and never with OpenCode.";
      expect = "names something the instructions no longer carry: never with OpenCode";
    }
    {
      name = "Antigravity worker sentence added";
      line = "- Give `writing` units to `gemini-5-pro` on the `antigravity` instance with `effort` `low`.";
      edit = ceLineAdded;
      expect = "assigns a model an instance, knob, or effort it does not take: gemini-5-pro on antigravity with effort low";
    }
    {
      name = "secrets sentence removed";
      line = "- ${secretsSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "peer isolation sentence removed";
      line = "- ${isolationSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "deep worker raised to claude-opus-5-5 max";
      line = "- ${deepSentence}";
      edit = replaceInLine "`effort` `medium` as primary" "`effort` `max` as primary";
      expect = "runs claude-opus-5-5 above effort medium: max";
    }
    {
      name = "Claude Code candidate raised to xhigh";
      line = "- ${claudeCandidateSentence}";
      edit = replaceInLine "`effort` `medium`" "`effort` `xhigh`";
      expect = "runs claude-opus-5-5 above effort medium: xhigh";
    }
    (candidateAtMedium "GLM Flash" "glmFlash" glmFlashCandidateSentence)
    (candidateAtMedium "Kimi" "kimi" kimiCandidateSentence)
    (candidateAtMedium "GLM" "glm" glmCandidateSentence)
    {
      name = "claude host sentence rewritten to run the GLM candidate";
      line = "- ${claudeHostSentence}";
      edit = replaceInLine "the GLM Flash and Kimi candidates" "the GLM and Kimi candidates";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${claudeHostSentence}";
    }
    {
      name = "kimi host sentence rewritten to run the Kimi candidate";
      line = "- ${kimiHostSentence}";
      edit = replaceInLine "the Claude Code and GLM Flash candidates" "the Claude Code and Kimi candidates";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${kimiHostSentence}";
    }
    {
      name = "every host given three default peers";
      line = "- By default, every session runs all three default candidates.";
      edit = ceLineAdded;
      expect = "carries an unpinned Compound Engineering sentence: By default, every session runs all three default candidates.";
    }
    {
      name = "CROSS_MODEL_MODEL_OVERRIDE rule added under # Git";
      line = "- Set `CROSS_MODEL_MODEL_OVERRIDE` to the GLM candidate before you push.";
      edit = ''awk '{ print } $0 == "# Git" { print ENVIRON["line"] }' '';
      expect = "names a delegation term outside the T3 Code and Compound Engineering sections: CROSS_MODEL_MODEL_OVERRIDE";
    }
    {
      name = "GLM writing fallback rendered at another effort than its source role";
      line = "- ${writingSentence}";
      edit = replaceInLine "`thinking` `${role "glm" "writing-fallback"}`" "`thinking` `${
        if role "glm" "writing-fallback" == "max" then "high" else "max"
      }`";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "session_info-first sentence negated";
      line = "- ${sessionInfoSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "take-from-session sentence removed";
      line = "- ${takeFromSessionSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "t3_thread_read rule added under # Git";
      line = "- Read a task with `t3_thread_read` before you push.";
      edit = ''awk '{ print } $0 == "# Git" { print ENVIRON["line"] }' '';
      expect = "names a delegation term outside the T3 Code and Compound Engineering sections: t3_thread_read";
    }
    {
      name = "full-access launch sentence removed";
      line = "- ${fullAccessSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "full-access launch sentence negated";
      line = "- ${fullAccessSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "runtimeMode rule added under # Git";
      line = "- Launch every review task with `runtimeMode: \"approval-required\"`.";
      edit = ''awk '{ print } $0 == "# Git" { print ENVIRON["line"] }' '';
      expect = "names a delegation term outside the T3 Code and Compound Engineering sections: runtimeMode";
    }
    {
      name = "rejection sentence inverted";
      line = "- ${rejectionSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { sub(/ is not a failed/, " is a failed") } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "approval note made unconditional again";
      line = "- ${noteSentence}";
      edit = ''old=${esc "- ${oldNoteSentence}"} awk '$0 == ENVIRON["line"] { $0 = ENVIRON["old"] } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "full access rule added under # Git";
      line = "- Ask for full access only when the user asks for it.";
      edit = ''awk '{ print } $0 == "# Git" { print ENVIRON["line"] }' '';
      expect = "names a delegation term outside the T3 Code and Compound Engineering sections: full access";
    }
    {
      name = "self-wake prohibition sentence removed";
      line = "- ${prohibitionSentence} ${allowedWaitsSentence}";
      edit = ''p=${esc prohibitionSentence} awk 'BEGIN { p = ENVIRON["p"] } $0 == ENVIRON["line"] { $0 = "- " substr($0, length(p) + 4) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "self-wake prohibition sentence negated";
      line = "- ${prohibitionSentence} ${allowedWaitsSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout definition sentence removed";
      line = "- ${scoutDefinitionSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout definition sentence negated";
      line = "- ${scoutDefinitionSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout assignment sentence removed";
      line = "- ${scoutAssignmentSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout assignment sentence negated";
      line = "- ${scoutAssignmentSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout assignment loses its failed-launch clause";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine scoutFailedLaunchClause "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout failed-launch clause joined by and instead of or";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine "returns no findings, or that waits" "returns no findings, and that waits";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout relaunch reuses the failed scout's clientRequestId";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine "under a new `clientRequestId`" "under the same `clientRequestId`";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout failure no longer ends in the parent's own research";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine scoutHandoffClause "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout no longer relaunches on its fallback";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine scoutRelaunchClause " counts as a failed launch";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout fallback raised to claude-opus-5-5 high";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine scoutFallbackClause "`claude-opus-5-5` on the `claudeAgent` instance with `effort` `high` as fallback";
      expect = "runs claude-opus-5-5 above effort medium: high";
    }
    {
      name = "scout rendered at another effort than its source role";
      line = "- ${scoutAssignmentSentence}";
      edit = replaceInLine "`thinking` `${role "deepseek" "scout"}`" "`thinking` `${
        if role "deepseek" "scout" == "max" then "high" else "max"
      }`";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout safeguard sentence removed";
      line = "- ${scoutSafeguardSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout safeguard sentence negated";
      line = "- ${scoutSafeguardSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout safeguard bans every untracked file again";
      line = "- ${scoutSafeguardSentence}";
      edit = replaceInLine ", no gitignored file${scoutUntrackedClause}" ", and no gitignored or untracked file";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "scout safeguard drops the untracked-file allowance";
      line = "- ${scoutSafeguardSentence}";
      edit = replaceInLine scoutUntrackedClause "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "shared-checkout default sentence removed";
      line = "- ${sharedCheckoutDefaultSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "shared-checkout default sentence negated";
      line = "- ${sharedCheckoutDefaultSentence}";
      edit = ''awk '$0 == ENVIRON["line"] { $0 = "- Do not " substr($0, 3) } { print }' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "shared-checkout default loses its cross-model peer exception";
      line = "- ${sharedCheckoutDefaultSentence}";
      edit = replaceInLine sharedCheckoutDefaultPeerClause "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "parallel-edits worktree trigger removed";
      line = "- ${parallelEditsSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "rewrite-command worktree trigger removed";
      line = "- ${rewriteTriggerSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "rewrite-command trigger loses its branch switch and mutation test examples";
      line = "- ${rewriteTriggerSentence}";
      edit = replaceInLine rewriteTriggerExamples "a formatter, a code generator, or a dependency update";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "committed-state worktree trigger removed";
      line = "- ${committedStateTriggerSentence}";
      edit = ''awk '$0 != ENVIRON["line"]' '';
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "shared-checkout rule loses its leave-to-the-parent clause";
      line = "- ${sharedCheckoutSentence}";
      edit = replaceInLine sharedCheckoutLeaveClause "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "launch-failure sentence loses its worktree fallback clause";
      line = "- ${launchFailureSentence}";
      edit = replaceInLine worktreeFallbackClause "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "worktree fallback no longer excludes a cross-model peer";
      line = "- ${launchFailureSentence}";
      edit = replaceInLine "a worktree launch of a task other than a cross-model peer" "a worktree launch of a task";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "worktree fallback no longer skips a task that must rewrite files";
      line = "- ${launchFailureSentence}";
      edit = replaceInLine worktreeFallbackRewriteCase "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "worktree fallback runs any task in the checkout again";
      line = "- ${launchFailureSentence}";
      edit = replaceInLine " only when it got its worktree for parallel edits of one file" "";
      expect = "does not hold this sentence exactly once, where a sentence starts:";
    }
    {
      name = "rewrite-command trigger moved above the shared-checkout default";
      line = "- ${rewriteTriggerSentence}";
      edit = ''d=${esc "- ${sharedCheckoutDefaultSentence}"} awk '$0 == ENVIRON["d"] { print ENVIRON["line"] } $0 != ENVIRON["line"] { print }' '';
      expect = "reorders or duplicates a T3 Code sentence:";
    }
    {
      name = "worktree sentence for every delegated task added";
      line = "- Launch every delegated task with `isolation: \"worktree\"`.";
      edit = ''awk '{ print } $0 == "# T3 Code" { print ENVIRON["line"] }' '';
      expect = "carries an unpinned T3 Code sentence:";
    }
    {
      name = "review-findings narrowing sentence added";
      line = "Only findings from `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` apply.";
      edit = ''awk '{ print } $0 == "# Review findings" { print ENVIRON["line"] }' '';
      expect = "carries an unpinned review-findings sentence: Only findings from";
    }
    {
      name = "review-findings tag sentence moved above the exception sentence";
      line = reviewFindingsLine;
      edit = replaceInLine "${reviewFindingsExceptionSentence} ${reviewFindingsTagSentence}" "${reviewFindingsTagSentence} ${reviewFindingsExceptionSentence}";
      expect = "reorders or duplicates a review-findings sentence:";
    }
    {
      name = "review-findings tag sentence removed";
      line = reviewFindingsLine;
      edit = replaceInLine "${reviewFindingsTagSentence} " "";
      expect = "moves a review-findings sentence out of its section: ${reviewFindingsTagSentence}";
    }
    {
      name = "review-findings tag sentence negated";
      line = reviewFindingsLine;
      edit = replaceInLine "List only those findings" "Do not list only those findings";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${reviewFindingsTagSentence}";
    }
  ]
  ++ removedAndNegated "claude host sentence" claudeHostSentence
  ++ removedAndNegated "glm host sentence" glmHostSentence
  ++ removedAndNegated "kimi host sentence" kimiHostSentence
  ++ removedAndNegated "other-host sentence" otherHostSentence
  ++ removedAndNegated "left-out named peer sentence" leftOutPeerSentence
  ++ removedAndNegated "outside-T3 Synthetic peer sentence" syntheticOutsideSentence
  ++ removedAndNegated "session_info-first sentence" sessionInfoSentence
  ++ removedAndNegated "Pi model-ID fallback sentence" piModelSentence
  ++ lib.concatMap (sentence: removedAndNegatedIn "Pi over ACP" "ACP sentence" sentence) acpSentences
  ++ [
    {
      name = "worker sent back to the opencode instance";
      line = "- ${writingSentence}";
      edit = replaceInLine "on the `pi` instance with `thinking`" "on the `opencode` instance with `variant`";
      expect = "assigns a model an instance, knob, or effort it does not take: synthetic/${glmId} on opencode with variant ${role "glm" "writing-fallback"}";
    }
    {
      name = "review peer sent to the pi agent over ACP";
      line = "- ${acpPeerAgentSentence}";
      edit = replaceInLine "on the `pi-readonly` agent" "on the `pi` agent";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${acpPeerAgentSentence}";
    }
    {
      name = "ACP worker lowered to medium";
      line = "- ${acpLowSentence}";
      edit = replaceInLine "`thought_level` `${role "deepseek" "unspecified-low"}`" "`thought_level` `medium`";
      expect = "assigns a model an instance, knob, or effort it does not take: synthetic/${deepseekId} on pi with thought_level medium";
    }
    {
      name = "ACP quick unit collapsed to the unspecified-low effort";
      line = "- ${acpQuickSentence}";
      edit = replaceInLine "`thought_level` `${role "deepseek" "quick"}`" "`thought_level` `${role "deepseek" "unspecified-low"}`";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${acpQuickSentence}";
    }
    {
      name = "ACP quick and unspecified-low units collapsed into one rule";
      line = "- ${acpQuickSentence}";
      edit = replaceInLine "Give each `quick` unit" "Give each `quick` or `unspecified-low` unit";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${acpQuickSentence}";
    }
    {
      name = "ACP deep fallback collapsed to the writing fallback's effort";
      line = "- ${acpDeepSentence}";
      edit = replaceInLine "`thought_level` `${role "glm" "deep-fallback"}`" "`thought_level` `${role "glm" "writing-fallback"}`";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${acpDeepSentence}";
    }
    {
      name = "ACP visual-engineering fallback sent to GLM";
      line = "- ${acpVisualSentence}";
      edit = replaceInLine "`synthetic/${kimiId}`" "`synthetic/${glmId}`";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${acpVisualSentence}";
    }
    {
      name = "ACP fallback category dropped from the lead rule";
      line = "- ${acpFallbackSentence}";
      edit = replaceInLine "`writing`, `visual-engineering`, `deep`, or `unspecified-high`" "`writing`, `deep`, or `unspecified-high`";
      expect = "does not hold this sentence exactly once, where a sentence starts: ${acpFallbackSentence}";
    }
    {
      name = "scout sent over ACP";
      line = "- Run a `ce-plan` scout on the `pi-readonly` agent.";
      edit = ''awk '{ print } $0 == "# Pi over ACP" { print ENVIRON["line"] }' '';
      expect = "carries an unpinned Pi over ACP sentence: Run a `ce-plan` scout on the `pi-readonly` agent.";
    }
    {
      name = "ACP section heading dropped";
      line = acpHeading;
      edit = lineRemoved;
      expect = "carries top-level headings other than the expected list:";
    }
    {
      name = "ACP section leaked into Pi's copy";
      copy = "pi";
      line = "- ${acpRouteSentence}";
      edit = ''h=${esc acpHeading} awk '{ print } END { print ""; print ENVIRON["h"]; print ""; print ENVIRON["line"] }' '';
      expect = "carries text of the ACP section, which Pi's copy must not hold: Pi over ACP";
    }
    {
      name = "acpx rule added to Pi's copy";
      copy = "pi";
      line = "- Run each Synthetic peer through `acpx`.";
      edit = ceLineAdded;
      expect = "carries text of the ACP section, which Pi's copy must not hold: acpx";
    }
    {
      name = "Pi model-ID fallback sentence missing from Pi's copy";
      copy = "pi";
      line = "- ${piModelSentence}";
      edit = lineRemoved;
      expect = "moves a Compound Engineering sentence out of its section: ${piModelSentence}";
    }
  ];

  # Proves the per-file rules fire: the unmutated rendering must pass them and
  # every mutant must fail them with its expected message. Each run happens in
  # a subshell with its own `file` and `failed`, and its messages go to a log,
  # so it can neither set the outer `failed` nor print a real failure. A broken
  # self-test sets `selfTestFailed` instead.
  selfTest =
    let
      copies = {
        full = {
          expected = expectedFile fakeKey;
          rules = rulesFor fakeKey;
        };
        pi = {
          expected = expectedShared fakeKey;
          rules = piRulesFor fakeKey;
        };
      };
      # No newline after the closing parenthesis, so the redirection the
      # caller appends applies to the subshell.
      runRules = copy: path: ''
        (
          file=${path}
          failed=0
          ${fileRules "the self-test rendering" fakeKey [ cardKey ] copies.${copy}.rules}
          [ "$failed" = "0" ]
        )'';
    in
    "log=$(mktemp)\n"
    + lib.concatMapStrings (copy: ''
      original=${copies.${copy}.expected}
      if [ ! -s "$original" ]; then
        echo ${esc "self-test: the expected ${copy} rendering is missing or empty"} >&2
        selfTestFailed=1
      else
        if ! ${runRules copy "\"$original\""} 2> "$log"; then
          echo ${esc "self-test: the unmutated ${copy} rendering fails the per-file rules:"} >&2
          cat "$log" >&2
          selfTestFailed=1
        fi
      fi
    '') (lib.attrNames copies)
    + lib.concatMapStrings (
      mutant:
      let
        copy = mutant.copy or "full";
      in
      ''
        original=${copies.${copy}.expected}
        mutated=$(mktemp)
        line=${esc mutant.line} ${mutant.edit} < "$original" > "$mutated"
        if cmp -s "$original" "$mutated"; then
          echo ${esc "self-test: the mutation did not apply: ${mutant.name}"} >&2
          selfTestFailed=1
        elif ${runRules copy "\"$mutated\""} 2> "$log"; then
          echo ${esc "self-test: a mutant passed the per-file rules: ${mutant.name}"} >&2
          selfTestFailed=1
        elif ! grep -qF -- ${esc mutant.expect} "$log"; then
          echo ${esc "self-test: a mutant failed without the expected message (${mutant.expect}): ${mutant.name}"} >&2
          cat "$log" >&2
          selfTestFailed=1
        fi
      ''
    ) selfTestMutants;

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

  ${repoCopyRules}

  selfTestFailed=0
  ${selfTest}

  if [ "$failed" != "0" ] || [ "$selfTestFailed" != "0" ]; then
    exit 1
  fi

  touch $out
''
