---
title: Manage the macOS Dock - Plan
type: feat
date: 2026-10-28
topic: manage-macos-dock
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Manage the macOS Dock - Plan

## Goal Capsule

- **Objective:** After an `nr switch` that finds the declared apps installed, every macOS host's Dock shows the declared apps in the declared order, the Downloads folder on the right, no recent-apps section, and icon size 32, with no manual Dock setup.
- **Means:** a new nix-darwin module that sets `system.defaults.dock` from a shared list plus a per-host option (KTD1, KTD2).
- **Product authority:** The pinned-app list, folder, and the two managed appearance settings are settled below; Dock settings not named in R7 and R8 stay user-controlled.
- **Execution profile:** Lightweight; one module, one host line, one fixture line, and extensions to the two existing macOS checks.
- **Stop conditions:** Stop if nix-darwin's pinned `system.defaults.dock` cannot express an ordered list with Downloads's current stack settings, or if a check cannot read the materialized Dock writes from the system activation.
- **Who finishes:** `ce-work` implements and verifies; the user runs `nr switch` on the MacBook Pro.
- **Open blockers:** None.

---

## Product Contract

### Summary

Declare the Dock on macOS hosts: a shared, ordered list of pinned apps, Downloads as the only right-side folder, recent apps hidden, and tile size 32. Each host can add its own apps at a fixed place in that order, and the declared list replaces whatever the Dock held on every apply.

### Problem Frame

The MacBook Pro's Dock is the macOS default lineup plus apps pinned by hand, 31 items in all, and its only customized setting is a tile size of 32. None of this is recorded in the repository, so setting up another Mac, or recovering after the Dock is reset, means rebuilding it by hand. `modules/darwin/defaults.nix` already names the Dock as belonging under `system.defaults`, but sets nothing for it.

### Key Decisions

- **The declared list is authoritative and overwrites on every apply.** Apps pinned or removed by hand return to the declared list at the next `nr switch`; changing the Dock means changing the configuration. Governs R4. (session-settled: user-directed — chosen over applying the list only once on a new Mac: the configuration stays the single source of truth)
- **A shared list for every Mac, plus per-host additions.** Work apps installed outside this repository (Microsoft Outlook and Teams, installed through Company Portal) are added only by the host that has them. Governs R2, R3. (session-settled: user-directed — chosen over one list for every Mac and over a list only on this host)
- **Only recent apps and tile size are managed among appearance settings.** Position, auto-hide, magnification, minimize effect, and minimize-into-app-icon stay as the user sets them by hand. Governs R7, R8. (session-settled: user-directed — chosen over declaring those settings too)
- **The wide app set, without KakaoTalk and Telegram.** The user uses an iPhone and iCloud Mail, so Mail, Messages, Phone, FaceTime, and iPhone Mirroring are pinned instead of Outlook as the mail client. Governs R1. (session-settled: user-directed — chosen over a compact 15-app set and a minimal 7-app set)
- **Hot corners are out of scope.** They live in the Dock's preferences domain but were not chosen.

### Requirements

**Pinned apps**

- R1. The Dock's pinned apps, after Finder, appear in this order: Google Chrome, Mail, Messages, Phone, FaceTime, iPhone Mirroring, Calendar, Reminders, Notes, Photos, Ghostty, T3 Code (Nightly), VSCodium, Xcode, Claude, ChatGPT, Microsoft Outlook, Microsoft Teams, Discord, 1Password, System Settings.
- R2. Every macOS host gets the shared part of R1's list; Microsoft Outlook and Microsoft Teams are per-host additions that the MacBook Pro host declares.
- R3. A per-host addition lands at its position in R1's order, between ChatGPT and Discord, not at the end of the Dock.
- R4. Each apply replaces the pinned apps and right-side items with the declared ones, dropping anything pinned by hand.
- R5. T3 Code (Nightly) is pinned only on hosts with the `my.t3.desktop` trait enabled, because only those hosts install it.

**Right side**

- R6. Downloads is the only folder on the Dock's right side, beside the Trash.

**Appearance**

- R7. The Dock shows no recent-apps section.
- R8. The Dock's tile size is 32.
- R9. Dock settings not named in R7 and R8 are left undeclared, so hand-made changes to them survive an apply.

