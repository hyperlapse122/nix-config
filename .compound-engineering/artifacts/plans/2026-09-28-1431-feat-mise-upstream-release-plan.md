---
title: mise Upstream Release Pin - Plan
type: feat
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# mise Upstream Release Pin - Plan

## Goal Capsule

- **Objective:** On every host, the `mise` built from main is the newest upstream jdx/mise release, instead of whatever version nixpkgs unstable last packaged. The hourly update workflow bumps the pin on main within an hour of publication once that run's verification passes, and hosts pick it up on their next rebuild.
- **Means:** repackage the upstream prebuilt static binary from a pinned in-repo release file, resolved and bumped by a release helper in the hourly update workflow, the same shape as claude-code (KTD1, KTD2).
- **Authority:** the user's request and the settled decisions (KTD1, KTD2) outrank this plan's inferred choices; `AGENTS.md` outranks both on repository conventions.
- **Stop conditions:** stop if the upstream release no longer publishes a `linux-x64-musl` tarball with a `SHASUMS256.txt` entry, or if the prebuilt binary cannot pass `mise --version` inside the Nix build sandbox.
- **Execution profile:** packaging plus a CI helper; prefer build and check evidence over new unit coverage except for the helper, which gets fixture tests.
- **Finish and ship:** `ce-work` implements and verifies locally; the LFG pipeline reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Add `packages/mise.nix`, which installs the upstream `mise-v<version>-linux-x64-musl.tar.gz` release pinned by `packages/mise-release.json`. Add a `mise-release` helper that reads upstream `SHASUMS256.txt` for the latest release and rewrites the pin. Wire the package into `programs.mise.package`, the flake's packages and checks, and the hourly `update-dependencies` workflow.

### Problem Frame

nixpkgs unstable currently ships mise 2026.8.6 while upstream is at v2026.9.15. mise releases several times a week and its tool registry and backends change with each release, so a nixpkgs lag of weeks leaves the user on stale behavior. claude-code already solves the same lag with an in-repo pin that CI bumps hourly; the user asked for mise to follow that model.

### Requirements

**Packaging**

- R1. `programs.mise` for user `h82` uses a mise package built from the pinned upstream release, not `pkgs.mise`.
- R2. The package installs `bin/mise`, the man page, and bash, zsh, and fish completions, matching what the nixpkgs package installs today.
- R3. The package disables mise's self-update, as the nixpkgs package does, because the binary lives in the read-only store.
- R4. The build fails unless the installed binary reports the pinned version.

**Release tracking**

- R5. A `mise-release` helper resolves the latest upstream release and writes its version and tarball hash to `packages/mise-release.json`.
- R6. The helper refuses to write a pin that is incomplete (no `linux-x64-musl` tarball entry) or not strictly newer than the current pin.
- R7. The hourly `update-dependencies` workflow runs the helper and commits a bump as `chore(packages): bump mise to <version>`.

**Guards**

- R8. A flake check fails when a configuration's `home.path` `bin/mise` is not the pinned package.
- R9. The helper's behavior is covered by offline fixture tests registered as a flake check.

### Key Decisions

- **Upstream latest release, not nixpkgs.** Governs R1, R5. (session-settled: user-directed — chosen over keeping `pkgs.mise` from nixpkgs unstable: the user wants upstream latest as with claude-code)

### Scope Boundaries

- The existing `all_compile = false` setting and the mutable `config.toml` behavior stay as they are; `tests/mise-settings.nix` keeps asserting them.
- Only `x86_64-linux` is packaged, matching the flake's single system.
- Verifying upstream minisign or sigstore signatures is out of scope; the pin records the SHA-256 that upstream publishes and Nix enforces it.

#### Deferred to Follow-Up Work

