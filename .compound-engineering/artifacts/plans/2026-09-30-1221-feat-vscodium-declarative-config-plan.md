---
title: VSCodium Package, Settings, and Keybindings - Plan
type: feat
date: 2026-09-30
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# VSCodium Package, Settings, and Keybindings - Plan

## Goal Capsule

- **Objective:** On every host, user `h82` can open VSCodium as `codium` or `code` and gets the editor settings and keybindings the legacy dotfiles carried, without running chezmoi.
- **Means:** a Home Manager module that installs VSCodium through `programs.vscodium` (KTD1), merges declared settings into the VSCodium-owned `settings.json` with the existing `agent-settings` merger (KTD2), and links `keybindings.json` from the store (KTD3).
- **Authority:** this plan, then `AGENTS.md`, then the merger pattern in `home/h82/agents/tokscale.nix` and its check `tests/tokscale.nix`.
- **Stop conditions:** stop if the pinned Home Manager no longer provides `programs.vscodium`, if `agent-settings` cannot express a declared value, or if a change breaks any `nixosConfigurations` build.
- **Execution profile:** one new Home Manager module, one new flake check, and documentation; `ce-work` implements it and the LFG pipeline ships it.

---

## Product Contract

### Summary

Add `home/h82/dev/vscodium.nix`, imported from `home/h82/dev/default.nix`. It installs VSCodium with a `code` wrapper, `nixd`, and the two extensions the settings name as formatter and language server. A `vscodiumSettings` activation entry merges the settings ported from the legacy dotfiles into `~/.config/VSCodium/User/settings.json`, and Home Manager links `~/.config/VSCodium/User/keybindings.json`. A new `vscodium` flake check guards all of it, and `docs/provisioning.md` and `docs/verification.md` describe it.

### Problem Frame

VSCodium's package, settings, and keybindings live in the chezmoi dotfiles repository (issue #59). Every other part of the migrated environment comes from this flake, so VSCodium is either missing or configured by hand on each host, and its settings drift between hosts.

### Requirements

**Package and commands**

- R1. On every configuration, `h82`'s profile provides an executable `codium` and an executable `code` that starts the same VSCodium.
- R2. On every configuration, `nixd` is on `h82`'s `PATH`, and the Nix IDE and Biome extensions are installed, so `nix.serverPath = "nixd"` and the Biome formatter settings resolve.

**Settings**

- R3. On every rebuild that produces a new Home Manager generation, `~/.config/VSCodium/User/settings.json` holds every setting of the legacy `vscodium-settings.json.tmpl` with its legacy value, and keeps every key the user or VSCodium added, including keys inside a declared object such as `[nix]`.
- R4. `editor.fontFamily` lists the managed monospace families Ghostty uses (JetBrainsMono Nerd Font, D2CodingLigature Nerd Font, D2KodingLigature Nerd Font) in order, each quoted, followed by the bare `monospace` keyword.

**Keybindings**

- R5. `~/.config/VSCodium/User/keybindings.json` carries the legacy bindings: `shift+enter` and `ctrl+enter` send a literal backslash-newline in the terminal, and the explorer delete mappings.

**Guard**

- R6. Removing the package, the `code` wrapper, `nixd`, an extension, the settings merge, a declared setting, or a keybinding fails `nix flake check`.

### Scope Boundaries

