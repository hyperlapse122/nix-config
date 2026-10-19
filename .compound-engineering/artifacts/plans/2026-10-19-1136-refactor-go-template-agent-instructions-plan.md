---
title: Go Template Agent Instructions - Plan
type: refactor
date: 2026-10-19
topic: go-template-agent-instructions
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Go Template Agent Instructions - Plan

## Goal Capsule

- **Objective:** A rule in the shared agent instructions can depend on a host fact that `modules/shared/host.nix` declares, such as a trait or the host kind, without new Nix plumbing, and an instruction file holding an unrendered or null value still never reaches a harness.
- **Means:** Render `instructions.md.tmpl` at build time with a purpose-built Go `text/template` renderer over the host facts (KTD1, KTD2), failing on any missing or null value (KTD3).
- **Product authority:** issue #246 and the Product Contract below. Planning resolves HOW only.
- **Stop conditions:** Stop if the rendered file is not byte-identical to today's `replaceVars` output on every host, or if any host output fails to build.
- **Execution profile:** Go (stdlib only), Nix packaging, Nix checks, Markdown. No hardware or `nr switch` validation.
- **Open blockers:** None.

---

## Product Contract

### Summary

The shared instructions become a Go template, `home/h82/agents/instructions/instructions.md.tmpl`, rendered once per host by a small stdlib renderer in `packages/` with the host facts as its data. The rendered file stays byte-identical to today's, and all three delivery paths keep linking that one file. A new check proves the renderer fails on a missing key, an empty value, and an undefined function, and the existing `agent-instructions` check keeps guarding the delivered file.

### Problem Frame

`home/h82/agents/instructions/default.nix` fills the file's single `@gpgKey@` placeholder through `pkgs.replaceVars`. That substitutes named plain values only: a rule that should apply only on hosts with a trait, such as the T3 Code section on a host with `my.t3.cli` or `my.t3.desktop`, needs either a second file or Nix string assembly, and every new value must be passed by name. An earlier generation rendered the file with gomplate (0b1f7d4); 6505c6a replaced it with the plain file when the per-harness variants were dropped, so today nothing in the repository can branch the instruction text on a host fact.

### Key Decisions