- Sharing one release-helper skeleton across claude-code, claude-desktop, and mise. The three scripts duplicate their fetch and argument handling; consolidating them is a separate refactor.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Follow the claude-code mechanism.** A pinned JSON file under `packages/`, a Python release helper packaged through `packages/agent-tools.nix`, a workflow step in `.github/workflows/update-dependencies.yml`, and flake checks. (session-settled: user-directed — chosen over an ad-hoc unpinned fetch or a separate flake input: the user asked for mise to work "like claude-code")
- KTD2. **Repackage the upstream prebuilt `linux-x64-musl` tarball rather than override nixpkgs' source build.** Overriding `src` also requires a new `cargoHash`, which the helper cannot compute without a full Nix build, and the source build runs mise's long test suite. The musl binary is statically linked, so it needs no `autoPatchelfHook` and no nix-ld, and upstream publishes its SHA-256. The glibc tarball was the other candidate; it links against `/lib` paths and would need patching.
- KTD3. **Resolve the release from `https://github.com/jdx/mise/releases/latest/download/SHASUMS256.txt`.** One redirect-following fetch returns both the version, from the `./mise-v<version>-linux-x64-musl.tar.gz` filename, and its checksum. This avoids the GitHub REST API's unauthenticated 60-requests-per-hour limit on shared runners. If "latest" ever points at a non-mise release (the repo also tags subcrates such as `aqua-registry`), the file has no matching entry and R6 refuses.
- KTD4. **Pin file shape mirrors `packages/claude-desktop-version.json`:** `version` (no leading `v`), `sha256` (hex, as upstream publishes it), and `hash` (SRI, consumed by `fetchurl`).
- KTD5. **Generate completions at build time with `mise completion <shell>`.** The v2026.9.x binary embeds the usage library and emits completions without an external `usage` binary, verified offline against v2026.9.15. This avoids pinning three more release assets. Set `HOME` to a temporary directory for the call.
- KTD6. **Enforce R4 with `versionCheckHook` in the package, and enforce R8 by resolving the materialized `home.path` `bin/mise`.** Per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reverifies-install-check-hook-guarantee.md`, the flake check should not re-run `--version`. Per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, it should check what landed in `home.path` rather than the option value. The check resolves `$homePath/bin/mise` and compares it with the pinned package's `bin/mise`.

### Assumptions

- The upstream asset naming `mise-v<version>-linux-x64-musl.tar.gz` and the `./`-prefixed `SHASUMS256.txt` lines stay stable across releases.
- `versionCheckHook` works with mise's `--version` output (`2026.9.15 linux-x64 (2026-09-27)`), which contains the bare version. If mise needs a writable `HOME` under the hook, keep that environment variable, as nixpkgs' claude-code does with `versionCheckKeepEnvironment`.
- Home Manager's `programs.mise.package` feeds both `home.packages` and the `mise activate zsh` line, so setting it once covers R1.

---

## Implementation Units

### U1. mise release helper

- **Goal:** add `scripts/mise-release`, which resolves the latest upstream release and writes or checks `packages/mise-release.json`.
- **Requirements:** R5, R6, R9; KTD1, KTD3, KTD4.
- **Dependencies:** none.
- **Files:**
  - `scripts/mise-release` (create)
  - `tests/test_mise_release.py` (create)
  - `packages/agent-tools.nix` (add `miseRelease`)
  - `flake.nix` (add `packages.mise-release` and `checks.mise-release`)
- **Approach:**
  1. Mirror `scripts/claude-code-release` and `scripts/claude-desktop-release`: a `Failure` exception, an overridable `MISE_RELEASE_FETCH` command (default `curl -sfL`), `--output`, `--dry-run`, and `--source-url` flags.
  2. Parse `SHASUMS256.txt` lines of the form `<hex>  ./mise-v<version>-linux-x64-musl.tar.gz`, matching only the exact `-linux-x64-musl.tar.gz` suffix so the `.tar.xz`, `.tar.zst`, glibc, and bare-binary entries are ignored.
  3. Validate the version against a dotted-numeric pattern and the hex against 64 characters, then convert the hex to SRI.
  4. Refuse, as claude-code does, when the resolved version is not strictly newer than the pinned one, and print an up-to-date message instead of rewriting the file.
- **Patterns to follow:** `scripts/claude-code-release` (downgrade refusal), `scripts/claude-desktop-release` (hex-to-SRI conversion), `tests/test_claude_code_release.py` (fake fetch fixture), the `claude-code-release` check in `flake.nix`.
- **Test scenarios:**
  - A fixture `SHASUMS256.txt` with a newer version writes `version`, `sha256`, and `hash` to the output file, and the SRI matches the hex.
  - A fixture with the same version as the pin leaves the file byte-identical and exits 0.
  - A fixture with an older version than the pin leaves the file unchanged and exits 0.
  - A fixture listing only glibc, `.tar.xz`, and `.tar.zst` entries exits non-zero and writes nothing.
  - A fixture with a malformed checksum or non-numeric version exits non-zero.
  - A failing fetch command exits non-zero with a message naming the URL.
  - `--dry-run` prints the resolved JSON and does not create the output file.
  - An empty `MISE_RELEASE_FETCH` exits non-zero.
- **Verification:** `checks.x86_64-linux.mise-release` builds, and `nix run .#mise-release -- --dry-run` prints the current upstream release.

### U2. Pinned mise package

- **Goal:** add `packages/mise.nix` and `packages/mise-release.json`, which install the pinned upstream binary with a man page, completions, and self-update disabled.
- **Requirements:** R2, R3, R4; KTD2, KTD4, KTD5, KTD6.
- **Dependencies:** U1, which produces the first pin through `nix run .#mise-release -- --output packages/mise-release.json`.
- **Files:**
  - `packages/mise.nix` (create)
  - `packages/mise-release.json` (create)
  - `flake.nix` (add `packages.mise`)
