---
title: OpenCode v2 - Plan
type: feat
date: 2026-10-17
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# OpenCode v2 - Plan

## Goal Capsule

- **Objective:** T3 Code's OpenCode provider runs at full support, which needs OpenCode 2.0.18 or newer; every host now gets 1.19.3, which T3 Code flags as limited.
- **Means:** Pin OpenCode to the v2 per-platform npm packages (KTD1), re-point `opencode-release` at the npm registry so the dependency workflow keeps bumping it (KTD2), move the declared update setting to v2's native key (KTD4), turn off v2's shared background server so each run keeps the wrapper's environment (KTD6), and keep every existing guard working against the v2 binary (KTD3, KTD5).
- **Authority:** The user's request ("use OpenCode v2") and the settled decision below. `AGENTS.md` outranks this plan on repository conventions.
- **Stop conditions:** Stop and report if the v2 glibc Linux build cannot run after the `autoPatchelfHook` patching v1 already uses, if the wrapped v2 binary loads a project `opencode.json` despite `OPENCODE_DISABLE_PROJECT_CONFIG`, or if no probe the sandbox can run reports project config (the guard would be blind).
- **Execution profile:** Nix packaging, a Python resolver and its tests, Home Manager settings, Nix checks, and docs. Build and check evidence is the primary proof.
- **Finish and ship:** `ce-work` implements and verifies locally; the caller (`lfg`) reviews, commits, and opens the PR.

---

## Product Contract

### Summary

Install OpenCode v2 (2.0.31 today) on every host kind in place of 1.19.3, from the official `@opencode/cli-<platform>` npm packages. The dependency workflow keeps bumping the pin. The wrapper's API key handling and its three isolation switches stay as they are.

### Problem Frame

T3 Code's OpenCode provider shows "Limited support ... Use >=2.0.18" for the installed 1.19.3. Upstream ships v2 only through npm: GitHub's `releases/latest` for `anomalyco/opencode` is still v1.19.3, and the `v2.0.x` git tags have no GitHub release objects, so the current resolver can never reach v2. v2 publishes `@opencode/cli` from the same repository and maintainer as the 1.x `opencode-ai` package, with one platform package per system holding a single Bun-compiled `bin/opencode`.

### Key Decisions

- **Use OpenCode v2 (>= 2.0.18).** Governs R1, R2. (session-settled: user-directed — chosen over staying on the 1.x line (1.19.3): T3 Code needs >= 2.0.18 for full support)

### Requirements

**Package and pin**

- R1. `opencode` on `PATH` on every host kind runs OpenCode v2 from `packages/opencode-release.json`, for `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`; evaluation still fails for any other system.
- R2. `scripts/opencode-release` resolves the newest stable v2 release from the npm registry and writes the pin. It exits non-zero and leaves the pin unchanged when the latest version is not a plain version, when the release is deprecated, or when any pinned platform package or its sha512 integrity is missing or inconsistent. It exits zero without rewriting when the resolved version is not strictly newer. `update-dependencies.yml` keeps running it and committing `chore(packages): bump opencode to <version>`.

**Isolation and configuration**

- R3. OpenCode never updates itself outside the store, loads no project `opencode.json` or `.opencode/`, and reads nothing from `.claude`, under any config T3 Code supplies.
- R4. `~/.config/opencode/opencode.json` carries `model = "opencode/glm-5.3-flash-free"`, `update = "disable"`, and `share = "disabled"`, and activation drops the legacy `autoupdate` key.
- R5. The API key path is unchanged: the wrapper exports `OPENCODE_API_KEY` from the key file unless the caller exported one, and a rotated key takes effect on the next `opencode` run.
- R6. Every `opencode` command runs its own server with the environment the wrapper gave it; no shared background server outlives a command or carries an earlier run's key, switches, or version.

### Scope Boundaries

