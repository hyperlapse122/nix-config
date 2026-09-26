---
title: Agent Browser Runtime Dependencies - Plan
type: feat
date: 2026-09-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Agent Browser Runtime Dependencies - Plan

## Goal Capsule

- **Objective:** On both hosts, a Chrome for Testing build downloaded by `agent-browser install` (without `--with-deps`) launches and renders pages, with the certificate tool and fonts that `--with-deps` would have installed on Ubuntu or Fedora.
- **Means:** Declare the `--with-deps` package set as NixOS configuration: runtime libraries through the existing nix-ld library path, plus `certutil` and the named fonts (KTD1, KTD2).
- **Authority:** This plan, then `AGENTS.md`, then existing module conventions.
- **Stop conditions:** Stop if a Chrome for Testing `NEEDED` soname has no nixpkgs provider, or if adding libraries to nix-ld breaks any host build.
- **Execution profile:** Configuration and one flake check. No hardware installation and no `nixos-rebuild switch`.
- **Finishes the work:** `ce-work` implements and verifies with the fast Nix commands. The user runs the hardware checklist item after their own rebuild.

---

## Product Contract

### Summary

Add one NixOS module that carries everything `agent-browser install --with-deps` installs on apt or dnf systems, in Nix terms. Import it on both hosts. Guard it with a flake check that reads the built system rather than option values.

### Problem Frame

`agent-browser install` downloads Chrome for Testing into `~/.agent-browser/browsers/`. It prefers that binary over any Chrome on `PATH`. On Linux the `--with-deps` flag installs the browser's shared libraries, `certutil`, and fonts, but only through `apt-get`, `dnf`, or `yum`, and NixOS has none of those. Without the libraries the downloaded binary fails at load time. Running Chrome for Testing 154.0.8037.57 on this host today fails with `libglib-2.0.so.0: cannot open shared object file`, even though nix-ld is enabled. Without `certutil`, agent-browser's CA-certificate import fails with an error that tells the user to run `--with-deps`.

### Key Decisions

- **Declare the dependencies in this repository rather than running `--with-deps`.** (session-settled: user-directed — chosen over running `agent-browser install --with-deps`: that command drives apt or dnf, which NixOS lacks.) Governs R1, R2, R3.
- **Declare dependencies only, not the agent-browser CLI.** (session-settled: user-directed — chosen over adding nixpkgs `agent-browser` to Home Manager packages and over pinning agent-browser to a Nix-built Chrome: the user installs the CLI themselves.) Governs R5.

### Requirements

**Browser runtime**

- R1. On every host configuration, each shared library named in Chrome for Testing's `NEEDED` list resolves through the nix-ld library path. So does GTK 3, which Chrome loads with `dlopen`.

**Certificate tooling**

- R2. `certutil` is on the system `PATH` on every host configuration.

**Fonts**

- R3. The font families that `--with-deps` installs on apt are resolvable by fontconfig on every host configuration: Noto Sans CJK, Noto Color Emoji, Liberation, and GNU FreeFont.

**Guard and records**

- R4. A flake check fails when any of R1 to R3 stops holding on any of the four configurations.
- R5. The agent-browser CLI and its browser download stay outside this repository.

### Scope Boundaries

- Packaging or installing the agent-browser CLI is excluded (see Key Decisions).
- Pointing agent-browser at a Nix-built Chrome through `--executable-path` or an environment variable is excluded. The Chrome on `PATH` from `home/h82/default.nix` stays as agent-browser's own fallback when no download exists.
- Linux ARM64 is excluded. agent-browser refuses to download Chrome for Testing there.
- `wget`, `xdg-utils`, and `libcurl` from Chrome's `deb.deps` are excluded. Chrome does not link them, and `--with-deps` does not install them.

### Sources