### Acceptance Examples

- AE1. **Covers R4.** **Given** the user pinned KakaoTalk by hand and removed Notes, **when** `nr switch` runs, **then** KakaoTalk is gone and Notes is back in its R1 position.
- AE2. **Covers R2, R3.** **Given** a second macOS host that declares no additions, **when** it applies, **then** its Dock shows R1's list without Outlook and Teams, and Discord follows ChatGPT directly.
- AE3. **Covers R5.** **Given** a macOS host without `my.t3.desktop`, **when** it applies, **then** VSCodium follows Ghostty directly.
- AE4. **Covers R9.** **Given** the user turned on auto-hide by hand, **when** `nr switch` runs, **then** auto-hide is still on.

### Scope Boundaries

- Hot corners, Dock position, auto-hide, magnification, minimize effect, and minimize-into-app-icon are not managed.
- Installing any app is out of scope; the Dock only pins apps that other configuration or Company Portal installs.
- Finder and the Trash are placed by macOS and are not part of the declared list.
- Considered and not built: a second Dock write and restart after the Homebrew and Mac App Store steps, so a new Mac's first apply shows apps those steps install. The gap is visible at once and the next `nr switch` closes it (KTD3); Outlook and Teams come from Company Portal, which no apply can order. Evidence that new Macs are set up often enough for the second apply to cost real time would change this call.

### Dependencies / Assumptions

- nix-darwin restarts the Dock on every apply whenever any Dock setting is declared, even when nothing changed. The user accepts the brief Dock flicker during `nr switch`.
- Outlook and Teams reach the MacBook Pro through Company Portal, not through this repository, so their presence is outside the configuration's control.

### Sources / Research

- `modules/darwin/defaults.nix`: the designated home for macOS system defaults; sets only automatic appearance switching today.
- nix-darwin `system.defaults.dock` offers `persistent-apps`, `persistent-others`, `show-recents`, and `tilesize`; its defaults-write step runs `killall Dock` whenever any Dock key is declared.
- `modules/shared/darwin-apps.nix`: casks shared by every macOS host, including Chrome, Claude, ChatGPT, Discord, Ghostty, and 1Password; Microsoft apps are absent.
- `home/h82/dev/vscodium.nix` and `home/h82/t3code.nix`: VSCodium and T3 Code (Nightly) install into `~/Applications/Home Manager Apps`, not `/Applications`.
- `modules/darwin/xcode.nix`: Xcode comes from the Mac App Store in a root step after Homebrew.

