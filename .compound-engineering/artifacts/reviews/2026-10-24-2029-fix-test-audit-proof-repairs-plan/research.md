# Test audit planning research

Baseline: revision `09e9f5aaf56f3bb549c69bc8499de9c208737e4d`, branch `chore/audit-tests`, Darwin. Research only; no execution, implementation, activation, commit, or push. Source evidence is the audit report and lane findings, preservation ledgers, and direct reads of the named interfaces below. The report's later systems ledgers complete the initial systems ledger; its old partial disclaimer does not invalidate the final report.

## Repository patterns

- `tests/lib/configurations.nix` defines `entries` solely from NixOS; `userEntries` includes both NixOS and architecture-matching standalone Linux fixture users and `userGuard` rejects missing kinds/bootstrap coverage. It does not include Darwin. F3's migration is appropriate for home-only contracts and must not mechanically change system-only loops.
- `tests/lib/etc-file.nix` already resolves an entry's enabled, effective target and returns null when disabled/retargeted. Reuse for F22/F23 while preserving builder-owned missing diagnostics rather than interpolating null into Nix strings.
- `tests/darwin-outputs.nix` builds native fixture generations and extracts actual generated activation blocks through `stepBlock`. It redirects Pi's destination, executes the block under strict Bash, and checks the effect. F15 belongs here for native Codex execution, while `tests/darwin-config.nix` retains Linux-evaluable declaration/target/DAG proof.
- `home/h82/dev/containers.nix` owns `containersAuth` after `writeBoundary`. `home/h82/agents/codex.nix`, `claude.nix`, `gemini.nix`, and `agent-plugins.nix` own the named activation steps; settings/plugins use `installPackages` ordering. Redirect destinations and replace helper executables only; do not reconstruct a call and claim execution of the original block.
- `packages/gpg-tools.nix` substitutes Linux Qt/curses/secret-tool paths into installed `bin/pinentry-card`, patches its shebang and links `bin/pinentry`. Darwin has a distinct filter/proxy renderer. F11 needs installed Linux artifact proof while retaining raw source behavior and Darwin filter proof. There is no current gnome/kde/none API to preserve.
- `home/h82/agents/test-audit.nix` declares the internal `my.testAuditSkill` option and the actual skill contribution. D3 removes the option/provenance let scaffolding only. Actual contribution stays. `tests/test-audit-skill.nix` keeps attribution, license, enabled resolved targets, byte equality, frontmatter and non-symlink proof. `docs/provisioning.md` is the single documentation adjustment.
- `flake.nix` has `hostClosureChecks` and dynamic light shards; native Darwin outputs are separate. Any check newly consuming a generation must be reviewed for hosts-shard routing by the serial integrator. Reading only home-files does not automatically imply a generation closure.

## Ownership and sequencing

Use disjoint batches: agents activation/delivery (F1-F3, agents C1-C5), release fixtures/workflow schedule (F4-F5, releases C1-C4/D1), security/identity (F7-F11, Docker C, pinentry C), workflow semantics (F6/F24 and Git self-test D), platform containers/SDK (F12-F14), Darwin native output proof (F15 and Darwin F14), desktop lifecycle (F18-F21 and D3 test/production module), materialized system policies (F22-F23). A serial integrator owns all `flake.nix` edits (F16/F17, F11 wiring and shard routing) and `docs/provisioning.md`. Avoid parallel owners on `tests/darwin-outputs.nix`, `tests/darwin-config.nix`, `tests/check-workflow-docs-skip.sh`, `tests/pinentry-card.sh`, and `tests/podman-containers.nix`.

The three explicit carry-first obligations are malformed-JSON process no-Traceback, converged plugin rerun exact symlink target, and exact Docker response key set for every distinct-value routing row. Pinentry is a fourth preservation-sensitive setup consolidation: simple no-holder SETDESC, holder-bearing older/non-YubiKey Number rows, and YubiKey alignment rows stay independently exercised, with raw-PIN-negative assertions applied to answered rows. No runtime saving is promised.

## Behavior trace