- Only the Linux path `~/.config/VSCodium/User` is managed; the legacy macOS target is outside this flake.
- Extensions other than Nix IDE and Biome stay user-installed from Open VSX. GitHub Copilot, GitLens, and the other extensions the settings mention are not packaged here; their settings are still carried so they apply once installed.
- No VSCodium profiles other than the default one, no `tasks.json`, `mcp.json`, or snippets.
- Not built: JSONC support in `settings.json`. The shared merger refuses a file that is not plain JSON and fails the rebuild loudly (KTD2), which the user sees at once; Home Manager's JSON5-reading alternative was declined for the reasons KTD2 gives, and it would drop the comments on write anyway.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Use Home Manager's `programs.vscodium` module with `pkgs.vscodium`.** The pinned Home Manager removed `programs.vscode.pname` and gives each fork its own module; `programs.vscodium` resolves the user directory to `~/.config/VSCodium/User` and the extensions directory to `~/.vscode-oss/extensions`. The module sets no `userSettings`, `enableUpdateCheck`, or `enableExtensionUpdateCheck`, because each of those makes Home Manager write `settings.json` as a read-only store link, which KTD2 rules out.
- KTD2. **Merge `settings.json` with the packaged `agent-settings` merger in `home.activation.vscodiumSettings`, ordered after `installPackages` and unguarded.** VSCodium rewrites `settings.json` whenever a setting changes in its UI, so a read-only store link would make every UI change fail. This is the same situation as Claude Code, the Antigravity CLI, and Tokscale, and it gets the same mechanism. The declared document splits by value shape:
  - top-level scalars go under `set`;
  - every scalar leaf inside an object-valued key (`[json]`, `[jsonc]`, `[nix]`, `[typescript]`, `[typescriptreact]`, `[yaml]`, `chat.instructionsFilesLocations`, `chat.tools.terminal.autoApprove`, `editor.codeActionsOnSave`, `editor.quickSuggestions`, `files.associations`, `github.copilot.enable`, `gitlab.authentication.oauthClientIds`, `json.schemaDownload.trustedDomains`, `remote.SSH.remotePlatform`) goes under `setPaths`, because VSCodium and its extensions write into those objects (a trusted schema domain, a Copilot toggle, a default formatter, a new SSH host) and `own` would erase those entries on the next generation;
  - array-valued keys (`github.copilot.chat.commitMessageGeneration.instructions`, `js/ts.preferences.autoImportFileExcludePatterns`, `js/ts.preferences.autoImportSpecifierExcludeRegexes`, `markdownlint.lintWorkspaceGlobs`, `todo-tree.general.tags`) go under `own`, since the merger has no element-wise form;
  - `emmet.preferences` is an empty object, VSCodium's default, and is not declared.

  Rejected: `profiles.default.userSettings` alone, which links a store file VSCodium cannot write. Also rejected: `profiles.default.mutableUserSettings`, which merges in place with a recursive `jq` merge and reads JSON5. Its activation entry runs after `linkGeneration` rather than `installPackages`, so a refusal can strand the entries behind it, which is what `claude.nix` orders its merges to avoid. It also fails the rebuild when VSCodium writes the file during activation instead of retrying, and it would be a second merge mechanism beside the one the existing checks drive.
- KTD3. **Link `keybindings.json` from the store through `profiles.default.keybindings`.** The file is a JSON array, and the merger accepts only a top-level object. The declared list is the whole file, as the legacy non-template chezmoi file was. The cost is that a keybinding added through VSCodium's UI cannot be saved and has to be added here instead. The legacy file lists the `backspace` → `deleteFile` binding twice; the port keeps one copy, which changes nothing VSCodium does. The generated `home.file` entry gets `force = true`: chezmoi left a regular file at that path on hosts that ran the dotfiles, and Home Manager's link check aborts activation on an unmanaged file, as `home/h82/desktop/avatar.nix` records for its own legacy paths.
- KTD4. **State the three managed monospace families as a literal list, as `home/h82/desktop/terminal.nix` does for Ghostty.** The legacy template built `editor.fontFamily` from the managed mono face and its fallbacks. `osConfig.fonts.fontconfig.defaultFonts.monospace` is not that list: the Plasma 6 module appends `Hack` and `Noto Sans Mono`, so every configuration evaluates it to five families. The literal yields `'JetBrainsMono Nerd Font', 'D2CodingLigature Nerd Font', 'D2KodingLigature Nerd Font', monospace`.
- KTD5. **Provide `code` as a wrapper executable on `PATH`, not a shell alias.** `pkgs.vscodium` ships only `codium`. Git, `xdg-open` handlers, and other non-interactive callers never see a zsh alias, and the wrapper execs the configured package's `codium` so both names start the same build.
- KTD6. **Install `nixd` in `home.packages` and declare `jnoortheen.nix-ide` and `biomejs.biome` from `pkgs.vscode-extensions`, keeping the extensions directory mutable.** These are the extensions the declared settings depend on (`nix.enableLanguageServer`, `nix.serverPath`, the Biome formatters and code actions). `mutableExtensionsDir` stays at its default of `true`, so the user can keep installing other extensions from Open VSX.
- KTD7. **Carry the legacy settings verbatim, including the machine- and account-specific ones.** `remote.SSH.remotePlatform`, `sherlock.userId`, and the GitLab OAuth client ID were already public in the dotfiles repository and are identifiers, not secrets. Carrying them keeps R3 checkable against the legacy file key by key.