Product Contract preservation: Product Contract unchanged, except the Deferred to Planning question on not-yet-installed apps, which KTD3 resolves and which was removed from Outstanding Questions.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **A dedicated `modules/darwin/dock.nix`, imported by `modules/darwin/profile.nix`.** The Dock carries an ordered list, a per-host option, and a folder spec, which is more than one setting; a module of its own keeps `modules/darwin/defaults.nix` to one-line system defaults, and that file's comment is updated to point Dock settings at the new module. Governs R1, R5-R9.
- KTD2. **A per-host option `my.dock.hostApps`, declared in `modules/darwin/dock.nix`, holds app bundle paths inserted between ChatGPT and Discord.** nix-darwin's `persistent-apps` is a plain list, so a host cannot splice into its middle with `mkBefore`/`mkAfter`; the module builds the list as shared head, then `my.dock.hostApps`, then shared tail. Declaring it beside its only consumer follows `my.tlsInspectionCa.certificateFile` in `modules/darwin/tls-inspection-ca.nix`; it stays out of `modules/shared/host.nix` because Home Manager never reads it. Implements R2, R3.
- KTD3. **Accept whatever the Dock shows for a declared app that is not installed yet; build no filter.** nix-darwin writes the Dock defaults and restarts the Dock in its `userDefaults` step, before Homebrew and the Mac App Store steps (`activation-scripts.nix` order), so only a new Mac's first apply can meet a missing bundle. The next apply rewrites the full list (R4) and restarts the Dock with the bundle in place, so the gap closes without manual work. Filtering by bundle existence would need a runtime step that rewrites Dock preferences outside nix-darwin, which the request did not ask for and which would compete with nix-darwin's own write. Resolves the brainstorm's deferred question.
- KTD4. **App paths are absolute; Home Manager apps derive from `config.my.user.home`.** T3 Code (Nightly) and VSCodium live under `<home>/Applications/Home Manager Apps/` (Home Manager's darwin app directory), so the module builds those two paths from the host's account rather than a fixed user. Implements R1, R5.
- KTD5. **Downloads keeps its current stack presentation: sorted by date added, shown as a stack, opened as a fan.** That is what the user's Dock shows today (`arrangement = 2`, `displayas = 0`, `showas = 1`), and declaring it avoids changing how the folder looks while taking ownership of it. Its path derives from `config.my.user.home`. Implements R6.
- KTD6. **R9 is enforced by leaving the other `system.defaults.dock` options at their `null` default.** nix-darwin writes only non-null keys, so position, auto-hide, magnification, minimize effect, and minimize-into-app-icon are never written.

### Assumptions

- The app bundle names in R1 match the installed bundles: `Google Chrome.app`, `Ghostty.app`, `Xcode.app`, `Claude.app`, `ChatGPT.app`, `Discord.app`, `1Password.app`, `Microsoft Outlook.app`, and `Microsoft Teams.app` under `/Applications`; Mail, Messages, Phone, FaceTime, iPhone Mirroring, Calendar, Reminders, Notes, Photos, and System Settings under `/System/Applications`. Verified against the MacBook Pro's `/Applications` and `/System/Applications` on 2026-10-28.
- VSCodium is installed on every macOS host (`home/h82/dev/default.nix` imports it for every non-linux kind), so it is pinned unconditionally.

---

## Implementation Units

### U1. Declare the Dock in a new nix-darwin module

**Goal:** Every macOS host's activation writes the declared pinned apps, Downloads, `show-recents = false`, and `tilesize = 32`, and nothing else in the Dock domain.

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9; KTD1-KTD6.

**Dependencies:** None.

**Files:**

- Create `modules/darwin/dock.nix`.
- Modify `modules/darwin/profile.nix` (import the module).
- Modify `modules/darwin/defaults.nix` (comment points Dock settings at `dock.nix`).
- Test `tests/darwin-config.nix` (see U3).

**Approach:**

1. Declare `my.dock.hostApps` as a list of strings defaulting to `[ ]`, with a description naming its position between ChatGPT and Discord (KTD2).
2. Set `system.defaults.dock.persistent-apps` to the shared head (Chrome through ChatGPT, with T3 Code (Nightly) present only when `config.my.t3.desktop.enable`), then `config.my.dock.hostApps`, then the shared tail (Discord, 1Password, System Settings), per R1, R3, R5.
3. Set `persistent-others` to one Downloads folder entry with the KTD5 presentation, `show-recents = false`, and `tilesize = 32`.

**Patterns to follow:** `modules/darwin/tls-inspection-ca.nix` for a module-local `options.my.*` declaration; `modules/darwin/defaults.nix` for `system.defaults` style.

**Test scenarios:** covered in U3, which owns the checks for this unit's behavior.

**Verification:** The macOS fixture's `system.defaults.dock` evaluates to the expected list, and its system activation writes the Dock keys U3 asserts.

### U2. Add the MacBook Pro's work apps and the fixture's host app

**Goal:** The MacBook Pro pins Outlook and Teams between ChatGPT and Discord, and the macOS fixture exercises the same insertion point.

**Requirements:** R2, R3.

**Dependencies:** U1.

**Files:**

- Modify `hosts/MacBook-Pro-Mac17-9/default.nix` (set `my.dock.hostApps` to Outlook then Teams).
- Modify `tests/fixtures/hosts/magnolia/default.nix` (set `my.dock.hostApps` to one fixture app path, and note it in the file's header comment).

**Approach:** Use full `/Applications/...app` paths. The fixture's app is a made-up bundle path so a check can tell host apps from shared apps without naming a real host.

**Test expectation:** none -- configuration values whose effect U3 asserts.

**Verification:** Both hosts evaluate; U3's order assertions pass on the fixture.

### U3. Guard the Dock in the macOS checks

**Goal:** The Linux-evaluated `darwin-config` check and the macOS-built `darwin-outputs` check fail when the Dock list, its order, the host-app position, Downloads, or the two appearance keys drift, or when an unmanaged Dock key is written.

**Requirements:** R1, R3, R5, R6, R7, R8, R9.

**Dependencies:** U1, U2.

**Files:**

- Modify `tests/darwin-config.nix` (option-level assertions, header list).
- Modify `tests/darwin-outputs.nix` (materialized-activation assertions, header list).

**Approach:**

- In `darwin-config`, compare the fixture's `persistent-apps` paths, in order, to the expected list built from the fixture's own `my.user.home` and `my.dock.hostApps`, and evaluate the fixture through `extendModules` with `my.t3.desktop.enable = lib.mkForce false` for the trait-off case, following the existing `extendModules` use in that file.
- In `darwin-outputs`, read the `defaults write com.apple.dock` lines from the built system's `activate` script, the way the automatic-appearance assertion reads its multi-line plist, and assert the app paths appear in the expected order, `show-recents` is false, `tilesize` is 32, `persistent-others` holds only the fixture's Downloads path, and no `autohide`, `orientation`, `magnification`, `mineffect`, or `minimize-to-application` write exists.

**Execution note:** Before trusting each new assertion, mutate the module (drop an app, swap two apps, move the host app to the end, set `show-recents = true`, set `autohide = true`) and confirm the check fails, per the repository's mutation-testing learnings.

**Test scenarios:**

- Covers AE2. The fixture's pinned list equals R1's shared order with the fixture host app between ChatGPT and Discord.
- Covers AE3. With `my.t3.desktop` forced off, the list has no T3 Code (Nightly) entry and VSCodium directly follows Ghostty.
- T3 Code (Nightly) and VSCodium paths start with the fixture's `/Users/tester/Applications/Home Manager Apps/`.
- `persistent-others` is exactly one Downloads folder under `/Users/tester/Downloads` with date-added sorting, stack display, and fan view.
- The built activation writes `show-recents` false and `tilesize` 32 in the Dock domain.
- Covers AE4. The built activation writes none of the unmanaged Dock keys listed in the Approach.
- Covers AE1. The built activation writes the full `persistent-apps` array, so an apply replaces hand-made pins.

**Verification:** Both checks pass on the fixture and each listed mutation makes at least one of them fail.

### U4. Document the Dock module

**Goal:** `AGENTS.md` describes the new module in its `modules/darwin/` list.

**Requirements:** R1, R2.

**Dependencies:** U1.

**Files:** Modify `AGENTS.md`.

**Approach:** Add `dock.nix` to the `modules/darwin/` bullet: the shared ordered pinned apps, `my.dock.hostApps` inserted between ChatGPT and Discord, Downloads on the right, recent apps off, tile size 32, and every other Dock key left to the user.

**Test expectation:** none -- documentation; the `agent-instructions` check reads `AGENTS.md` and must still pass.

**Verification:** `AGENTS.md` lint passes and `agent-instructions` still builds.

---

## Verification Contract

| Gate | Command or evidence | Applies to |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` on Linux CI (`formatter.aarch64-darwin` is absent) | U1-U3 |
| Markdown lint | pre-commit `mise run lint-staged-markdown` | U4, this plan |
| Linux evaluation of the macOS fixture | `checks.x86_64-linux.darwin-config`, via `nix derivation show` on macOS or CI's `check-shards` | U1-U3 |
| macOS build | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` and every `darwinConfigurations.<host>.system` on this Mac | U1-U3 |
| Flake evaluation | `nix flake check --no-build` | all |
| Instructions consumer | `checks.x86_64-linux.agent-instructions` in CI | U4 |
| Mutation evidence | each U3 mutation fails a check | U3 |

Hardware evidence, the MacBook Pro's Dock after `nr switch`, is the user's step and is reported separately from these checks.

## Definition of Done

- U1-U4 are implemented and every gate above passes locally or is recorded as deferred to CI.
- Each U3 mutation was run and made a check fail; the mutations are reverted.
- No unused option, dead helper, or abandoned-attempt code remains in the diff.