1. Settings activation: Home Manager produces step body -> activation invokes installed merger with declaration/destination -> divergent scratch file gains declared values and preserves unmanaged content -> refusal exits nonzero. Existing static checks stop before invocation, while generic merger suites start after invocation. Full-block execution closes that boundary without duplicating merger semantics.
2. Delivery: options supply source/enable/target -> Home Manager or NixOS materializes at consumer destination -> consumer parses configuration or executes binary. Existing gaps inspect source/option proxy; repaired owner reads materialized files and installed home.path executables. Missing, disabled and retargeted mutations must remain distinct from wrong content.
3. Identity loading: user installer derives recipient and compares expected recipient before replace; valid mismatch differs from corrupt key derivation. SSH load decrypts existing private key with wallet password and compares declared public identity; provision mismatch is a different boundary. F10's valid B fingerprint mapped to A's working password reaches the load comparison.
4. Lifecycle: printer reconciler queries existing URI before deciding creation, then updates description; taskbar discovers applet types before writes; tailscale skips all API traffic with existing state. Record actual calls and effects, not a text inventory. Tailscale mock must record GET as well as DELETE and reset observations only after startup settles.
5. Workflow: classifier output and event feed each job-level scalar; correct-looking step condition cannot replace it. Darwin list expression determines all output targets, so alpha rename must pass while omitted host/check targets and wrong native runner fail.

## Institutional learnings

Read and adopt these strongest matches, all under `.compound-engineering/artifacts/solutions/best-practices/`:

1. `activation-step-grep-check-passes-an-echo-only-step.md` (best_practice): run the redirected actual block, assert replacement occurred, run strict shell, inspect written file. Echo/dead branch and failing helper are independent negative controls.
2. `nix-check-reads-option-value-not-materialized-output.md` (best_practice): disabled and retargeted entries retain option text. Materialized consumer paths and full host variants own delivery proof.
3. `mutation-testing-reveals-decorative-nix-check-assertions.md` (best_practice): a negative assertion requires an explicit failing branch; domain parse validity does not establish intended values. One mutation per assertion class, read the failure reason.
4. `unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md` (best_practice): guard absent derivations at Nix level so missing output reaches the builder diagnostic. Evaluation failure is not a caught mutation.
5. `converged-fixture-state-defeats-nix-check-mutation-testing.md` (best_practice): seed distinct candidate states; equal fixtures cannot prove source selection. Relevant to every activation and registry routing fixture.

Also read `copied-git-worktree-writes-the-real-index.md`: future mutations use archives with no .git or an independently initialized copy excluding .git, never copied worktree links; keep working directory in trusted checkout and address scratch paths explicitly. Full root-required learning set must be read by implementers before adding or trusting changed guards, especially nullable operand, nullglob, store-hash substring, read-only evaluation, host partition and exact-sentence pitfalls. No assertion is certified merely because an adjacent check has the same shape.

## Flow and edge-case findings for plan integration

- No launch blocker is evidenced. All repairs are bounded strengthening of existing proof; none needs a new production API or architecture choice.
- Execute materialized/native boundaries on supported platforms. Source replay, identical derivation and all-system evaluation are useful gap evidence but never Linux build/VM passes. Pending Linux evidence must not block implementation or CI publication.
- F14 must cover fresh auth JSON, 0700 directory/0600 file, preservation of existing custom bytes, and dry-run no change on Linux and Darwin. VM's hand-authored auth file remains a distinct consumer/security contract.
- F18 must include already-correct/offline state rejecting unnecessary creation, changed URI, missing queue, and command errors. F19 needs both supported applet types and trait variants; preserve launcher order/grouping values and observable write effects.
- F24 should run the actual workflow list expression with distinguishable fixture hosts/checks and record target splitting; expected values must be independent of the expression. Alpha rename is a positive refactor control, not a production fix.
- Do not mutate or remove production comparators as a fix: use isolated mutants to demonstrate repaired tests. Rejected Claude updater duplicate and VSCodium whole-object set hypotheses are excluded; actual merger already rejects object-valued set.
- Final campaign evidence must list all F1-F24/C1-C11/D1-D3 outcomes, retained independent contracts, intended caught mutants with control restoration, owner/sibling results, production versus test/support LOC, native platform evidence and hardware limitations. Linux/KVM absent remains pending until supported CI/builders supply current-head evidence.