- No change to the T3 Code instance declaration in `home/h82/t3code.nix`; it names the `opencode` on `PATH`.
- No change to the review-peer model in `home/h82/agents/opencode-model.nix`.
- The musl and baseline (non-AVX2) v2 builds stay unpinned, as with v1.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Pin the `@opencode/cli-<platform>` npm tarballs.** Each pinned platform records its npm package name, the registry tarball `url`, and the registry's `sha512` SRI `hash`; `packages/opencode.nix` fetches `pin.url`, as the Antigravity CLI pin does. The tarball unpacks to `package/bin/opencode`, so the source root moves to `package` and the macOS `unzip` input goes away. Platform packages: `x86_64-linux` → `@opencode/cli-linux-x64`, `aarch64-linux` → `@opencode/cli-linux-arm64`, `aarch64-darwin` → `@opencode/cli-darwin-arm64`. The glibc builds are still the ones patched with `autoPatchelfHook`, for the reason `packages/opencode.nix` already gives. Implements R1 under the settled v2 decision.
- KTD2. **Resolve from the registry's `latest` manifest.** The resolver reads `https://registry.npmjs.org/@opencode/cli/latest` (the full packument is very large, carrying thousands of dev builds), takes its `version`, requires each pinned platform package in its `optionalDependencies` at exactly that version, then reads `https://registry.npmjs.org/@opencode/cli-<platform>/<version>`. It refuses when the version fails `VERSION_PATTERN` (which rejects `0.0.0-dev-*` and `-beta` builds), when either manifest has a `deprecated` field, when a platform manifest's `name` or `version` differs from the request, when `dist.integrity` is not a single `sha512-` SRI of 64 bytes, or when `dist.tarball` is not under `https://registry.npmjs.org/`. The strictly-newer gate stays, so the first run bumps 1.19.3 to 2.0.31 and later runs never downgrade. The fetch override (`OPENCODE_RELEASE_FETCH`) stays so tests drive fixtures; `--source-url` becomes the registry base URL.
- KTD3. **Keep the wrapper unchanged.** v2.0.31 still reads all three switches: `OPENCODE_DISABLE_AUTOUPDATE` in `packages/cli/src/services/updater.ts`, and `OPENCODE_DISABLE_PROJECT_CONFIG` and `OPENCODE_DISABLE_CLAUDE_CODE` in `packages/cli/src/server-process.ts`, where the server builds its config. v2 runs a detached background server spawned from the bare binary with the spawning process's environment, so the wrapper's exports reach the server too. The `opencode` flake check's switch and version assertions stay as written.
- KTD4. **Declare `update = "disable"` and remove `autoupdate`.** v2's schema replaces `autoupdate` with `update` (`disable`/`notify`/`auto`); it still migrates `autoupdate = false`, but the native key is what the schema documents. `home/h82/agents/opencode.nix` sets `update` and passes `remove = [ "autoupdate" ]` to `agent-settings`, so an existing file loses the legacy key instead of carrying both.
- KTD5. **Run the project-config probe with the service disabled in a private config home.** v2's `debug config` asks a server for the configuration sources, and its handler calls `ServerConnection.resolve()` with no arguments, so a `--standalone` flag never reaches it. `resolve()` takes the standalone path when `$XDG_CONFIG_HOME/opencode/service.json` holds `disabled: true`; otherwise it spawns the detached managed server on a fixed port, which would outlive the command in the build sandbox. The check points `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_DATA_HOME` at temp directories, writes `{"disabled": true}` there, and runs plain `debug config`. The bare-binary canary assertion stays, so a probe that stops reporting project config still fails as blind.
- KTD6. **Disable v2's managed background server for the user.** By default v2 clients (the TUI, `run`, `models`, `debug`, `mcp`, and others) connect to one detached server that the first client spawned with its own environment, and later clients reuse it whatever they export (`packages/client/src/service-contender.ts`). That breaks R5 for a caller-exported key and for a rotated key file, and after a pin bump `run` keeps talking to the old version because it ignores version mismatches. `home/h82/agents/opencode.nix` therefore merges `disabled = true` into `~/.config/opencode/service.json` with the same `agent-settings` merger, which writes it at mode 0600 and leaves the service's other keys as OpenCode wrote them. `ServerConnection.resolve()` then starts a server per command that inherits the wrapper's environment and stops on exit. `serve` and `acp`, which T3 Code can use, already run their own server and are unaffected. Implements R6, and keeps R3 and R5 true on every client path.

