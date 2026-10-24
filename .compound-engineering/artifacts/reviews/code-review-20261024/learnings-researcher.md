## Institutional Learnings Search Results

### Search Context

- **Feature/Task**: Review test-audit proof repairs against repository learnings about mutation evidence, materialized delivery, activation effects, and lifecycle fixtures.
- **Keywords Used**: mutation-testing, activation, materialized output, delivery, fixture divergence, builder diagnostics, scratch worktree, platform evidence.
- **Files Scanned**: 64 solution documents searched; seven directly relevant documents read in full.
- **Relevant Matches**: Five principal patterns below, plus adjacent guidance on decorative assertions and macOS inspection of Linux checks.
- **Observed defects**: None established in this specialist review.

### Relevant Learnings

#### 1. Activation argument checks can pass an echo-only step

- **File**: `.compound-engineering/artifacts/solutions/best-practices/activation-step-grep-check-passes-an-echo-only-step.md`
- **Module**: Home Manager activation checks
- **Problem Type**: `best_practice`
- **Relevance**: The new `tests/lib/agent-activation.py` executes redirected activation blocks, records actual helper calls, verifies settings effects, and injects helper refusals. `tests/vscodium.nix` now executes its block against divergent settings and a destination that must be refused. These address the documented historical failure.
- **Key Insight**: Command text and ordering establish wiring; executing the block and checking resulting state establish effects. The current diff preserves that distinction.
- **Severity**: medium

#### 2. Option values do not prove materialized delivery

- **File**: `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`
- **Module**: NixOS and Home Manager file checks
- **Problem Type**: `best_practice`
- **Relevance**: Gemini settings now come from `home-files`; sysctl and Logitech rules come from `system.build.etc`; GPG, Zsh, Ghostty, and container registry assertions likewise inspect delivered paths. Disabling or retargeting declarations can therefore affect the observed artifact instead of leaving a proxy value unchanged.
- **Key Insight**: Assert the destination and contents consumers receive. A declaration’s `text` or `source` alone cannot detect broken delivery.
- **Severity**: medium

#### 3. Evaluation failure is not a caught mutation

- **File**: `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`
- **Module**: Nix flake mutation evidence
- **Problem Type**: `best_practice`
- **Relevance**: `tests/audit-proof-mutations.py` separates evaluation from building, rejects evaluation failures as evidence, requires a changed owner derivation, and checks the failing owner’s log for its intended diagnostic. It also rebuilds the restored control.
- **Key Insight**: A red command proves the guard only when the intended owner builder rejects the mutation for the intended reason.
- **Severity**: medium

#### 4. Scratch mutation copies must own their index

- **File**: `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`
- **Module**: Mutation testing in scratch copies
- **Problem Type**: `best_practice`
- **Relevance**: The mutation venue uses `git archive`, rejects an unexpected `.git`, then initializes and stages a separate scratch repository. It does not copy the worktree’s Git pointer.
- **Key Insight**: Mutation isolation must include Git metadata. The reviewed implementation follows the documented isolation rule.
- **Severity**: medium

#### 5. Fixtures must distinguish correct behavior from the regression

- **File**: `.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md`
- **Module**: Behavioral fixture design
- **Problem Type**: `best_practice`
- **Relevance**: Settings fixtures begin with divergent declared values and unmanaged state. Printer fixtures distinguish fresh, changed, correct, and refused reconciliation. Taskbar fixtures include two supported applets and an unrelated applet. These produce different observable outcomes for the relevant regressions.
- **Key Insight**: A green assertion is useful only when the fixture makes the buggy implementation observably different.
- **Severity**: medium

### Recommendations

- Preserve the separation between historical risks and observed defects: the patterns above support the repairs; they do not establish additional bugs.
- Keep matching-platform execution pending until the real owner checks and mutation jobs complete. The adjacent learning `verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md` explicitly distinguishes local input inspection from complete check evidence.
- All 36 mutation anchors currently occur exactly once in their target files. This confirms that the edits can apply; it does not prove the mutations are caught.
- This review performed read-only inspection and anchor validation. It did not run owner builds, VM checks, or mutation builds, and made no repository or index edits.