- agent-browser 0.38.1 source (`cli/src/install.rs`): the apt, dnf, and yum package lists, and `find_installed_chrome`, which reads `~/.agent-browser/browsers/chrome-*`.
- agent-browser 0.38.1 source (`cli/src/native/cdp/chrome.rs`): `find_chrome` checks the downloaded Chrome first, then `google-chrome` and `chromium` on `PATH`. `run_certutil` runs the `certutil` it finds on `PATH`.
- `readelf -d` on Chrome for Testing 154.0.8037.57 `chrome`. Its `NEEDED` sonames are `libglib-2.0`, `libgobject-2.0`, `libgio-2.0`, `libnspr4`, `libnss3`, `libnssutil3`, `libsmime3`, `libatk-1.0`, `libatk-bridge-2.0`, `libatspi`, `libdbus-1`, `libcups`, `libexpat`, `libxcb`, `libxkbcommon`, `libasound`, `libgbm`, `libX11`, `libXext`, `libXcomposite`, `libXdamage`, `libXfixes`, `libXrandr`, `libcairo`, and `libpango-1.0`. It also needs `libudev`, `libgcc_s`, and glibc. Chrome for Testing ships its own `libEGL`, `libGLESv2`, and `libvulkan.so.1`.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Libraries go through nix-ld, in a new focused system module.** A downloaded FHS binary finds libraries only through `NIX_LD_LIBRARY_PATH`, which is `/run/current-system/sw/share/nix-ld/lib`. Home Manager packages never reach that path. The new module appends to `programs.nix-ld.libraries`, which is a list option, so `modules/nixos/system/nix-ld.nix` keeps its baseline role. List only providers of the direct `NEEDED` sonames plus the runtime-loaded libraries that upstream's apt list also names: `gtk3` and `libxcursor`. `libX11-xcb.so.1` already ships in the `libx11` package. Nix-built libraries resolve their own dependencies through their store `RUNPATH`. `libudev`, `libgcc_s`, and glibc already come from the nix-ld defaults and the existing baseline.
- KTD2. **`certutil` and fonts live in the same module as the libraries.** The module's single concern is "what `--with-deps` installs", so its package list maps one-to-one onto upstream's list. The user left the system-or-home choice open. System placement keeps everything in one place and covers every user. Fonts go in `fonts.packages` even though Plasma and `fonts.enableDefaultPackages` already provide them today. Declaring them states the dependency, and duplicate font packages deduplicate harmlessly.
- KTD3. **The check reads the materialized system, never the option values.** Per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, it inspects the built system path's `share/nix-ld/lib` for each required soname, the built system path's `bin/certutil`, and `fc-list` run against each configuration's materialized `fonts/conf.d/00-nixos-cache.conf`. The top-level `fonts.conf` includes the absolute `/etc/fonts/conf.d`, which does not exist inside the build sandbox. The soname and family lists are the check's own literals, independent of the module. It covers all four configurations, not just the ThinkPad.

### Assumptions

- `at-spi2-core` in the locked nixpkgs provides `libatk-1.0`, `libatk-bridge-2.0`, and `libatspi`, because ATK merged into it upstream. Implementation confirms this against the built nix-ld directory.
- The Chrome for Testing `NEEDED` list is stable across Chrome releases within the check's shelf life. A future soname addition shows up at the hardware checklist step, not in the check.

---

## Implementation Units

### U1. Declare the agent-browser dependency module

**Goal:** One NixOS module carries the `--with-deps` package set, and both hosts import it.

**Requirements:** R1, R2, R3, R5 (Key Decisions: declare in repo, dependencies only)

**Dependencies:** None

**Files:**

- `modules/nixos/system/agent-browser-deps.nix` (new)
- `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`
- `hosts/MS-7D91/default.nix`

**Approach:**

1. Append the Chrome runtime providers to `programs.nix-ld.libraries` per KTD1. The providers are `glib`, `nss`, `nspr`, `at-spi2-core`, `dbus`, `cups`, `expat`, `libxcb`, `libxkbcommon`, `alsa-lib`, `libgbm`, the six X11 libraries, `cairo`, `pango`, `gtk3`, and `libxcursor`. Use `.lib` outputs where a package splits them, such as `cups`.
2. Add `nssTools` to `environment.systemPackages` and the four font packages to `fonts.packages` per KTD2.
3. Import the module beside `nix-ld.nix` in both hosts' import lists, unconditionally, so bootstrap variants carry it too.
4. Keep one short comment naming upstream `install.rs` as the source of the list, since that list is the non-obvious constraint.

**Patterns to follow:** `modules/nixos/system/nix-ld.nix` for shape, and the cherry-picked host import lists.