- **Fail the build on a missing key.** Governs R3. (session-settled: user-directed — chosen over Go's default of rendering `<no value>`: `<no value>` must never reach a harness.)
- **One rendered file for every delivery path.** Governs R5. (session-settled: user-directed — chosen over per-harness or per-path variants: variants were dropped in 6505c6a and are not wanted back now.)
- **Keep the existing `agent-instructions` assertions and mutation-test the new renderer.** Governs R7, R8. (session-settled: user-directed — chosen over dropping or relaxing the existing check: it guards the materialized file.)

### Requirements

**Rendering**

- R1. The instructions are rendered at build time from `instructions.md.tmpl` with Go `text/template` semantics, and `pkgs.replaceVars` no longer renders them.
- R2. The template's data context is the host facts that `lib/host-facts.nix` projects from `config.my`; the template can read nothing else, including files, environment variables, or the network.
- R3. Rendering fails the build when the template reads a key the context lacks, or prints a `null` value, so no `<no value>` or `<nil>` reaches a delivered file.
- R4. Rendering fails the build when the template calls a function the renderer does not define.

**Delivery**

- R5. `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`, and `~/.gemini/config/AGENTS.md` keep linking one rendered file, byte-identical to today's on every host.

**Checks and documentation**

- R6. A renderer check fails when the renderer accepts a missing key, a printed `null`, or an undefined function, or when it renders a known template wrongly.
- R7. `tests/agent-instructions.nix` keeps its assertions: an unrendered action (`{{`, `}}`), `<no value>`, an `@name@` placeholder, and a fingerprint other than the host's `my.user.gpgKey` each turn it red.
- R8. Mutations prove the guards: an unrendered action in the template, a missing key, and a literal fingerprint on the fake-key fixture each turn a check red.
- R9. `docs/provisioning.md` and the `AGENTS.md` project-structure line describe the template, the renderer, its data context, and its failure modes.

### Scope Boundaries

- No conditional section is added now; the template's only action reads `.user.gpgKey`. Gating the T3 Code section on `my.t3.*` is a follow-up the template makes possible.
- No per-harness or per-path variant (Key Decisions).
- Considered and not built: an allowlist of the host facts the template may read. The renderer reads nothing outside its context, `lib/host-facts.nix` is already the boundary for what the user layer sees, and `tests/host-name-guard.nix` greps every file under `home/`, so a host-name branch in the template still fails. A fact that must not reach agent text would change this.
- Considered and not built: gomplate. Its `file`, `env`, and `http` functions read outside the context, and on macOS, where Nix's `sandbox` defaults to false and `modules/darwin/` sets none, a build could read the Mac's filesystem and network. A need for gomplate's functions would change this.

#### Deferred to Follow-Up Work

- Gate the `# T3 Code` section on `my.t3.cli.enable || my.t3.desktop.enable`, with the `agent-instructions` pins split by trait.

### Sources / Research

- `home/h82/agents/instructions/default.nix`, `home/h82/agents/instructions/instructions.md:9` — the current `replaceVars` render and its one placeholder. The file also holds `${TMPDIR:-/tmp}`, which `text/template` passes through unchanged.
- `git show 6505c6a^:home/h82/agents/instructions/render.nix` — the earlier gomplate renderer with `--missing-key error` and JSON contexts from `pkgs.writeText`.
- `lib/host-facts.nix`, `lib/nixos-host.nix:55`, `lib/darwin-host.nix:74` — the projection and where it reaches Home Manager. `lib/linux-host.nix` imports `modules/shared/host.nix` into Home Manager directly, so `config.my` carries every declared option there too.
- `modules/shared/host.nix` — the facts: `bootstrap`, `hostName`, `kind`, `desktopSSH.publicKey` (`nullOr path`), `user.{name,home,gpgKey}`, and the trait `enable` options.
- `tests/agent-instructions.nix:122-143` (`fileRules`), `:212-229` (`assertEntry`'s fake-key handling) — the assertions R7 keeps.
- `home/h82/agents/opencode.nix:15`, `home/h82/t3code.nix:25` — Home Manager modules importing `packages/*.nix` by relative path.
- Nix manual 2.34.9, `nix.conf` `sandbox`: "The default is true on Linux and false on all other platforms."
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`, `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md` — how the mutations in U3 are run and read.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **A purpose-built stdlib renderer, `packages/text-template/` (`go.mod`, `main.go`) packaged by `packages/text-template.nix` with `pkgs.buildGoModule` and `vendorHash = null`.** It parses one template with `Option("missingkey=error")` and no `FuncMap`, so only Go's builtin functions exist and an unknown function is a parse error (R4). It reads the template path and a JSON data path from its arguments, renders into a buffer, and writes stdout only on success, so a failed render leaves no partial file. Gomplate is out per Scope Boundaries. Governs R1, R2, R4.
- KTD2. **The data is `builtins.toJSON (hostFacts.of config.my)` written with `pkgs.writeText`, decoded by the renderer into `map[string]any`.** `missingkey=error` applies only to map lookups, so decoding into maps rather than structs is what makes a missing key fail. `desktopSSH.publicKey`, a path, serializes to its store path string; it is a public key, and the render already differs per host through `gpgKey`. Governs R2, R3.
- KTD3. **The renderer also fails when the output contains `<no value>` or `<nil>`.** Go prints `<no value>` for a key that is present with a `null` value, which `missingkey=error` does not catch, and the builtins `print`, `printf`, and `println` print the same `null` as `<nil>` (or `%!s(<nil>)`). Every host but those with a desktop SSH key carries `desktopSSH.publicKey = null`. Checking the output for both markers is the one place that sees every such print. Governs R3.
- KTD4. **Render in a `pkgs.runCommand` in `home/h82/agents/instructions/default.nix` that runs `text-template` with the renderer as a `nativeBuildInputs` entry, and keep the three `home.file` entries pointing at its output.** Only the render step changes, so delivery and the `agent-instructions` check's lookups keep working unchanged. Governs R1, R5.
- KTD5. **A separate `text-template` check in `tests/text-template.nix`, registered under `checks` in `flake.nix`.** It reads no host generation, so it belongs in a light shard, which `tests/check-shards.nix` assigns by name automatically. Each case runs the renderer against a small fixture template under `tests/text-template/` and asserts the exit status, and for a failure case that stdout is empty. Governs R6.

### Assumptions

- `nix fmt` and `nixfmt-tree` format only Nix; `main.go` is kept `gofmt`-clean by hand, since the flake has no Go formatter.
- `pkgs.buildGoModule` with `vendorHash = null` builds a module with no dependencies on every system the flake targets, including `aarch64-darwin`.

### Sequencing

U1 builds the renderer and its check; U2 switches the instructions to it; U3 proves the guards by mutation; U4 updates the documentation to the landed state.

---

## Implementation Units

### U1. Add the stdlib template renderer and its check

- **Goal:** A `text-template` binary renders a Go template from a JSON context and fails on a missing key, a printed `null`, or an undefined function.
- **Requirements:** R2, R3, R4, R6; KTD1, KTD2, KTD3, KTD5.
- **Dependencies:** None.
- **Files:**
  - Create `packages/text-template/go.mod`, `packages/text-template/main.go`, `packages/text-template.nix`.
  - Create `tests/text-template.nix` and fixtures under `tests/text-template/`.
  - Modify `flake.nix` to register the `text-template` check.
- **Approach:**
  1. `main.go` takes exactly two arguments, the template path and the data path, and exits non-zero with a message naming the cause on a wrong argument count, an unreadable file, invalid JSON, a parse error, an execution error, or `<no value>` or `<nil>` in the output.
  2. Name the template after its file so a Go error message carries the template path and line.
  3. `packages/text-template.nix` takes `{ pkgs }` and sets `meta.mainProgram`, matching the other `packages/*.nix` files.
  4. `go.mod`'s `go` directive is no newer than nixpkgs' `go` version, so the sandboxed build never tries to download a toolchain.
- **Patterns to follow:** `packages/tokscale.nix` for the `{ pkgs }` package shape; the `requireSentences` failure collection in `tests/agent-instructions.nix` for reporting every failing case in one build.
- **Test scenarios:**
  - A template reading `.user.gpgKey` and `{{ if .t3.cli.enable }}` against a matching context renders exactly the expected text.
  - A template reading `.user.missing` exits non-zero, prints nothing on stdout, and names `map has no entry for key` on stderr.
  - A template reading a missing key without printing it, `{{ if .user.missing }}BAD{{ end }}`, exits non-zero and prints nothing on stdout. This is the case that separates `missingkey=error` from the output check, since Go's default renders it as empty.
  - A template printing `.desktopSSH.publicKey` with a `null` value exits non-zero.
  - A template printing the same `null` through `{{ printf "%v" .desktopSSH.publicKey }}` exits non-zero and prints nothing on stdout.
  - A template calling `env "HOME"` exits non-zero at parse.
  - A wrong argument count exits non-zero.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.text-template` succeeds, and removing `Option("missingkey=error")`, the `<no value>` check, or the `<nil>` check from `main.go` turns it red (U3).

### U2. Render the instructions from the template

- **Goal:** All three delivery paths link the file rendered from `instructions.md.tmpl` over the host facts.
- **Requirements:** R1, R2, R5, R7; KTD2, KTD4.
- **Dependencies:** U1.
- **Files:**
  - Rename `home/h82/agents/instructions/instructions.md` to `home/h82/agents/instructions/instructions.md.tmpl`, replacing `@gpgKey@` with `{{ .user.gpgKey }}`.
  - Modify `home/h82/agents/instructions/default.nix`.
  - Modify the header comment of `tests/agent-instructions.nix` ("one plain file rendered with the user's card key").
- **Approach:**
  1. In `default.nix`, import `lib/host-facts.nix` and `packages/text-template.nix` by relative path, write the context with `pkgs.writeText`, and render with `pkgs.runCommand` (KTD4).
  2. Keep the existing delivery comment and the three `home.file` entries.
- **Patterns to follow:** the relative `import ../../../packages/...` in `home/h82/agents/opencode.nix`.
- **Test scenarios:**
  - `agent-instructions` passes on every host, including the fake-key fixture, with no change to its assertions.
  - Every host's rendered `~/.claude/CLAUDE.md` is byte-identical to the one built from the base commit (compare each host's two `home-files` outputs with `cmp`).
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` succeeds, and the `cmp` against the base commit's outputs reports no difference on any host.

### U3. Prove the guards by mutation

- **Goal:** Each guard the issue names turns red when the code it guards is broken.
- **Requirements:** R6, R7, R8.
- **Dependencies:** U1, U2.
- **Files:** none committed; mutations run in a scratch copy.
- **Approach:** For each mutation, edit a scratch copy, build the named target, confirm it fails for the stated reason in `nix log` or the build output, and discard the copy.
- **Execution note:** Run the mutations in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, and confirm each failure comes from the expected builder rather than from evaluation.
- **Test scenarios:**
  - An unrendered action: the template writes `{{ "{{" }}` so the output carries `{{`; `agent-instructions` fails with "carries an unrendered template action or placeholder".
  - A missing key: the template reads `{{ .user.gpgkey }}`; the render derivation fails with a missing-key error, so the home generation and `agent-instructions` fail to build.
  - A literal fingerprint: the template states the card fingerprint in place of `{{ .user.gpgKey }}`; `agent-instructions` fails on the fake-key fixture with "names a key other than the host's my.user.gpgKey".
  - The renderer: removing `Option("missingkey=error")` turns `text-template` red through the `{{ if .user.missing }}` case; removing the `<no value>` output check turns it red through the printed-`null` case; removing the `<nil>` output check turns it red through the `printf` case.
- **Verification:** Every mutation fails as stated; the unmutated tree builds both checks.

### U4. Document the template and renderer

- **Goal:** The documentation describes the template, its renderer, its data context, and how it fails.
- **Requirements:** R9.
- **Dependencies:** U2.
- **Files:** Modify `docs/provisioning.md` ("Shared agent instructions"), `AGENTS.md` (the `home/h82/` project-structure line, and the `scripts/`/`packages/` line if it names packaged helpers only).
- **Approach:** Replace the `replaceVars` sentence in `docs/provisioning.md` with the template, `{{ .user.gpgKey }}`, the host-facts context, the renderer's three failure modes, and the reason gomplate is not used; say that a NixOS-only trait must move into `modules/shared/host.nix` before the template can read it; describe the `text-template` check beside the `agent-instructions` paragraph.
- **Test expectation:** none -- documentation only; `markdownlint-cli2` runs from the pre-commit hook.
- **Verification:** `rg -nP 'replaceVars|@gpgKey@|instructions\.md(?!\.tmpl)' docs AGENTS.md CONCEPTS.md` returns no stale mention.

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Renderer | `nix build --no-link .#checks.x86_64-linux.text-template` | R3, R4, R6 |
| Delivered file | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R5, R7 |
| Byte identity | `cmp` of every host's `home-files/.claude/CLAUDE.md` against the base commit's | R5 |
| Mutations | U3's mutations, each red | R8 |
| Formatting | `nix fmt -- --ci`; `nix shell nixpkgs#go -c gofmt -l packages/text-template` prints nothing | style |
| Flake | `nix flake check` | registration, shards |
| Hosts | every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output from `AGENTS.md`'s shipping loop; `darwinConfigurations` left to CI's `build-darwin` | R1 on every host |

---

## Definition of Done

- U1 through U4 are complete, and every Verification Contract gate passes or, for macOS outputs, is left to CI and reported as such.
- `pkgs.replaceVars` and `@gpgKey@` no longer appear in `home/h82/agents/instructions/`.
- No scratch copies, mutation edits, or abandoned experiments remain in the diff.
