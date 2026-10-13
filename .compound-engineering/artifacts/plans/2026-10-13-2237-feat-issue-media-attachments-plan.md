---
title: Media Attachments in Issues and Pull Requests - Plan
type: feat
date: 2026-10-13
topic: issue-media-attachments
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Media Attachments in Issues and Pull Requests - Plan

## Goal Capsule

- **Objective:** Issues, pull requests, merge requests, and their comments that a coding agent writes on GitHub or GitLab carry the screenshots and videos a reader needs, so the reader sees the problem or change instead of reconstructing it from text.
- **Means:** Add a media section to the global agent instructions in `home/h82/agents/instructions/instructions.md.tmpl`, which Claude Code, Codex, and Antigravity all load, and guard its sentences in `tests/agent-instructions.nix` (KTD1, KTD4).
- **Product authority:** This Product Contract, then the Planning Contract.
- **Open blockers:** None.
- **Execution profile:** Lightweight; two units in one PR (U1, U2).
- **Stop conditions:** Stop if a harness's rendered file cannot carry the new section, or if the render check cannot be made to fail when one of the guarded sentences is removed, negated, or moved into one harness's branch.
- **Who finishes:** `ce-work` implements and verifies; `lfg` reviews, opens the PR, and watches CI. Merging stays with the user.

---

## Product Contract

Product Contract preservation: changed R4, R8, R9, R10 — document review found that R4 skipped capture whenever unrelated media was present, that R8 allowed a reversible mask, that R9's example read as excluding every moving video, and that R10 let brief content fall between sampled frames; added R16 (metadata removal, serving R8's personal-data intent) and R17 (GitHub paths with no `--attach`, serving R1's comment scope), and R18 with its Key Decision (GitLab image uploads outside a project's access boundary, settled with the user during review). The two Deferred to Planning questions are resolved in KTD2 and KTD4 and removed from Outstanding Questions.

### Summary

When a coding agent creates or edits a GitHub or GitLab issue, pull request, merge request, or comment, it attaches the images and videos from the conversation, and it captures its own when showing the screen or behavior would help. It masks secrets and personal data before upload, leaves a file out only when masking would make it useless or cannot be done reliably, and uploads through `gh` and `glab` alone.

### Problem Frame

Agents often create issues as text only, even when the user pasted a screenshot or recording into the conversation. A reader of the issue then has to infer from prose what the user saw, and the agent that later picks the issue up has less to work from. The user wants issues and pull requests to carry more context. Agents also rarely produce media on their own when a bug or UI change is reproducible with tools they already have, such as browser automation or an app preview.

### Key Decisions

