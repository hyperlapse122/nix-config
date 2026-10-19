---
title: Grok Bot App - Plan
type: feat
date: 2026-10-19
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Grok Bot App - Plan

## Goal Capsule

- **Objective:** the user can open xAI's Grok Bot desktop app on every Linux host (NixOS and non-NixOS) and every macOS host this flake manages, and the installed version keeps up with xAI's stable channel without hand edits.
- **Means:** a pinned Nix package built from xAI's Linux `.deb` for both Linux architectures (KTD1, KTD2), and the Homebrew `grok-bot` cask on macOS (KTD4).
- **Authority:** this plan's Requirements and KTDs; `AGENTS.md` for repository conventions and the shipping checks.
- **Execution profile:** one branch, one pull request, units landed in U-ID order.
- **Stop conditions:** stop and report when the `.deb` cannot be turned into a package whose binary starts on x86_64-linux, or when the download feed stops returning a version and `debUrl` for both Linux architectures.
- **Finishing:** `ce-work` implements, runs the U1 smoke launch in its own build environment, and verifies with the flake checks and builds. Opening the app on the user's real NixOS, non-NixOS, and macOS machines stays with the user.

---

## Product Contract

### Summary

Install Grok Bot on all Linux and macOS hosts. Linux gets a Nix package from xAI's `.deb`, pinned per architecture and bumped by the dependency-update workflow. macOS gets the `grok-bot` cask through the existing Homebrew mapping.

### Problem Frame

