---
title: T3 Code accepts a preinstalled Antigravity runtime only in its managed layout
date: "2026-10-08"
category: integration-issues
module: T3 Code Antigravity provider runtime (Home Manager activation)
problem_type: best_practice
component: tooling
severity: medium
applies_when:
  - "Preinstalling the Antigravity ACP runtime for T3 Code from Nix instead of the app's Install button"
  - "Changing scripts/t3code-antigravity-install, packages/antigravity-acp.nix, or the antigravity entry of packages/t3code-release.json"
  - "A T3 Code nightly bump changes how T3 Code finds, records, or validates the Antigravity runtime"
symptoms:
  - "The Antigravity provider page shows an Install button or no version although agy_acp_server.par is on PATH or set as the provider's binary path"
related_components:
  - infrastructure
tags: ["t3code", "antigravity", "acp", "nix-store", "symlink", "home-manager", "activation", "release-pin"]
retire_when: "T3 Code changes AntigravityInstallation (src/provider/AntigravityInstallation.ts) so the resolver uses lstat, checks link counts, or reports a version for a PATH or binaryPath runtime; check by grepping the pinned CLI bundle for completedRelease and fromExternal"
---

# T3 Code accepts a preinstalled Antigravity runtime only in its managed layout

## Context

T3 Code installs the Antigravity ACP server on demand: the provider page's Install button downloads a 110-335 MB archive into `~/.t3/tools`. This flake preinstalls that runtime (since the branch that made T3 Code's settings declarative) from a Nix-fetched package so a rebuild leaves only the Google sign-in (`home/h82/t3code.nix:156`). Getting there needed reading how T3 Code `0.0.46-nightly.20261008.2801` resolves the runtime, because several plausible shortcuts work at runtime yet leave the provider looking uninstalled, and one plausible worry (store symlinks) turned out not to apply. None of this is visible from the final code alone. The facts below were read from the pinned server bundle (`AntigravityInstallation.completedRelease` and `resolve`) and confirmed with a live ACP `initialize` on macOS (per this session's investigation).

## Guidance

**Write T3 Code's managed layout; do not rely on `PATH` or the provider's `binaryPath`.** T3 Code reports an installed version only when `~/.t3/tools/antigravity-acp/<platform>-<arch>/active.json` names a release (`{"releaseId": "<archive sha256>"}`) whose `versions/<sha256>/` directory holds `.install-complete.json` and the two binaries. The record is `{releaseId, version, executable: {name, bytes}, harness: {name, bytes}}`. A runtime found through `PATH` (an `agy_acp_server.par` with a sibling `localharness_external`) or through the provider's `binaryPath` setting still runs, but the resolver returns `version: null`, so the page never shows it as installed. `<platform>-<arch>` is Node's key; the systems this flake pins are `linux-x64`, `linux-arm64`, and `darwin-arm64`.

**Linking the binaries into the Nix store is accepted.** The resolver checks each binary with `stat`, which follows symlinks: it must be a regular file of exactly the recorded byte size with any execute bit. There is no `lstat` and no link-count check, unlike Orca's skill check. So `versions/<sha256>/` can be a real directory whose two binaries are symlinks into the store package, which avoids storing the Linux runtime (about 1 GB unpacked) twice. Keep the directory and both JSON records as real, writable files: T3 Code's own Remove and reinstall act on them. `scripts/t3code-antigravity-install` does this, and leaves a version directory T3 Code installed itself (real binaries, matching record) alone (`scripts/t3code-antigravity-install:59`).

**Relink when the package path changes.** The Home Manager generation roots only its own package. A version directory whose links point at an older store path stays valid until that generation is collected, then dangles. The installer therefore treats links to any path other than the current package as stale and replaces them, and it renames the old directory aside, renames the new one into place, and only then deletes the old one (`scripts/t3code-antigravity-install:99-108`).

**Fixup must stay off for the runtime package** (`packages/antigravity-acp.nix:35`). T3 Code compares exact byte sizes, and `agy_acp_server.par` carries an appended archive that stripping or patchelf would break. NixOS runs the unpatched binaries through nix-ld, as it does the runtime T3 Code downloads.

**Take the pin from T3 Code, and check it against the built CLI.** The release table (version, URL, archive sha256 and size, binary names and sizes per platform) is in `apps/server/src/provider/antigravityRelease.ts` of the upstream T3 Code repository (pingdotgg/t3code) at the pinned tag, which `scripts/t3code-release` fetches (`scripts/t3code-release:53`). The same table is embedded as plain JavaScript in the CLI binary `libexec/t3code/t3`, but the bundler rewrites `const releaseAssets = new Map([...])` into a hoisted `var` plus an assignment. A parser of the binary must match the assignment, not the `const` declaration (`tests/t3code-antigravity-pin.py:27-30`). The archive sha256 is at once the Nix fetch hash, the version directory name, and T3 Code's `releaseId`.

## Why This Matters

The shortcuts fail quietly. A `PATH` or `binaryPath` runtime answers sessions, so nothing errors, but the provider page keeps offering Install. With a `PATH` runtime, clicking it downloads a second copy that T3 Code then prefers, because the resolver reads `active.json` before it searches `PATH`. A pin that drifts from the nightly's table makes T3 Code reject or replace the preinstalled runtime at its next resolve. A fixup pass changes the byte sizes and T3 Code reports the runtime as incomplete.

T3 Code spawns the executable by the path inside `versions/<sha256>/` (the symlink, not its target), sets `ANTIGRAVITY_HARNESS_PATH` to the harness path, and validates a reinstall with an ACP `initialize` that must report `agentInfo` `antigravity-acp` at the pinned version, protocol 1 or 2, `loadSession`, session resume, logout, and the `oauth-personal` auth method. A store-linked layout passed that handshake on macOS. The Linux `.par` running from a read-only store path has not been exercised yet; `docs/verification.md` lists it as a first-run hardware check.

## When to Apply

- Before replacing the managed layout with a simpler `PATH` entry, a `binaryPath` setting, or a `home.file` link: none of them shows the runtime as installed.
- On every T3 Code nightly bump: the `t3code-antigravity-pin` check compares the pin with the table the built CLI embeds, so a stale pin turns it red.
- When the resolver logic itself may have changed: re-read `completedRelease` and `fromExternal` in the new bundle before trusting the layout described here.

## Examples

The managed layout the installer writes for the macOS runtime:

```text
~/.t3/tools/antigravity-acp/darwin-arm64/
  active.json                      {"releaseId":"7cd97045...aa5b88"}
  versions/7cd97045...aa5b88/      real directory, mode 0755
    .install-complete.json         real file, mode 0600, the four-field record
    agy_acp_server.par   -> /nix/store/...-antigravity-acp-1.3.0/libexec/antigravity-acp/agy_acp_server.par
    localharness_external -> /nix/store/...-antigravity-acp-1.3.0/libexec/antigravity-acp/localharness_external
```

What looks equivalent but is not:

```text
PATH=/nix/store/...-antigravity-acp-1.3.0/libexec/antigravity-acp:$PATH   # runs, but version: null
providers.antigravity.binaryPath = ".../agy_acp_server.par"              # runs, but version: null
```

Related: [T3 Code's Antigravity ACP server finds no CA bundle on NixOS](t3code-antigravity-acp-openssl-missing-ca-bundle-hangs-sessions.md) (the wrapper's `SSL_CERT_FILE` still covers the preinstalled binary); [Orca rejects skill files hardlinked by the Nix store optimiser](orca-rejects-hardlinked-nix-store-skill-files.md) (the opposite outcome: Orca checks link counts, T3 Code does not).