**Test scenarios:** Covered by U2's check.

**Verification:** All four host toplevels build. The built system path's `share/nix-ld/lib` holds `libglib-2.0.so.0`, `libnss3.so`, and `libgtk-3.so.0`.

### U2. Add the materialized-output flake check

**Goal:** A registered flake check fails whenever a configuration loses a required library, `certutil`, or font family.

**Requirements:** R4

**Dependencies:** U1

**Files:**

- `tests/agent-browser-deps.nix` (new)
- `flake.nix` (register as `agent-browser-deps`)

**Approach:**

1. For each of the four `nixosConfigurations`, read `config.system.path` and the built `/etc` tree per KTD3.
2. Test for existence of every `NEEDED` soname from Sources, plus `libgtk-3.so.0`, `libXcursor.so.1`, and `libX11-xcb.so.1`, under `share/nix-ld/lib`.
3. Assert that `bin/certutil` exists and is executable.
4. Set `FONTCONFIG_FILE` to that configuration's materialized `fonts/conf.d/00-nixos-cache.conf`, point `HOME` and `XDG_CACHE_HOME` at a writable temporary directory, run `fc-list : family`, and match each required family.
5. Collect every failure, naming configuration and item, and exit non-zero once at the end. Use `set -x` and explicit `if ...; then echo >&2; fi` branches, never `! cmd`.

**Execution note:** Mutation-test before trusting the check, per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`. Guard interpolations so a mutation fails inside the builder rather than at evaluation, per `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.

**Test scenarios:**

- Unmutated tree: the check passes on all four configurations.
- Remove `nss` from the module: the check fails and names `libnss3.so`, `libnssutil3.so`, and `libsmime3.so` for every configuration.
- Remove `gtk3`: the check fails on `libgtk-3.so.0`.
- Wrap the module's config in `lib.mkIf (!config.my.bootstrap)`: the check fails for both bootstrap configurations only. Gating `imports` on `config` would recurse during evaluation and prove nothing.
- Remove `nssTools`: the check fails on `certutil`.
- Remove `noto-fonts-cjk-sans` from the module and set `fonts.enableDefaultPackages = false` in the same mutation: the check fails naming Noto Sans CJK on every configuration. The default font set also provides all four families, so removing the font from the module alone stays green.

**Verification:** `nix build --no-link .#checks.x86_64-linux.agent-browser-deps` passes on the clean tree. Each mutation above turns it red with the expected message.

### U3. Document the check and the hardware step

**Goal:** Repository docs describe the new module and check, and the user has a manual step proving Chrome actually launches.

**Requirements:** R1, R4

**Dependencies:** U1, U2

**Files:**

- `docs/verification.md`
- `AGENTS.md`

**Approach:**

1. Add an `agent-browser-deps` sentence to the check catalogue paragraph in `docs/verification.md`. State what it reads and that it cannot see whether Chrome launches.
2. Add a hardware checklist item. After a rebuild, run `agent-browser install` without `--with-deps`, then open a page and take a screenshot. Record any `cannot open shared object file` output.
3. Add the new module to the `modules/nixos/` `system/` list in `AGENTS.md`.

**Test scenarios:** Test expectation: none -- documentation only.

**Verification:** Both docs name the module and check consistently.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | U1, U2 |
| New check | `nix build --no-link .#checks.x86_64-linux.agent-browser-deps` | U2 |
| All checks | `nix flake check` | all |
| Host builds | the four `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` commands in `AGENTS.md` | U1 |
| Local smoke (optional, evidence only) | run a downloaded Chrome for Testing `chrome --headless --dump-dom about:blank` with `NIX_LD_LIBRARY_PATH` pointed at the built system path's `share/nix-ld/lib` | U1 |

Report the local smoke separately from the check evidence. Hardware verification after a rebuild stays with the user.

## Definition of Done

- The new module is imported by both hosts, and all four toplevels build.
- `agent-browser-deps` is registered, passes, and each U2 mutation was observed red, then restored.
- `nix flake check` and `nix fmt -- --ci` pass.
- `docs/verification.md` and `AGENTS.md` describe the module, the check, and the hardware step.
- No mutation or experimental edits remain in the diff.
