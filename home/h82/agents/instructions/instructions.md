# GPG and encryption

The user's GPG key is on a YubiKey that stays connected, and its PIN is usually cached.

- Run GPG signing, decryption, and encryption yourself, including SOPS re-encryption and edits; when a pinentry dialog appears, let it reach the user.
- Stop and report only when the PIN is rejected, the prompt times out, or the card is missing.
- Never print decrypted values, pass them as arguments, or open decrypted files with the file tools; pipe decrypted output straight into the command that consumes it.
- Leave card administration and key management to the user.
- For a new SOPS setup or secret file, use the card key `621512777E6933FEB4458FDC4945855D4F283F05` as the user's recipient, plus a machine's own recipient when it must decrypt without the card. Keep the existing method in a project that already has one.

# Git

- Before the first push, rename a branch whose name does not describe the change, such as a worktree codename or random hex, with `git branch -m`. Follow the project's documented naming rule; otherwise use `type/short-kebab-slug` with a Conventional Commits type. Never rename onto or push over an existing branch.
- When a commit hook fails because mise does not trust a `mise.toml` in a temporary copy the hook made, retry that commit once with `MISE_TRUSTED_CONFIG_PATHS="$(cd "${TMPDIR:-/tmp}" && pwd -P)"`. Do not run `mise trust` on the copy or skip the hook with `--no-verify`.
- Before each push, find the learnings under the project's Compound Engineering `solutions/` directory that cite a path or name the pushed commits delete, move, or rename. Refresh each with `ce-compound-refresh`, commit each refresh separately on the current branch, then push once.

# Pull and merge requests

- Treat GitLab like GitHub: when a Compound Engineering skill speaks only GitHub, do the same steps with `glab`, and skip only a step with no GitLab counterpart, naming it in your report.
- After you open or push to a pull or merge request, babysit it until it looks ready to merge, then leave the merge to the user. Babysit a draft only when asked. On GitLab, call it ready only when `head_pipeline` passed on the current `sha`, `detailed_merge_status` is `mergeable`, and no discussion is unresolved; never rebase.
- Attach the screenshots or recordings a reader needs to see the change. Before uploading, cover secrets, personal data, and internal hosts with opaque boxes, never blur, and strip metadata with `ffmpeg -map_metadata -1`. Upload through `gh --attach` or the GitLab uploads API, never a browser.

# Review findings

Apply every finding that `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` report, whatever its severity, confidence, or list, including testing gaps and residual risks. Leave a finding unapplied only when you verified it is wrong or its fix would weaken a safety check, and say why. When a fix needs a user decision, such as a product or scope change, ask in an interactive run; in an autonomous run, apply the recommended fix and report it, but ask before reversing a decision the user made. When the user asked only for a review, report the findings and ask once whether to apply them all. Report what you applied in the pull request body and the final report.

# T3 Code

- When the session lists T3 Code's delegation tools, such as `delegate_task`, delegate subagent work through them; otherwise use your native subagent tool.
- When the session lists T3 Code's pull request tools, such as `watch_pull_request`, use them to watch a request you babysit instead of your own background wait.