### Assumptions

- `opencode --version` on the v2 binary prints the plain version, so `versionCheckHook` passes unchanged; `ce-work` confirms it in the build.
- The Nix build sandbox lets the standalone server bind a loopback port. On macOS the `opencode-wrapper` check may need `__darwinAllowLocalNetworking = true`; add it only if the darwin build fails without it.
- The v2 glibc build's runtime needs match v1's (`stdenv.cc.cc.lib` plus the loader patch). `ce-work` confirms it on an x86_64-linux build.

### Risks

| Risk | Mitigation |
| --- | --- |
| A shared background server would fix the first client's key, switches, and version for every later client. | KTD6 disables it, so each command starts its own server. v1 has no background server, so no stale one exists when the first v2 generation activates. |
| Someone re-enables the service with `opencode service set disabled false`. | Activation reasserts `disabled = true` on the next generation, as it does the other declared keys; docs say why it is off. |
| npm serves a tampered tarball. | The pin stores the registry's sha512 SRI, and `fetchurl` verifies it, the same trust root the GitHub digests gave v1. |

---

## Implementation Units

### U1. npm resolver and its tests

- **Goal:** `scripts/opencode-release` resolves v2 from the npm registry per KTD2 and writes the KTD1 pin shape.
- **Requirements:** R2.
- **Files:** `scripts/opencode-release`, `tests/test_opencode_release.py`, `packages/agent-tools.nix` (comment only).
- **Patterns:** The current resolver's `Failure`, `fetch`, strictly-newer gate, and `--dry-run`; `scripts/antigravity-cli-release` for a pin with per-platform `url` and `sha512` `hash`.
- **Test scenarios:**
  - A `latest` manifest for 2.0.31 with all three platform manifests writes a pin with version `2.0.31` and, for each system, the package name, the registry tarball URL, and the `sha512-` hash taken verbatim from `dist.integrity`.
  - A pinned 1.19.3 is replaced by 2.0.31; a pinned 2.0.31 is left unchanged with exit 0; a pinned 2.0.40 is not downgraded.
  - `latest` version `0.0.0-dev-19274` or `2.1.0-beta.1` exits non-zero and leaves the pin byte-identical.
  - A `deprecated` field on the `latest` or a platform manifest exits non-zero.
  - `optionalDependencies` missing `@opencode/cli-linux-arm64`, or listing it at another version, exits non-zero.
  - A platform manifest whose `version` or `name` differs from the request, whose integrity is `sha1-...` or a truncated `sha512-`, or whose tarball host is not `registry.npmjs.org`, exits non-zero.
  - A fetch failure or non-JSON body exits non-zero with a readable message.
- **Verification:** `nix build --no-link .#checks.<system>.opencode-release` passes.

### U2. Package and pin on v2

- **Goal:** `packages/opencode.nix` installs the v2 binary from the KTD1 pin on every pinned system.
- **Requirements:** R1, R5.
- **Dependencies:** U1 (pin shape).
- **Files:** `packages/opencode-release.json` (regenerated by U1's resolver against the live registry), `packages/opencode.nix`, `flake.nix` (`opencode-sources` fetches each pinned platform's `url` and `hash`; its comment).
- **Approach:** `src` uses `pin.url` and `pin.hash`; `sourceRoot = "package"`; the binary is installed from `bin/opencode`; drop `unzip`. Keep `dontStrip`, `autoPatchelfHook` on Linux, the wrapper substitution, and `versionCheckHook`.
- **Test scenarios:** Test expectation: covered by existing checks — `opencode-sources` fetches every platform's tarball against its hash; the `opencode` check asserts the built version equals the pin and the wrapper lines are present; `versionCheckHook` runs `opencode --version`.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.opencode-sources`, `.#opencode` on this Mac, and the `opencode` check pass.

### U3. Project-config probe on v2