- **Global agent instructions, not a skill.** The rule must apply to every path that writes an issue or pull request, including ones where no skill is invoked. (session-settled: user-approved — chosen over a separate skill: a skill only applies when something invokes it.) Governs R1.
- **Issues, pull requests, merge requests, and comments.** (session-settled: user-directed — chosen over issues only and over issues plus issue comments: the same attachment path serves all of them.) Governs R1.
- **Upload through CLI or API only.** No browser automation of the GitHub or GitLab web UI. (session-settled: user-directed — chosen over uploading through the web UI in a browser.) Governs R11, R12, R17.
- **Capture media when showing would help, not always.** (session-settled: user-directed — chosen over attaching only media that already exist, such as test or CI artifacts, and over capturing everything that can be rendered as an image.) Governs R3, R4, R5, R7.
- **Drop media only when masking makes it useless or cannot be done reliably.** (session-settled: user-directed — chosen over asking the user whenever sensitive content appears and over a stricter rule for public repositories only.) Governs R8, R9.
- **Videos are in scope, and agents check them by viewing extracted frames.** The video probe showed Antigravity cannot see video in this environment, so there is no rule to route video input to Antigravity. (session-settled: user-approved — chosen over sending video to Antigravity, which failed through `view_file` and through a T3 Code attachment: frame extraction works in every harness.) Governs R2, R10.
- **Verify the masked file before upload.** An uploaded file can stay reachable by URL after the issue is deleted, so a masking miss cannot be undone. (session-settled: user-approved — proposed as a safeguard the request did not name; confirmed in the scoping synthesis.) Governs R10.
- **Keep images off GitLab projects whose uploads skip authentication.** A private or internal GitLab project serves uploaded images to anyone with the URL unless it enforces authentication on uploads, so masking alone does not keep them inside the project. (session-settled: user-directed — chosen over uploading with a warning and over asking each time: the image would leave the project's access boundary.) Governs R18.

### Requirements

**Scope**

- R1. The rule applies whenever the agent creates or edits a GitHub or GitLab issue, pull request, merge request, or a comment on one of them.
- R2. Media means images and videos, whether the user supplied them in the conversation or the agent produced them.

**Gathering media**

- R3. The agent attaches every image or video the user supplied in the conversation that relates to the item being written, subject to R8 and R9.
- R4. When showing the screen or behavior would help a reader and no media in the conversation already shows it, the agent reproduces it with tools available in the session and captures a screenshot, or a recording when the point is motion or a sequence of steps.
- R5. The agent does not capture when reproducing would need production data, payments, a login it does not already hold, or another action with side effects, and it tells the user why it captured nothing.
- R6. Logs and terminal output go into the body as fenced code blocks, not as images.
- R7. For a pull or merge request that changes something visible, the agent attaches the state after the change, and adds the state before it when the base revision can be run without much effort.

**Masking**

- R8. Before upload, the agent masks credentials, tokens, passwords, personal data, and internal hosts or addresses visible in the media, so that the masked content cannot be recovered from the uploaded file.
- R9. The agent leaves a file out only when masking would remove what the file was meant to show, or when the sensitive content cannot be reliably masked, such as a sensitive region that cannot be located in every frame of a recording, as in AE5; it then tells the user which file it left out and why.
- R16. Before upload, the agent removes embedded metadata, such as location, device, and capture time, from every image and video, including files that need no visual masking.
- R10. The agent views the masked result before uploading it, and checks a video by extracting and viewing frames dense enough that content shown only briefly is among them.

**Upload**

- R11. On GitHub, the agent uploads with the `--attach` option of `gh issue create`, `gh issue comment`, `gh issue edit`, `gh pr create`, `gh pr comment`, or `gh pr edit`.
- R17. When the GitHub item being written has no `--attach` path, such as a review-thread reply or an edit of a comment other than the agent's last, the agent posts the media in a separate `gh issue comment --attach` or `gh pr comment --attach` on the same issue or pull request and links that comment from the text it wrote.
- R12. On GitLab, the agent uploads through the project uploads API with `glab api` and puts the returned Markdown into the body; for a merge request from a fork, it uploads to the target project that renders the merge request.
- R18. Before uploading an image to a private or internal GitLab project, the agent checks that the project enforces authentication on uploads; when it does not, the agent uploads no images there and tells the user which files it held back, why, and that a maintainer can turn on "Require authentication to view media files" in the project's visibility settings.
- R13. When some uploads fail, the agent tells the user which files did not attach, including when `gh` created the item but exited non-zero.

**Skills and guard**

- R14. When a skill defines the body of an issue or pull request, the agent keeps that structure and adds the media to it.
- R15. The repository's render check fails when any of the new section's required sentences is missing, reworded, negated, or present in only one harness's rendered file.

### Acceptance Examples

- AE1. **Covers R3, R11.** **Given** the user pasted a screenshot of an error dialog and asks for a GitHub issue, **when** the agent creates the issue, **then** the screenshot appears in the issue body through `gh issue create --attach`.
- AE2. **Covers R4.** **Given** a layout bug in a web app the agent can open in a browser it controls and no media in the conversation, **when** the agent files the issue, **then** it attaches a screenshot of the broken layout.
- AE3. **Covers R5.** **Given** the bug only appears after checkout with a real card, **when** the agent files the issue, **then** it attaches no capture and tells the user that reproducing it would make a payment.
- AE4. **Covers R8, R10.** **Given** a screenshot that shows an API token in a terminal pane, **when** the agent attaches it, **then** the uploaded image has the token masked and the agent viewed the masked image before uploading.
- AE5. **Covers R9.** **Given** a screen recording in which a password field scrolls through several frames, **when** the agent cannot mask it reliably, **then** the recording is not uploaded and the agent names the file and the reason.
- AE6. **Covers R6.** **Given** a failing build, **when** the agent files the issue, **then** the build log is a fenced code block and no terminal screenshot is attached.
- AE8. **Covers R18.** **Given** a private GitLab project with authentication on uploads turned off and a masked screenshot, **when** the agent files the issue, **then** the screenshot is not uploaded and the agent names it, the reason, and the setting that would allow it.
- AE7. **Covers R12.** **Given** a GitLab merge request from a fork with a screenshot, **when** the agent opens it, **then** the image is uploaded to the target project and renders in the merge request.

### Scope Boundaries

- Uploading through a browser session on the GitHub or GitLab web UI.
- Routing video input to Antigravity or any other model; nothing verified it can see video in this environment.
- Hosting media outside the issue tracker, such as a media branch, a gist, or a third-party image host.
- Changing the body structure that `ce-commit-push-pr` or other skills define for pull requests.

### Dependencies / Assumptions

- `gh` 2.102.0 or later, which provides `--attach` on issue and pull request create, comment, and edit. The installed version is 2.102.0.
- `glab` 1.114.0 has no `--attach`; uploads go through `glab api --form` against the project uploads endpoint. An upstream merge request proposes `--attach`.
- Masking and frame extraction use `ffmpeg`, which no host installs globally; the agent reaches it through `nix shell nixpkgs#ffmpeg`, since every host in scope has Nix (KTD3).

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` and `home/h82/agents/instructions/default.nix`: the shared template and how each harness renders it.
- `tests/agent-instructions.nix`: the sentence-level render check new sections register in.
- `gh issue create --help` (gh 2.102.0): `--attach '<file>#<alt text>'`, up to 50 files, body references to local files rewritten to the uploaded URL, partial failure creates the item and exits non-zero.
- [GitHub CLI: media in issues, pull requests, and comments](https://github.blog/changelog/2026-09-01-github-cli-media-in-issues-pull-requests-and-comments)
- [GitLab project markdown uploads API](https://docs.gitlab.com/api/project_markdown_uploads/): `POST /projects/:id/uploads` returns a `markdown` field.
- [GitLab user file uploads](https://docs.gitlab.com/security/user_file_uploads/): images in private or internal projects are viewable by URL unless the project enables "Require authentication to view media files"; `GET /projects/:id` returns it as `enforce_auth_checks_on_uploads`.
- [glab merge request proposing `--attach`](https://gitlab.com/gitlab-org/cli/-/merge_requests/3835)
- Antigravity video probe, 2026-10-13: Gemini 3.8 Flash through T3 Code read a known test video as binary text through `view_file`, and received only a saved-path note through a T3 Code attachment; it described the content in neither case.
- `glab api --help` (glab 1.114.0): `--form` sends `multipart/form-data` with `@<path>` file values, and `:id` in the endpoint is replaced with the current project's ID.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **One new top-level section in the shared template body, outside every harness branch.** The section goes after `# Branch names` as `# Issue and pull request media`, so all three rendered files carry the same text, matching how `# Learning refresh` and `# Branch names` were added. Governs R1 through R14, R16 through R18.
- KTD2. **Name capture capabilities, not harness tools.** The body text is shared by Claude Code, Codex, and Antigravity, and the render check fails when one harness's file names another harness's native tools. The section names kinds of tools (browser automation, an app preview, a device simulator) rather than `agent-browser` or T3 Code preview tool names. Governs R4.
- KTD3. **`ffmpeg` through `nix shell nixpkgs#ffmpeg` for masking, metadata removal, and frame extraction.** It covers images and video with one tool, and every host in scope has Nix, so no package is added to the closure. A `ffmpeg` already on `PATH` is used as is. The section tells the agent four things about it:
  1. Mask with an opaque filled box over the whole sensitive region, never blur or pixelation, which tools such as Depix can reverse (R8).
  2. Read the file's real pixel size with `ffprobe` and scale coordinates taken from the viewed image to it, because harnesses show large images downscaled (R8).
  3. Re-encode every file without its metadata (R16).
  4. For a video, extract a frame at every scene change plus at least one frame per second, both to find what to mask and to check the result (R10).
  Governs R8, R10, R16.
- KTD4. **Pin one sentence per requirement in the render check.** A new `mediaSentences` list in `tests/agent-instructions.nix` holds the sentence that carries each of R1, R3 through R14, and R16 through R18, checked with the existing `requireSentences` helper so a deleted, reworded, negated, or branch-moved sentence fails. R2 is a definition carried by the other sentences and is not pinned on its own. Governs R15.
- KTD5. **GitLab uploads use `glab api --form` against `projects/:id/uploads`.** glab 1.114.0 has no `--attach`; the `:id` placeholder resolves the current project, and a fork merge request names the target project explicitly instead. Before an image upload, `glab api projects/:id` returns the project's `visibility` and `enforce_auth_checks_on_uploads`, which decide R18; non-image files already require authentication. Governs R12, R18.

### Assumptions

- The section's sentences are imperative and addressed to the agent, like the rest of the template, and each pinned sentence starts at a line start or after a full stop so `requireSentences` can find it.
- Video recordings are captured with whatever recording the session's browser or preview tool offers; when none exists, the agent falls back to screenshots and says so.

---

## Implementation Units

### U1. Add the media section to the shared agent instructions

- **Goal:** Every harness's rendered instruction file tells the agent how to gather, mask, verify, and upload media for issues, pull or merge requests, and comments.
- **Requirements:** R1 through R14, R16 through R18; KTD1, KTD2, KTD3, KTD5. Implements the settled decisions whose Key Decisions govern R1, R3, R4, R5, R7, R8, R9, R10, R11, R12, R17, R18.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Add `# Issue and pull request media` after the `# Branch names` section, outside every `{{ if }}` branch (KTD1).
  2. Open with a one-paragraph rule stating when it applies and what it asks (R1, R3), then bullets grouped in this order: gathering (R4, R5, R6, R7), masking and checking (R8, R16, R9, R10), upload (R11, R17, R12, R18, R13), and skills (R14).
  3. Name tool kinds rather than harness-specific tool names (KTD2), and name `ffmpeg` with its `nix shell` fallback (KTD3).
  4. Name the exact `gh` subcommands and the `glab api` upload form (R11, R12, KTD5).
- **Patterns to follow:** The `# Learning refresh` and `# Branch names` sections: a lead paragraph, then short imperative bullets, one rule per bullet.
- **Test scenarios:** Covered by U2's render check; this unit has no behavior of its own beyond the rendered text.
- **Verification:** All three rendered files carry the section with identical text, and none carries an unrendered template action.

### U2. Guard the media section in the render check

- **Goal:** The agent-instructions render check fails when any pinned media sentence is missing from, reworded in, negated in, or moved out of any harness's rendered file.
- **Requirements:** R15; KTD4.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Add a `mediaSentences` list beside `branchNameSentences`, with one literal sentence copied from U1 for each requirement KTD4 names.
  2. Call `requireSentences` with a `lacks the media rule:` message inside `sourcePresent`.
  3. Add a bullet to the header comment describing what the new list guards, in the style of the existing bullets.
- **Execution note:** Mutation-test the new list before declaring it done, per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`, in a scratch copy that does not write the real index (`.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`).
- **Patterns to follow:** `branchNameSentences` and `learningRefreshSentences` and their `requireSentences` calls.
- **Test scenarios:**
  - The check passes on the U1 template for every host and harness.
  - Deleting one pinned sentence from the template fails the check and names that sentence.
  - Prefixing a pinned sentence with "Do not" fails the check.
  - Moving the section inside the `claude-code` branch fails the check for Antigravity and Codex.
  - Changing one word of a pinned sentence, such as `--attach` to `--upload`, fails the check.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes on the change and fails on each mutation above.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | U2 |
| Render check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1, U2 |
| Flake checks | `nix flake check` | U1, U2 |
| Host outputs | Build every `nixosConfigurations` toplevel and every `homeConfigurations` and `systemConfigs` output per `AGENTS.md` | U1 |
| Markdown lint | `mise run lint-staged-markdown` through the pre-commit hook | plan file |

macOS outputs build only in CI's `build-darwin` job.

---

## Definition of Done

- The rendered Claude Code, Codex, and Antigravity instruction files each carry the media section with the same text.
- The render check passes, and each U2 mutation turned it red before being reverted.
- `nix flake check` and the host-output builds pass.
- No experimental or abandoned edits remain in the diff.