### Assumptions

- VSCodium is installed on bootstrap outputs too, like the other GUI applications `home/h82/default.nix` installs, so the check covers every configuration.
- The module lives under `home/h82/dev/`, with the other developer tooling.
- A declared setting the user changes in VSCodium returns to its declared value only on a rebuild that produces a new Home Manager generation, as `.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md` records for the other merges.

### Risks

- The merger rewrites `settings.json` with two-space indentation, and VSCodium writes tabs. The content is unchanged, and VSCodium rewrites the file in its own style on its next write.
- If the user adds a comment or trailing comma to `settings.json`, the merger refuses the file and the rebuild fails with a message naming it. Removing the comment restores the merge. This matches the other merged files.
- With a mutable extensions directory, Home Manager's `.extensions-immutable.json` change hook runs `codium --list-extensions` during activation to regenerate `extensions.json`. This is Home Manager's own mechanism and needs no display.

---

## Implementation Units

### U1. VSCodium Home Manager module

- **Goal:** install VSCodium, `code`, `nixd`, and the two extensions, declare the keybindings, and merge the settings.
- **Requirements:** R1, R2, R3, R4, R5; KTD1 through KTD7.
- **Dependencies:** none.
- **Files:**
  - `home/h82/dev/vscodium.nix` (new)
  - `home/h82/dev/default.nix` (import it)
- **Approach:**
  1. Enable `programs.vscodium` with `package = pkgs.vscodium`, `profiles.default.extensions` set to the two extensions, and `profiles.default.keybindings` set to the seven de-duplicated legacy bindings (KTD3). The terminal bindings' `args.text` is backslash, carriage return, line feed. Set `force = true` on the generated `keybindings.json` file entry (KTD3).
  2. Add `nixd` and a `code` wrapper that execs `lib.getExe config.programs.vscodium.package` with its arguments (KTD5) to `home.packages`.
  3. Build the declared document with `set`, `setPaths`, and `own` from the legacy settings as KTD2 splits them (KTD7). `editor.fontFamily` comes from the literal family list (KTD4).
  4. Add `home.activation.vscodiumSettings` after `installPackages`, calling the merger from `packages/agent-tools.nix` with `--label VSCodium`, `--settings ${config.home.homeDirectory}/.config/VSCodium/User/settings.json`, and the declared document. Keep the comment explaining why it is unguarded short and point at `claude.nix`, as `tokscale.nix` does.
- **Patterns to follow:** `home/h82/agents/tokscale.nix` for the merger, declared document, and activation entry; `home/h82/desktop/terminal.nix` for the monospace family list.
- **Test scenarios:** covered by U2.
- **Verification:** every `nixosConfigurations` output builds, and its Home Manager generation contains `bin/codium`, `bin/code`, `bin/nixd`, the two extensions under `.vscode-oss/extensions`, and `.config/VSCodium/User/keybindings.json`.

### U2. `vscodium` flake check

- **Goal:** guard R1 through R6 against the materialized generation on every configuration.
- **Requirements:** R6, and through it R1 through R5.
- **Dependencies:** U1.
- **Files:**
  - `tests/vscodium.nix` (new)
  - `flake.nix` (register `vscodium` beside `tokscale`)
- **Approach:**
  1. Iterate `tests/lib/configurations.nix` entries and splice its `guard`, as `tests/tokscale.nix` does; collect every failure in one build.
  2. Read `home-path`, `home-files`, `home.file` targets, and `home.activation.vscodiumSettings` rather than module options; give every lookup an `or` fallback so a removed entry fails in the builder, not in evaluation.
  3. State every expected value as an independent literal written as JSON text: the declared settings document, the keybindings array, and the font family string.