- **Goal:** The `opencode-wrapper` check proves the wrapped v2 binary keeps a checkout's `opencode.json` out, per KTD5.
- **Requirements:** R3.
- **Dependencies:** U2.
- **Files:** `flake.nix` (`opencode-wrapper` check), `tests/opencode.sh` if it asserts anything v1-specific.
- **Approach:** Before both `debug config` probes, point the XDG config, state, and data homes at temp directories and write `{"disabled": true}` to the config home's `opencode/service.json` (KTD5). Keep the bare-binary canary assertion first, so a blind probe fails.
- **Test scenarios:**
  - The bare binary's `debug config` in a directory holding `{"username": "canary-project-config"}` reports the canary.
  - The wrapped binary's same probe does not report it.
  - No OpenCode process is left running after the probes (the managed server was never spawned).
- **Verification:** `nix build --no-link .#checks.<system>.opencode-wrapper` passes on this Mac and on x86_64-linux. Mutation: dropping `export OPENCODE_DISABLE_PROJECT_CONFIG=true` from `scripts/opencode` makes the check fail.

### U4. Declared settings

- **Goal:** OpenCode's user config uses v2's `update` key per KTD4, and its service config turns the managed server off per KTD6.
- **Requirements:** R4, R6.
- **Files:** `home/h82/agents/opencode.nix`, `tests/opencode.nix`.
- **Test scenarios:**
  - A file holding `autoupdate = true`, `model = "anthropic/claude-sonnet"`, `share = "auto"`, and an unrelated key ends with the declared `model`, `update = "disable"`, `share = "disabled"`, no `autoupdate`, and the unrelated key intact.
  - A missing file is created with exactly the declared keys and `$schema`.
  - A `service.json` holding `disabled = false`, a `password`, and a `port` ends with `disabled = true`, the same `password` and `port`, and mode 0600.
  - A missing `service.json` is created holding only `disabled = true`, at mode 0600.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.opencode-settings` passes (evaluated through derivation inputs on macOS if it is Linux-only).

### U5. Docs and comments

- **Goal:** Docs describe the npm source, the `update` key, and why v2's background server is off.
- **Requirements:** R1, R2, R4, R6.
- **Files:** `docs/provisioning.md` (OpenCode section), `docs/verification.md` (OpenCode items), `.github/workflows/update-dependencies.yml` (step 12 comment).
- **Approach:** Replace "prebuilt releases" with the `@opencode/cli-<platform>` npm packages and why (v2 has no GitHub releases); `autoupdate = false` with `update = "disable"`; add the declared `service.json` `disabled = true` and its reason (a shared server would keep the first run's key, switches, and version). Add a verification item: after activation, `~/.config/opencode/service.json` holds `disabled = true`, and `opencode service status` reports no running server.
- **Test scenarios:** Test expectation: none -- documentation only; `markdownlint-cli2` via the pre-commit hook.

---

## Verification Contract

| Check | Command | Units |
| --- | --- | --- |
| Resolver tests | `nix build --no-link .#checks.aarch64-darwin.opencode-release` | U1 |
| Live resolve | `nix run .#opencode-release -- --output packages/opencode-release.json` | U1, U2 |
| Package builds | `nix build --no-link .#opencode` | U2 |
| Pin fetch, all platforms | `nix build --no-link .#checks.x86_64-linux.opencode-sources` (needs a Linux builder; otherwise CI) | U2 |
| Wrapper and probe | `nix build --no-link .#checks.aarch64-darwin.opencode-wrapper` | U3 |
| Wrapper and probe, Linux | `nix build --no-link .#checks.x86_64-linux.opencode-wrapper` (needs a Linux builder; otherwise CI) | U3 |
| Settings merge | `opencode-settings` check | U4 |
| Darwin host | `nix build --no-link .#darwinConfigurations.<host>.system` | U2, U4 |
| Flake evaluation | `nix flake check --no-build` and `nix fmt -- --ci` | all |

Linux-only outputs that this Mac cannot build are left to CI's `check-shards` and host jobs.

## Definition of Done

- `packages/opencode-release.json` pins 2.0.31 (or newer) with npm tarball URLs and sha512 hashes for all three systems.
- The built `opencode` reports the pinned v2 version, and every check in the Verification Contract that this machine can run passes.
- Activation writes `disabled = true` into `~/.config/opencode/service.json`, and the settings check proves it.
- Docs match the npm source, the `update` key, and the disabled background server.