Grok Bot (<https://x.ai/bot>) is xAI's desktop app for "AI teammates that work across your apps and tools". The user wants it on every machine the flake manages. Today no host installs it, and a hand install on a NixOS host does not survive a rebuild. xAI ships it for macOS (`.dmg`, also the Homebrew `grok-bot` cask, served from `downloads.cursor.com/sand/...`) and for Linux on x64 and arm64 (`.deb`, `.rpm`, AppImage, served from `downloads.cursor.com/grokbot/...`).

### Requirements

**Installation**

- R1. Every NixOS host's user environment has a `grok-bot` executable and a desktop entry that launches Grok Bot.
- R2. Every non-NixOS Linux host's user environment has the same package and desktop entry, on x86_64-linux and aarch64-linux.
- R3. Every macOS host installs the `grok-bot` Homebrew cask.

**Pinning and updates**

- R4. The Linux package is pinned to one version with a per-architecture URL and hash, the build fails on a hash mismatch, and the running app does not replace itself with an unpinned build.
- R5. The dependency-update workflow bumps the Linux pin to xAI's current stable release, never to an older one, and a failed lookup keeps the current pin without blocking the other updates.

### Scope Boundaries

- Desktop configuration on non-NixOS Linux hosts stays out of scope (per `AGENTS.md`); they get the package and its desktop entry file, nothing that edits their desktop.
- Autostart at login is not added on any host kind.
- Windows is out of scope; the flake manages no Windows host.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Package the Linux `.deb`, not the AppImage.** The stable download feed (`https://api2.cursor.sh/updates/api/download/stable/linux-{x64,arm64}/sand`) returns `version` and `debUrl` for each architecture. A `.deb` install is managed by its package manager and does not replace itself, so the pin stays the only updater (R4). The AppImage offers in-app updates that cannot land in the read-only Nix store. The package unpacks with `dpkg-deb` and patches with `autoPatchelfHook`, as `packages/claude-desktop.nix` and `packages/wifiman-desktop.nix` do.
- KTD2. **Pin in `packages/grok-bot-release.json` with a `platforms` map**, keyed by `x86_64-linux` and `aarch64-linux`, each holding `url` and SRI `hash`, the same shape as `packages/grok-build-release.json`. One `version` covers both architectures.
- KTD3. **Install on every Linux host kind, outside the `gui` gate.** `home/h82/default.nix` gates GUI apps on `nixos`; Grok Bot instead goes in for `hostKind != "darwin"` so non-NixOS Linux hosts get it too (R2). The request names all Linux hosts, which outranks the repository's NixOS-only default for GUI apps. The cost is the Electron closure on non-NixOS hosts, including ones without a display server.
- KTD4. **macOS uses the `grok-bot` cask through `modules/shared/darwin-apps.nix`.** The `.app` is code-signed and self-updating, and `homebrew.onActivation.upgrade` already updates listed casks. The entry goes in `apps` as `grok-bot.cask = "grok-bot"`, and the header comment widens to say `apps` also maps packages every Linux host has that a Mac gets as a cask. `darwin-config`'s derived set does not cover a package non-NixOS hosts also have, so the check pins this entry by value, as it does for `telegram-desktop` (U3).
- KTD5. **The release helper is a Python script in `scripts/grok-bot-release`**, following `scripts/wifiman-desktop-release` and `scripts/grok-build-release`. It has an overridable fetch command (`GROK_BOT_RELEASE_FETCH`) and an overridable prefetch command, because the feed publishes no hash. It takes `--output` and `--dry-run`. It refuses when the two architectures disagree on version or a URL leaves `https://downloads.cursor.com/grokbot/`. It leaves the pin untouched when the resolved version is not newer than the current one.

### Assumptions

- "All Linux hosts" includes non-NixOS Linux hosts, which today exist only as the two non-NixOS check fixtures under `tests/fixtures/hosts/`.
- The `.deb` ships a `.desktop` file and hicolor icons under `usr/share/`; U1 reads the exact names from the unpacked archive.
- The `.deb` build does not offer in-app updates; the U1 smoke launch confirms it.

### Risks & Dependencies

- The feed lives on Cursor's update API (`api2.cursor.sh`, product `sand`), which xAI uses for Grok Bot. A product rename would break the helper; R5's keep-the-pin fallback contains it to a `::warning` on each scheduled run, which someone has to read.
- Once xAI retires a build, the app may demand an update it cannot install; a timely pin bump is the remedy, and a failed helper delays it.
- On a non-NixOS host, a Nix-built Electron app depends on the host's GPU drivers and display server. The fixtures prove the package and desktop entry are installed, not that the app starts there.
- The aarch64-linux package is only buildable on an aarch64 builder; `grok-bot-sources` fetches its `.deb` on x86_64 so a bad hash fails before the pin lands, and CI's arm runners build the aarch64 fixture.
- macOS and Linux can run different versions while the Homebrew cask lags or leads xAI's feed.

---

## Implementation Units

### U1. Pinned Grok Bot package for Linux

- **Goal:** a `grok-bot` derivation for x86_64-linux and aarch64-linux built from the pinned `.deb`.
- **Requirements:** R1, R2, R4; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `packages/grok-bot.nix` (new), `packages/grok-bot-release.json` (new), `flake.nix` (expose `packages.<system>.grok-bot`).
- **Approach:**
  1. Seed the pin from the feed's current answer (0.71.2, both architectures), hashing each `.deb` with `nix store prefetch-file`.
  2. Select the platform entry by `stdenv.hostPlatform.system`, throwing a readable error for an unpinned system, as `packages/grok-build.nix` does.
  3. Unpack with `dpkg-deb`, patch with `autoPatchelfHook` and the Electron runtime libraries `packages/claude-desktop.nix` lists, and expose `bin/grok-bot`.
  4. Install the `.desktop` file with `Exec=` pointing at `grok-bot`, and the icons under `share/`.
  5. Set `meta.platforms` to the two Linux systems, `license = unfree`, `mainProgram = "grok-bot"`.
- **Execution note:** this is packaging; prove it by building on x86_64-linux and running a smoke launch of the built binary in the build environment that reaches its window or sign-in screen, rather than by unit tests.
- **Patterns to follow:** `packages/claude-desktop.nix` for an Electron `.deb`; `packages/grok-build.nix` for per-system pin selection.
- **Test scenarios:** covered by the U4 check (executable and desktop entry present, `Exec=` names the package's `bin/grok-bot`).
- **Verification:** `nix build .#grok-bot` succeeds on x86_64-linux, the smoke launch starts with no missing-library error, and it shows no update download or update prompt. If it does, U1 disables the updater in the wrapper before continuing.

### U2. Release helper and its tests

- **Goal:** `nix run .#grok-bot-release -- --output packages/grok-bot-release.json` rewrites the pin from xAI's stable channel.
- **Requirements:** R4, R5; KTD5.
- **Dependencies:** U1 (the pin file and its shape).
- **Files:** `scripts/grok-bot-release` (new), `tests/test_grok_bot_release.py` (new), `packages/agent-tools.nix` (add `grokBotRelease` as a `pythonHelper`), `flake.nix` (package `grok-bot-release` and a `pythonScriptCheck` named `grok-bot-release`).
- **Approach:** query the feed once per architecture, validate, prefetch each `debUrl`, and write the KTD2 shape.
- **Patterns to follow:** `scripts/wifiman-desktop-release` and `tests/test_wifiman_desktop_release.py` (fetch and prefetch overrides, `Failure` messages); `scripts/grok-build-release` (multi-platform shape, `version_tuple`).
- **Test scenarios:**
  - Both architectures answer 0.71.2 with valid `debUrl`s: the written file holds version 0.71.2 and the two SRI hashes from the prefetch fixtures.
  - x64 answers 0.71.2 and arm64 answers 0.71.1: the helper exits non-zero naming both versions and leaves the output file untouched.
  - A `debUrl` outside `https://downloads.cursor.com/grokbot/`: refused, file untouched.
  - The feed returns an error object with no `version` (the shape `api2.cursor.sh` gives for an unknown platform): refused with a readable message.
  - The fetch command exits non-zero: refused, naming the URL.
  - The prefetch command fails or prints no hash: refused, file untouched.
  - The current pin is 0.72.0 and the feed answers 0.71.2: the pin is left untouched.
  - The current pin already equals the feed's answer: exits 0 reporting it is up to date, file unchanged.
  - `--dry-run` prints the resolved JSON and writes nothing.
- **Verification:** the `grok-bot-release` check passes.

### U3. Install on every Linux and macOS host

- **Goal:** Linux user environments carry the package and macOS hosts install the cask.
- **Requirements:** R1, R2, R3; KTD3, KTD4.
- **Dependencies:** U1.
- **Files:** `home/h82/default.nix`, `modules/shared/darwin-apps.nix`, `tests/darwin-config.nix`, `docs/adding-a-host.md`.
- **Approach:**
  1. Add the package to `home.packages` under `lib.optionals (hostKind != "darwin")`, beside the other imported packages.
  2. Add `grok-bot.cask = "grok-bot"` to `apps` and update the header comment (KTD4).
  3. In `tests/darwin-config.nix`, add `"grok-bot"` to the casks it pins by name and assert `mapping.apps.grok-bot or null == { cask = "grok-bot"; }`, as for `telegram-desktop`.
  4. Update the sentence in `docs/adding-a-host.md` that says a macOS decision is required only for a package a non-NixOS host lacks.
  5. Leave `grok-bot` out of the `guiPackages` list in `tests/non-nixos-outputs.nix`, which names the NixOS desktop's GUI packages.
- **Patterns to follow:** the `claude-desktop` line in `home/h82/default.nix`; the `telegram-desktop` assertions in `tests/darwin-config.nix`.
- **Test scenarios:**
  - `darwin-config`: the macOS fixture's casks include `grok-bot`.
  - Mutation: delete the `grok-bot` entry from `apps`: `darwin-config` fails.
  - Mutation: move it to `darwinOnly`: `darwin-config` fails on the by-value assertion.
- **Verification:** `darwin-config` and `non-nixos-outputs` pass, and every Linux fixture user environment lists `grok-bot`.

### U4. Checks for every Linux user and both pinned sources

- **Goal:** a flake check `grok-bot` that fails when any Linux user environment lacks the package, its executable, or a desktop entry that launches it, and a check `grok-bot-sources` that fetches every pinned `.deb`.
- **Requirements:** R1, R2, R4.
- **Dependencies:** U1, U3.
- **Files:** `flake.nix` (both checks).
- **Approach:**
  1. `grok-bot`: run `forEveryUser` with `assertUserPackage { pname = "grok-bot"; executables = [ "grok-bot" ]; desktopEntries = [ <name found in U1> ]; }`, and assert the entry's `Exec=` names that package's `bin/grok-bot`, as the `t3code` check does for `t3code.desktop`. Iterating users rather than configurations is what reaches the non-NixOS fixtures (R2).
  2. `grok-bot-sources`: a `linkFarm` that fetches every `platforms` entry of `packages/grok-bot-release.json`, as `opencode-sources` does.
  3. Both stay in the light shards. Neither reads a host generation; `grok-bot` reads user package lists, as the `claude-desktop` and `grok-build` checks do.
  4. Name fixtures in failure output only through `entry.name`, never as literals, so `host-name-guard` stays green.
- **Patterns to follow:** the `claude-desktop`, `t3code`, and `opencode-sources` checks in `flake.nix`; the mutation-testing learnings under `.compound-engineering/artifacts/solutions/best-practices/`.
- **Test scenarios:**
  - All Linux users have the package: `grok-bot` passes.
  - Mutation: gate the package back to NixOS only (`gui`): `grok-bot` fails naming a non-NixOS fixture.
  - Mutation: drop the desktop entry install from U1: `grok-bot` fails naming the entry.
  - Mutation: point the entry's `Exec=` at another path: `grok-bot` fails.
  - Mutation: corrupt the aarch64-linux hash in the pin: `grok-bot-sources` fails on x86_64.
- **Verification:** `nix flake check` passes, and each mutation above turns its check red before being reverted.

### U5. Dependency-update workflow and docs

- **Goal:** the scheduled update bumps Grok Bot, its reconcile test covers the new step, and the docs say where the app comes from.
- **Requirements:** R5.
- **Dependencies:** U2.
- **Files:** `.github/workflows/update-dependencies.yml`, `tests/update-dependencies-reconcile.sh`, `docs/provisioning.md`, `docs/macos.md`.
- **Approach:**
  1. Add a numbered step that runs `grok-bot-release` with the keep-the-pin fallback and `::warning`, as the WiFiman and Grok Build steps do.
  2. Add the matching `chore(packages): bump grok-bot to $NEW_VER` commit block.
  3. Seed `packages/grok-bot-release.json` in `tests/update-dependencies-reconcile.sh` and cover the new step and commit block beside `grok-build-release`.
  4. Add a paragraph to `docs/provisioning.md` naming the Linux package and its pin file, and a line to `docs/macos.md` naming the cask.
- **Patterns to follow:** the Grok Build step, commit block, and reconcile-test cases.
- **Test scenarios:**
  - Reconcile test: a bumped `packages/grok-bot-release.json` produces one `chore(packages): bump grok-bot to <version>` commit.
  - Reconcile test: a failing `grok-bot-release` restores the pin and the other updates still commit.
- **Verification:** the reconcile test's check passes, and the step names the same output path U2 writes.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout |
| Checks | `nix flake check` | `grok-bot`, `grok-bot-sources`, `grok-bot-release`, `darwin-config`, `non-nixos-outputs`, the reconcile test, `host-name-guard` |
| Package | `nix build --no-link .#grok-bot` plus the U1 smoke launch | R1, R4 on x86_64-linux |
| Hosts | the `AGENTS.md` loop over `nixosConfigurations`, `homeConfigurations`, `systemConfigs` | every Linux output still builds |
| macOS | `nix build --no-link .#darwinConfigurations.<host>.system` on a Mac, or CI's `build-darwin` | R3 |
| aarch64 | CI's arm runners | R2 on aarch64-linux |

VM tests are unaffected by a user package and need not be rebuilt for this change unless the host builds fail.

## Definition of Done

- Every unit's Verification holds, and the U3 and U4 mutations were each seen to fail.
- Every Verification Contract gate passes locally or is named as left to CI.
- No experimental or abandoned packaging code remains in the diff.