- **Execution note:** before trusting the check, mutation-test it per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: remove the `code` wrapper, drop one declared setting, move one object leaf from `setPaths` to `own`, change one keybinding, drop `force` from the keybindings entry, and point `--settings` elsewhere, and confirm each turns the check red for the stated reason. Run the mutations in a scratch copy only after reading `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.
- **Patterns to follow:** `tests/tokscale.nix` (activation parsing, `compareJson`, seeded merge run), `tests/lib/configurations.nix`.
- **Test scenarios:**
  - `home-path/bin/codium` and `home-path/bin/nixd` are executable.
  - `home-path/bin/code` is executable and its resolved script execs the same `bin/codium` store path that `home-path/bin/codium` resolves to.
  - `home-files/.vscode-oss/extensions` holds an entry for `jnoortheen.nix-ide` and one for `biomejs.biome`.
  - `home-files/.config/VSCodium/User/keybindings.json` parses to the seven-entry expected array, including `shift+enter` and `ctrl+enter` sending `"\\\r\n"` under `terminalFocus`.
  - The Home Manager file entry targeting `.config/VSCodium/User/keybindings.json` has `force = true`.
  - No Home Manager file targets `.config/VSCodium/User/settings.json`.
  - `home.activation.vscodiumSettings` exists, runs after `installPackages`, invokes `/nix/store/…/bin/agent-settings` without `|| true`, `; true`, or `set +e`, and passes `--settings /home/h82/.config/VSCodium/User/settings.json`.
  - The `--declared` document equals the expected document, and its `set.editor.fontFamily` equals `'JetBrainsMono Nerd Font', 'D2CodingLigature Nerd Font', 'D2KodingLigature Nerd Font', monospace`.
  - Running that exact merger and document against a seeded file whose `files.autoSave` is `"off"`, whose `[nix]` is `{"editor.tabSize": 4, "editor.insertSpaces": false}`, and which carries an undeclared `workbench.colorTheme` yields `files.autoSave = "onFocusChange"`, `[nix]` equal to `{"editor.tabSize": 2, "editor.insertSpaces": false}`, and the undeclared key unchanged. A seeded `json.schemaDownload.trustedDomains` entry the legacy file does not list survives beside the declared ones.
- **Verification:** `nix build .#checks.x86_64-linux.vscodium` passes on the branch, and each mutation above fails it.

### U3. Documentation

- **Goal:** tell the reader what the module manages, what stays user-owned, and how to confirm it on hardware.
- **Requirements:** R3, R5.
- **Dependencies:** U1, U2.
- **Files:**
  - `docs/provisioning.md` (new `### VSCodium` section beside `### Tokscale`)
  - `docs/verification.md` (describe the `vscodium` check under Repository checks, add an "Every host" hardware item)
- **Approach:**
  1. In provisioning, state that settings are merged (declared keys return on a rebuild that produces a new Home Manager generation, other keys stay the user's), that keybindings are a read-only link edited here, that a comment in `settings.json` stops the merge, and which extensions are declared versus user-installed.
  2. In verification, describe what the `vscodium` check reads and what it cannot see (whether VSCodium starts, whether nixd attaches). Add a hardware item: open `code` from a terminal, confirm the font, confirm `shift+enter` in the integrated terminal inserts a line continuation, and confirm Nix IDE reports nixd running on a `.nix` file.
- **Test scenarios:** Test expectation: none -- documentation only.
- **Verification:** the sections exist and name the same paths and keys as U1.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix files are formatted |
| New check | `nix build .#checks.x86_64-linux.vscodium` | R1 through R6 |
| All checks | `nix flake check` | no regression in other checks |
| Host builds | build every `nixosConfigurations.<name>.config.system.build.toplevel` listed by `nix eval .#nixosConfigurations --apply builtins.attrNames` | production and bootstrap outputs build |

Hardware evidence (the new "Every host" item) is reported separately from these checks, per `docs/verification.md`.

---

## Definition of Done

- U1 through U3 are implemented and every gate in the Verification Contract passes.
- Each U2 mutation was run and turned the check red; the mutations are reverted.
- No real credentials were evaluated; the check uses only the literals it states.
- No abandoned-attempt code remains in the diff.

---

## Sources

- Issue: <https://github.com/hyperlapse122/nix-config/issues/59>
- Legacy files in <https://github.com/hyperlapse122/dotfiles>: `home/.chezmoitemplates/vscodium-settings.json.tmpl`, `home/dot_config/VSCodium/User/keybindings.json`, `home/dot_config/VSCodium/User/settings.json.tmpl`.
- Merger contract: `scripts/agent-settings` (`set` takes scalars only, `own` takes whole values).
- Font declaration: `modules/nixos/desktop/fonts.nix`.