- **Approach:**
  1. `stdenvNoCC.mkDerivation` reading the pin with `builtins.fromJSON`, the same way `packages/claude-desktop.nix` does, and `fetchurl` for `https://github.com/jdx/mise/releases/download/v<version>/mise-v<version>-linux-x64-musl.tar.gz`.
  2. Install `bin/mise` and `man/man1/mise.1` from the tarball. Skip `bin/mise.d`, which is a Cargo dependency file, and the fish `vendor_conf.d` activation, which Home Manager already handles.
  3. Generate bash, zsh, and fish completions with `installShellCompletion` from the installed binary (KTD5).
  4. Create `lib/mise/.disable-self-update`, the marker the upstream binary checks, as nixpkgs does.
  5. Enable `doInstallCheck` with `versionCheckHook` (KTD6).
  6. Set `meta` fields: `mainProgram = "mise"`, MIT license, `platforms = [ "x86_64-linux" ]`, `sourceProvenance = [ binaryNativeCode ]`.
- **Execution note:** this is packaging; prove it with a build and smoke run of the installed binary rather than new unit tests.
- **Patterns to follow:** `packages/claude-desktop.nix` for a pinned `fetchurl` source; nixpkgs `pkgs/by-name/mi/mise/package.nix` `postInstall` for man page, completions, and the self-update marker.
- **Test scenarios:**
  - Test expectation: none -- packaging; `versionCheckHook` and U3's check carry the proof.
- **Verification:** `nix build .#mise` succeeds, and the result contains `bin/mise`, `share/man/man1/mise.1.gz`, `share/zsh/site-functions/_mise`, `share/bash-completion/completions/mise.bash`, `share/fish/vendor_completions.d/mise.fish`, and `lib/mise/.disable-self-update`.

### U3. Wire the package into Home Manager and guard it

- **Goal:** point `programs.mise.package` at the pinned package, and fail a check when any configuration's `home.path` carries a different `mise`.
- **Requirements:** R1, R8; KTD6.
- **Dependencies:** U2.
- **Files:**
  - `home/h82/shell/shell.nix` (modify)
  - `tests/mise-settings.nix` (modify)
- **Approach:**
  1. Set `programs.mise.package` by importing `packages/mise.nix`, the way `home/h82/default.nix` imports `packages/claude-code.nix`.
  2. In `tests/mise-settings.nix`, pass the pinned package's store path into `checkHost` and fail when `readlink -f "$homePath/bin/mise"` differs from the pinned package's `bin/mise`.
  3. Keep the existing `or` fallbacks so that removing the declaration fails inside the builder rather than at evaluation, per `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.
  4. Extend the check's header comment with the new assertion.
- **Execution note:** before trusting the new assertion, mutation-test it. Revert `programs.mise.package` to `pkgs.mise` in a scratch copy and confirm the check fails. Read `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` first.
- **Patterns to follow:** the `claude-code` check in `flake.nix`, and the existing `checkHost` shape in `tests/mise-settings.nix`.
- **Test scenarios:**
  - Every configuration, bootstrap outputs included, passes with `bin/mise` resolving into the pinned package.
  - With `programs.mise.package` reverted to `pkgs.mise`, the check fails and names each configuration.
  - With `programs.mise` disabled, the check fails with "mise is not in home.path" rather than an evaluation error.
  - The existing `all_compile` source assertion still passes when run against the upstream binary.
- **Verification:** `nix build .#checks.x86_64-linux.mise-settings` passes, and the mutation run fails it.

### U4. Hourly bump in the update workflow

- **Goal:** have the `update-dependencies` workflow bump the mise pin and commit it under its own message.
- **Requirements:** R7; KTD1.
- **Dependencies:** U1, U2.
- **Files:**
  - `.github/workflows/update-dependencies.yml` (modify)
- **Approach:**
  1. Add a numbered step after the Claude Code step that runs `nix run .#mise-release -- --output packages/mise-release.json`.
  2. In "Push verified updates directly to main", add a block that commits `packages/mise-release.json` as `chore(packages): bump mise to $NEW_VER` before the catch-all commit and before the rebase.
- **Patterns to follow:** the claude-code blocks in the same workflow.
- **Test scenarios:**
  - `checks.update-dependencies-push-order` still passes, which exercises the push step's script against a sandboxed remote.
- **Verification:** `nix build .#checks.x86_64-linux.update-dependencies-push-order` passes, and the workflow diff adds exactly one resolve step and one commit block.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout |
| Checks | `nix flake check` | U1 fixture tests, U3 guard, push-order test, and every existing check |
| Package | `nix build .#mise` | R2, R3, R4 |
| Hosts | build every `nixosConfigurations.<name>.config.system.build.toplevel`, as `AGENTS.md` lists | the production and bootstrap outputs evaluate and build with the new package |
| Mutation | revert `programs.mise.package` in a scratch copy and rebuild `checks.x86_64-linux.mise-settings` | R8's assertion can fail |

---

## Definition of Done

- Every unit's Verification holds, and every gate in the Verification Contract passes.
- `packages/mise-release.json` pins the upstream release that is current when the implementation runs.
- No leftover experimental code, scratch pins, or unused helpers remain in the diff.
