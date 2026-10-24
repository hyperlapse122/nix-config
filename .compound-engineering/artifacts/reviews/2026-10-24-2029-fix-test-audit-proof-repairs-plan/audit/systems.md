# Systems test audit at 09e9f5a

## Status and limits

**Partial audit; do not treat the systems lane as complete.** The manifest contains 103 files and 17,598 lines. This report records confirmed findings and the declarations inspected closely enough to make a disposition. The final inventory explicitly names files still needing full declaration, owner, history, overlap, and dependency review. No disposition is implied for those files. In particular, this is not an approval to remove the unaudited Linux, Darwin, hardware, security, or package checks.

HEAD was `09e9f5aaf56f3bb549c69bc8499de9c208737e4d` before and after inspection; the shared checkout remained clean. No repository edit, commit, push, activation, real secret, or hardware operation occurred. Mutation material was extracted with `git archive 09e9f5a` to `/tmp/nix-config-test-audit/systems-controls/repo`; that tree has no `.git`. The physical path is under `/private/tmp` on macOS. No nested agent was used.

Read AGENTS.md and the explicitly requested store skill, audit reference, and campaign. Relevant learning review included decorative shell assertions, evaluator-only mutation failures, materialized versus option values, converged fixtures, copied worktree index hazards, Linux-check derivation replay on Darwin, SOPS directory permissions, and card provisioning. A bulk learning read was truncated; this is another reason not to claim complete learning coverage for the lane.

## Confirmed findings

### F1: workflow conditions are matched as substrings, allowing a permanently false gate

- Location: `tests/check-workflow-docs-skip.sh:108`; the same implementation occurs in `assert_docs_only_only` at line 151.
- Contract: ordinary code changes, classifier failures, and main pushes must run Nix validation; the complementary lint job must run for docs-only PRs.
- Flaw: `grep -qF "$expected"` accepts additional expression terms despite claiming an exact condition. Prepending `false &&` to flake-check's job-level condition disables evaluation for every event while the entire test still exits zero. The helper also searches all indented `if:` lines within a job, including steps, rather than parsing the job-level YAML key.
- Evidence: `systems-controls/control.log` and `false-flake-gate.log` both exit 0. The latter corresponds to `false-flake-gate.yml`, where only the actual flake-check condition gained `false &&`. The mutation leaves syntactically valid quoted YAML and preserves the expected substring.
- Keeper: retain this independent workflow-routing contract in this suite. CI running once cannot prove future event/classifier combinations. The executable classifier table in `tests/ci-docs-only-paths.sh` is distinct and should remain.
- Fix: read each job's own YAML `if` scalar and compare the normalized complete expression, or evaluate an explicit truth table. Reject extra prefix/suffix operators; add controls for a false prefix, true suffix, and a step-only matching condition. Retain matrix and native platform routing assertions.
- History: `db35652` introduced the full expected expression specifically after independent substring fragments missed swapped connectives; blame attributes the current grep line to `46f76da`. That repair never enforced whole-expression equality.
- Routing: flake.nix:1585 declares `ci-workflow-docs-skip`; normal changes run it through the generated light shards, and the workflow itself is the owner under test. Native bash control is real execution, not Linux build evidence.

### F2: installer mismatch tests use an invalid identity, missing valid-key recipient mismatch

- Location: `tests/test_install_user_age_identity.py:61`, related cleanup case at line 110; keygen stub at line 34.
- Contract: the user installer must reject a valid identity belonging to another recipient, preserve the prior identity, and remove staging files.
- Flaw: the stub exits nonzero for `OTHER-ID`, so both mismatch cases exercise derivation failure (`None`), not a successfully derived wrong recipient. They cannot distinguish equality validation from merely checking whether derivation succeeded.
- Mutation: in the temporary owner only, replace `if _derive_recipient(staged_path) != expected_recipient:` with `if _derive_recipient(staged_path) is None:`. All ten tests still pass. A separate command with a valid derived `age1testrecipient` and expected `age1otherrecipient` is rejected by the control (exit 1, no file) and accepted by the mutant (exit 0, file installed).
- Evidence: `systems-controls/user-identity-control.log`, `user-identity-ignore-recipient.log`, `valid-wrong-recipient-control.log`, and `valid-wrong-recipient-mutant.log`.
- Keeper: retain this subprocess suite as the primary user-installer validation owner. `tests/non-nixos-vm.nix:174` rejects a foreign key during production activation, but places it directly on disk. Its installer call at line 185 uses the correct recipient; it does not prove the installer rejects a valid wrong recipient. The root installer has a real valid-mismatch case at `tests/restore-age-identity.py:64`, but it is a separate security boundary and cannot substitute for this owner.
- Fix: pass `VALID-ID` with a different syntactically valid expected recipient, assert rejection and existing bytes, and check no staging names remain in that same case. Preserve a separate corrupt-key case. Consolidate the existing cleanup-only mismatch declaration into the repaired case if desired.
- History: initial non-NixOS implementation `a4908dc`; `03e69a7` added the cleanup-only case without changing the invalid-payload fixture. This is a coverage gap, not evidence the current production comparator is wrong.
- Production callers: recovery's `--user` pipeline invokes the packaged installer; Home Manager installs it from bootstrap onward via `home/h82/security/non-nixos-secrets.nix:113`. `packages/gpg-tools.nix:74` packages it. `tests/non-nixos-scripts.nix` and flake.nix:1625 route its subprocess suite into checks.

### F3: empty bootstrap recipient passes membership check

- Location: `tests/bootstrap-recipients.nix:53` (the `hasInfix (recipientOf host) sopsConfig` branch).
- Contract: every host has nonempty recovery material and its recorded recipient is authorized for the shared encrypted tokens.
- Flaw: `lib.strings.hasInfix "" sopsConfig` is true. Emptying a tracked `recipient.txt` produces `ok` and a successful builder, while `scripts/recover-age-identity:83` explicitly rejects an empty recipient. Arbitrary substrings and occurrences in unrelated rules/comments also satisfy the current membership assertion.
- Evidence: baseline and empty-recipient mutation both evaluate and their generated builder scripts both exit 0; see `systems-controls/bootstrap-control-builder.log` and `bootstrap-empty-recipient-builder.log`, plus the saved builder scripts. Mutated only the public `secrets/bootstrap/MS-7D91/recipient.txt` in the standalone archive. Initial path-URL attempts failed because `/tmp` is a symlink; reran using its physical path. Those initial failures are not mutation success evidence.
- Keeper: retain directory pairing and bootstrap-material checks here. `sops-recipients` independently compares each encrypted file against its first creation rule; it never compares those recipients with bootstrap recipient files. The desktop SSH source checker checks NixOS SSH metadata, not every host's token recovery contract, so it does not replace this check.
- Fix: reject empty/malformed recorded public recipients and compare parsed exact recipients from the first rule applying to `secrets/tokens.yaml`; preserve `sops-recipients` for actual ciphertext metadata equality. Add standalone empty, shortened substring, comment-only, and wrong-rule negative controls.
- History: introduced with recovery automation in `e12fe7a`, host discovery changed in `df115a5`, directory enumeration shared in `ca7cab8`; substring membership survived these changes.
- Proof limit: executed the actual generated shell via native bash, which has no Linux-only runtime dependencies. This is builder replay evidence, not a native Nix/Linux build or actual secret decryption.

### C1: duplicate successful Docker credential get case

- Location: `tests/test_docker_credential_sops.py:66` (`test_mapped_registry_valid_secret`).
- Contract: Docker helper emits the exact successful response schema, routes each registry to its own account/token, and keeps stderr empty.
- Flaw: this case repeats the ghcr.io row already executed by `test_distinct_value_routing` at line 120. Only its exact key-set assertion is absent from that stronger three-registry table.
- Keeper/fix: first move `set(data) == {ServerURL, Username, Secret}` into every row of `test_distinct_value_routing`, then retire the one-off successful get declaration. Keep all distinct error normalization, list, unsupported mutation, whitespace, and leakage cases. No production seam removal follows.
- History: both declarations originated in `837ef5c` with the helper; `72ed746` later simplified the implementation. They still invoke the same real CLI subprocess against the same mapping.
- Production owner/callers: `scripts/docker-credential-sops` implements the Docker helper protocol; both NixOS secrets and non-NixOS Home Manager install mappings through `packages/docker-credential-sops.nix`. Flake.nix:817 owns the subprocess check; Podman VM authentication is distinct container transport proof.
- Evidence: parent baseline records the 11-declaration suite passing. Inspection proves the repeated ghcr.io row and identifies the unique key-set assertion to carry first. No deletion or fixed test was applied or validated.

### D1: direct Git configuration self-test has no repository owner

- Location: `tests/lint-staged-markdown.sh:391` through its assertion at line 395.
- Claimed contract: assigning `git config core.hooksPath .githooks` twice leaves one value.
- Flaw: both writes and the read invoke Git directly; this declaration never calls the repository hook, task, lint script, setup command, or package. It can fail only if the dependency's own replace-value behavior changes, not if repository code regresses.
- Remaining proof: the immediately preceding real `git commit` fixtures run the copied `.githooks/pre-commit` through the task stub in linked worktrees, accepting clean staged Markdown and rejecting bad staged Markdown. Those are the repository-owned hook-delivery contracts and must remain. The no-hook branch fixture is a distinct lifecycle case and remains.
- History: added by `56118ec` during review fixes after original hook work `3c94e44`; later `c919dc0` and `fabad15` added resolved-path trust and safe-mode checks, which are separate security/config contracts and remain.
- Fix: delete only this direct Git self-test. It unlocks no production deletion. No credible repository regression is lost because there is no repository production call in its execution path.
- Evidence: full test and `scripts/lint-staged-markdown`, `.githooks/pre-commit`, and flake.nix:1775 wiring inspected. The full lint suite was not rerun here (requires the declared markdownlint version); this is a source-supported deletion candidate, not a validated deletion.

## Layer plan

No entire file is recommended for retirement. Repair F1-F3 at their present independent boundaries. Absorb C1's exact-schema assertion into the existing multi-registry CLI table before removing its duplicate. Remove only D1's direct dependency self-test. Do not collapse the root installer into the user installer, security metadata into decryption behavior, boot layout invariants into the single-host VM, or declared package/config/platform delivery into generic host build success.

The root restore helper's injectable `target`, `age_keygen`, and `uid` are explicitly test-only parameters, but their removal is **not recommended on the evidence collected**: the VM does not yet absorb the malformed-input and non-root cases. A complete seam-removal proposal would need that migration and Linux/KVM proof first.

## Baseline evidence

Parent's `python-baseline.json` reports passing Android parity, Docker helper, user installer, publisher, serve-html, and Synthetic watcher suites. Desktop SSH's initial baseline failed during import because `cryptography` was unavailable; the inspected log is not a product-failure proof. A configured SSH Python environment exists in the parent's directory, but this lane has no verified rerun result to substitute. Parent's `eval-all.log` ends `all checks passed`; this is evaluation evidence only. Parent's Darwin output log reaches the final Darwin check build but has no explicit harness exit record in that file; this lane does not infer a pass from that tail. Parent owns final baseline disposition.

Linux native checks, Linux host builds, NixOS/Ubuntu VM tests, and physical hardware proof are unavailable in this lane. Nix evaluation and generated-shell replay do not turn those into passes. No final campaign line-count reduction exists because no edits occurred.

## Declaration ledger

R = retain; F = preserve contract and repair proof; C = consolidate into the named keeper; D = delete because no repository contract is exercised. The rows below are audited dispositions, not a claim that every manifest declaration is covered.

### tests/test_install_user_age_identity.py

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | `tests/test_install_user_age_identity.py:53` `test_installs_valid_identity_privately` | Valid stdin identity reaches user-owned 0600 target in 0700 directory; catches permissive modes or wrong output bytes. |
| F | `tests/test_install_user_age_identity.py:61` `test_refuses_recipient_mismatch_and_keeps_existing` | F2: valid wrong recipient must preserve existing target; current payload cannot distinguish mismatch from corrupt input. |
| R | `tests/test_install_user_age_identity.py:69` `test_refuses_symlinked_target` | Symlinked target must not overwrite outside bytes; catches following the planted destination. |
| R | `tests/test_install_user_age_identity.py:79` `test_refuses_symlinked_directory` | Symlinked identity directory must remain untouched; catches following a planted parent. |
| R | `tests/test_install_user_age_identity.py:96` `test_refuses_empty_identity` | Empty identity rejected before staging; catches writing empty key files. |
| R | `tests/test_install_user_age_identity.py:99` `test_refuses_oversized_identity` | Oversized input rejected before staging; catches missing size bound. |
| R | `tests/test_install_user_age_identity.py:102` `test_refuses_identity_with_nul_bytes` | NUL-containing input rejected before staging; catches malformed identity acceptance. |
| R | `tests/test_install_user_age_identity.py:105` `test_refuses_invalid_recipient_argument` | Malformed expected recipient rejected before staging; catches removing argument validation. |
| F | `tests/test_install_user_age_identity.py:110` `test_mismatch_leaves_no_staged_file` | F2: failed valid mismatch must remove temporary files; merge cleanup assertions into repaired mismatch case. |
| R | `tests/test_install_user_age_identity.py:114` `test_never_prints_the_identity` | Failed installation never echoes identity; catches exception or debug output leaking stdin. |

### tests/test_docker_credential_sops.py

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| C | `tests/test_docker_credential_sops.py:66` `test_mapped_registry_valid_secret` | C1: carry exact successful response schema into distinct-value routing table first. |
| R | `tests/test_docker_credential_sops.py:76` `test_unmapped_registry` | Unmapped registry uses normalized protocol miss with empty stderr; catches lookup fallthrough. |
| R | `tests/test_docker_credential_sops.py:80` `test_secret_file_absent` | Missing secret file uses normalized protocol miss; catches exception leakage. |
| R | `tests/test_docker_credential_sops.py:91` `test_secret_file_empty_or_whitespace_only` | Empty and whitespace-only secrets both miss; catches accepting unusable credentials. |
| R | `tests/test_docker_credential_sops.py:106` `test_trailing_newline_stripping` | Trailing whitespace is stripped from otherwise valid token; catches sending line endings to registry. |
| R | `tests/test_docker_credential_sops.py:120` `test_distinct_value_routing` | Three distinct registry/account/token routes; catches cross-registry credential substitution. Absorbs C1 schema assertion. |
| R | `tests/test_docker_credential_sops.py:135` `test_store` | Docker store operation acknowledges declarative ownership; catches unsupported mutation breaking client protocol. |
| R | `tests/test_docker_credential_sops.py:146` `test_erase` | Docker erase operation acknowledges declarative ownership; distinct externally selected protocol action despite shared implementation. |
| R | `tests/test_docker_credential_sops.py:152` `test_list` | List returns registry-to-username map without tokens; catches wrong list response shape. |
| R | `tests/test_docker_credential_sops.py:159` `test_leak_guard` | Invalid/missing/oversized/control/space credentials yield normalized miss without token bytes; catches unsafe rejection diagnostics. |
| R | `tests/test_docker_credential_sops.py:200` `test_unknown_action` | Unknown action fails and names action; catches success/fallthrough for unsupported protocol operations. |

### tests/test_publish_cli_auth.py

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | `tests/test_publish_cli_auth.py:29` `test_writable_host_specific_configs_and_repair` | Host/account-specific writable regular 0600 auth configuration, unchanged inode on repeat, repair after deletion; catches wrong routing, permissions, or failure to repair. |
| R | `tests/test_publish_cli_auth.py:47` `test_invalid_input_preserves_last_good_files` | Invalid final token preserves last-good gh bytes; catches publishing before all inputs validate. |
| R | `tests/test_publish_cli_auth.py:56` `test_symlink_directory_rejected` | Symlinked config directory refused and outside tree untouched; catches directory traversal. |

### tests/test_android_sdk_repo_parity.py

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | `tests/test_android_sdk_repo_parity.py:68` `test_identical_entries_pass` | Identical independent fixture entries pass and report compared image; catches false-positive drift. |
| R | `tests/test_android_sdk_repo_parity.py:73` `test_same_revision_that_differs_fails` | Same revision with changed type details fails; catches skipping equal revisions. |
| R | `tests/test_android_sdk_repo_parity.py:78` `test_newer_pinned_image_revision_is_skipped` | Newer pinned image skipped while comparable platform remains checked; catches treating unavailable upstream revision as drift. |
| R | `tests/test_android_sdk_repo_parity.py:84` `test_older_pinned_image_revision_fails` | Older pinned image fails; catches downgrades hidden as an unlisted release. |
| R | `tests/test_android_sdk_repo_parity.py:89` `test_revision_compares_numerically` | Numeric revision order compares 10 above 9; catches lexicographic ordering. |
| R | `tests/test_android_sdk_repo_parity.py:94` `test_revision_with_another_field_set_is_compared_not_skipped` | Different revision field sets compare full entries instead of skipping; catches schema drift hidden as newer release. |
| R | `tests/test_android_sdk_repo_parity.py:102` `test_missing_revision_details_is_compared_not_skipped` | Missing revision metadata compares instead of skipping; catches missing metadata hiding archive drift. |
| R | `tests/test_android_sdk_repo_parity.py:109` `test_non_numeric_revision_is_compared_not_a_crash` | Nonnumeric revision reports drift without traceback; catches unhandled conversion failure. |
| R | `tests/test_android_sdk_repo_parity.py:117` `test_multi_field_revision_orders_by_each_field` | Multi-field revision ordering in both directions; catches ignored minor/micro components. |
| R | `tests/test_android_sdk_repo_parity.py:128` `test_newer_pinned_package_revision_is_skipped` | Newer package revision also skips; catches image-only skip policy. |
| R | `tests/test_android_sdk_repo_parity.py:137` `test_entry_nixpkgs_does_not_list_is_skipped` | Absent upstream package is explicitly skipped and excluded from compared summary; catches false drift for newly released packages. |
| R | `tests/test_android_sdk_repo_parity.py:145` `test_only_skipped_entries_assert_nothing` | All-skipped input fails as no evidence; catches vacuous parity success. |

### tests/restore-age-identity.py

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | `tests/restore-age-identity.py:59` `test_valid_identity_is_root_mode_0600_and_atomic_target` | Valid input yields matching bytes and 0600 target; actual root ownership is separately kept in auth VM. The mocked chown does not prove root ownership or atomic visibility. |
| R | `tests/restore-age-identity.py:64` `test_recipient_mismatch_preserves_existing_target` | Successfully derived wrong recipient preserves old bytes; catches replacing equality with mere parse success. |
| R | `tests/restore-age-identity.py:69` `test_corrupt_identity_preserves_existing_target` | Corrupt identity preserves old bytes; catches installing an unparsable identity. |
| R | `tests/restore-age-identity.py:74` `test_empty_oversized_and_nul_inputs_are_rejected` | Empty, oversized, NUL-containing inputs preserve old bytes; catches malformed payload acceptance. Size uses owner constant: fixed 8192 external-bound assertion would be stronger, but no independent declared changed-bound contract established here. |
| R | `tests/restore-age-identity.py:80` `test_non_root_cannot_install` | Non-root invocation rejected by install boundary; catches removing privilege gate. This is injected uid proof, not actual root CLI proof. |
| R | `tests/restore-age-identity.py:83` `test_symlink_parent_is_rejected` | Real directory validation rejects symlink parent; catches writing outside fixed identity directory. |

### tests/ci-docs-only-paths.sh

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | `tests/ci-docs-only-paths.sh:31` | 'all paths under docs/' true 'docs/install.md' 'docs/recovery.md'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:32` | 'all paths under .compound-engineering/artifacts/' true \; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:35` | 'root *.md mixed with a docs/ path' true 'AGENTS.md' 'docs/install.md'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:36` | 'one non-doc path among otherwise-doc paths' false 'docs/install.md' 'flake.nix'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:37` | 'a nested README.md is not root-level' false 'secrets/README.md'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:38` | 'a docs-prefixed but different directory' false 'docs2/foo.md'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:39` | 'a single root *.md file alone' true 'README.md'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:40` | 'a path under neither declared root' false 'scripts/ci-docs-only-paths'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:41` | 'a non-artifacts path directly under .compound-engineering/' false '.compound-engineering/config.yaml'; catches misclassifying this path category and skipping required CI or losing the promised docs optimization. |
| R | `tests/ci-docs-only-paths.sh:43` empty input | Empty change input defaults to full checks; catches a vacuous all-docs result. |

### tests/check-workflow-docs-skip.sh

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| F | `tests/check-workflow-docs-skip.sh:250` `assert_gated flake-check` | F1: preserve event gate, repair substring acceptance. |
| F | `tests/check-workflow-docs-skip.sh:251` `assert_gated hosts` | F1: preserve event gate, repair substring acceptance. |
| F | `tests/check-workflow-docs-skip.sh:252` `assert_gated build list` | F1: preserve event gate, repair substring acceptance. |
| F | `tests/check-workflow-docs-skip.sh:253` `assert_gated build-linux list` | F1: preserve event gate, repair substring acceptance. |
| R | `tests/check-workflow-docs-skip.sh:254` `assert_matrix_from_hosts build targets` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:255` `assert_matrix_from_hosts build-linux linux_targets` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| F | `tests/check-workflow-docs-skip.sh:256` `assert_gated build-darwin list` | F1: preserve event gate, repair substring acceptance. |
| R | `tests/check-workflow-docs-skip.sh:257` `assert_matrix_from_hosts build-darwin darwin_targets` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:258` `assert_native_darwin` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:259` `assert_darwin_targets` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:260` `assert_native_arm` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| F | `tests/check-workflow-docs-skip.sh:261` `assert_gated check-shard-names` | F1: preserve event gate, repair substring acceptance. |
| F | `tests/check-workflow-docs-skip.sh:262` `assert_gated check-shards list` | F1: preserve event gate, repair substring acceptance. |
| R | `tests/check-workflow-docs-skip.sh:263` `assert_empty_list_fails check-shard-names` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:264` `assert_matrix_from check-shards check-shard-names names name` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| F | `tests/check-workflow-docs-skip.sh:265` `assert_gated vm-check-names` | F1: preserve event gate, repair substring acceptance. |
| F | `tests/check-workflow-docs-skip.sh:266` `assert_gated vm-checks list` | F1: preserve event gate, repair substring acceptance. |
| R | `tests/check-workflow-docs-skip.sh:267` `assert_empty_list_fails vm-check-names` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:268` `assert_matrix_from vm-checks vm-check-names names name` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| R | `tests/check-workflow-docs-skip.sh:269` `assert_unconditional fmt` | Preserve dynamic producer/consumer matrix, nonempty lister, unconditional formatting, or native runner contract selected by this call; catches the corresponding missing dependency, literal matrix, empty success, condition, or wrong runner. |
| F | `tests/check-workflow-docs-skip.sh:270` `assert_docs_only_only markdown-lint` | F1: preserve event gate, repair substring acceptance. |

### tests/lint-staged-markdown.sh

Scenario declarations below retain the public index/hook/security contract; helper and final summary `pass` calls are not additional declarations.

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | `tests/lint-staged-markdown.sh:48` | version parity holds (mise.toml=$toml_version, mise.lock=$lock_version, nixpkgs=$nixpkgs_version); catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:60` | version parity assertion fails on mismatched version inputs; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:109` | staged docs/bad.md exits non-zero and reports file, line number, and MD032; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:118` | staged clean docs/ok.md exits 0; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:134` | staging only flake.nix exits 0 without running markdownlint-cli2; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:159` | lint runs with MISE_TRUSTED_CONFIG_PATHS naming the scratch copy; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:165` | lint runs the trusted copy in mise safe mode; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:177` | lint under a symlinked TMPDIR trusts the resolved scratch path; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:191` | lint-staged-markdown never calls mise; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:200` | staged secrets/bad.md exits 0 (outside config globs); catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:220` | staged root README.md and .compound-engineering/artifacts/plans/*.md each exit non-zero on error; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:232` | index holding bad docs/x.md with fixed working tree exits non-zero; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:242` | index holding clean docs/x.md with broken working tree exits 0; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:253` | staged deletion of a Markdown file exits 0; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:269` | staged Markdown path containing a space is linted correctly; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:283` | unborn repository with staged bad docs/bad.md fails; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:298` | working-tree and index blobs byte-identical after failing run; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:311` | staged Markdown symlink is linted through its target; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:328` | nested markdownlint config applies to staged files beneath it; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:333` | mise task lint-staged-markdown runs the script under test; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:370` | git commit in linked worktree with staged bad markdown fails and prints rule; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:376` | git commit in linked worktree with clean markdown succeeds; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| R | `tests/lint-staged-markdown.sh:389` | linked worktree on branch without .githooks commits successfully; catches loss of the named staged-file, index isolation, routing, diagnostic, hook, trust, or safe-mode behavior. |
| D | `tests/lint-staged-markdown.sh:396` | D1: tests only Git replacement semantics; actual linked-worktree commits remain. |

### Nix checks and executable guard declarations

Nix runCommand/nixosTest declarations group their internal parameter rows unless a finding separates one contract above. Rows explicitly noting pending owner review are conservative retention decisions, not completed whole-owner audit.

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| F | `tests/bootstrap-recipients.nix:41` | F3: preserve paired directories, required files, and actual recipient membership; empty recipient currently succeeds. |
| R | `tests/boot-layout-invariants.nix:17` | Fleet-wide independent disk/boot interface: LUKS name/type, ESP mount, subvolumes, swap; catches another host layout drifting beyond the one VM boots. |
| R | `tests/boot-layout.nix:58` | Upstream disko formats and boots disposable disk through imported boot module; catches unusable real disk assembly that a raw layout assertion cannot. Encrypted volume, LUKS2, all five mounted subvolumes and swap remain separate runtime assertions within this declaration. |
| R | `tests/check-shards-guard.nix:36` | Check inventory is assigned exactly once to nonempty shards and contains no unknown check; catches a green CI omitting a check. No check derivations forced. |
| R | `tests/vm-checks-guard.nix:39` | VM derivations stay outside ordinary checks and known VM inventory proves detector recognizes actual VM features; catches accidental KVM requirement in fast CI or detector covering nothing. |
| R | `tests/host-options.nix:49` | System/HM option bridge equality and prohibition of NixOS-only osConfig reads; catches dropped shared facts and standalone host evaluation coupling. Shared source enumerates option paths, not expected values. |
| R | `tests/host-name-guard.nix:45` | Independently declared architectural rule forbids real/fixture host identifiers in shared code; catches hardcoded machine branching. Fixed bytes are the public policy, not a private implementation identifier. |
| R | `tests/git-cli-repo-flags.nix:73` | Installed CLI package routing must honor explicit enterprise host/project outside checkout; wrong default host exposes data or mutates wrong project. Keep gh/glab command variants as distinct CLI contracts. Full dependency-source review remains pending; no deletion candidate. |
| R | `tests/kernel-sysctl.nix:49` | Materialized sysctl lines and enabled etc entry preserve forwarding/inotify defaults; catches retargeted/disabled/misrendered config and changed numeric policy. |
| R | `tests/nix-ld.nix:71` | Independent binary loader selection, session variables and baseline package libraries; catches changed loader/default library declarations. Option-only portions do not prove runtime linker behavior; no deletion recommended. |
| R | `tests/logitech-wakeup.nix:35` | Receiver vendor/product scope and remote-wakeup disable rule; catches incorrect USB IDs or enabled wakeup. Current proof reads merged rule option, not installed udev rules: delivery verification remains pending, so no clean bill on that layer. |
| R | `tests/wireplumber-bluetooth.nix:65` | Loaded WirePlumber data fragments disable headset autoswitch and carry no true setting; catches stale/overriding emitted config. Service option enable is not runtime proof. |
| R | `tests/user-avatar.nix:60` | Home and SDDM faces match independent source asset at consumer paths; catches system greeter losing avatar despite private home containing it. Separate paths are independent consumer delivery contracts. |
| R | `tests/ghq.nix:48` | Installed ghq uses rendered Git config to create/list repository under HOME/src; catches missing package or ignored config with otherwise valid evaluation. |
| R | `tests/git-lfs.nix:54` | Installed LFS filter stores pointer with independent content hash and restores bytes on checkout; catches declaration failing to reach Git or accidental skip-smudge default. |
| R | `tests/git-trim.nix:59` | Rendered config keeps merged deletion local and never detaches active linked-worktree branch; catches upstream dangerous defaults returning. Distinct live bare-remote refs and worktree HEAD assertions remain. |
| R | `tests/wifi-assertions.nix:41` | Table: case-insensitive collision, hyphen, digit prefix reject; valid distinct labels pass. Catches malformed environment-label acceptance and overly restrictive validation. Reason-specific assertion matching would strengthen isolation; not claimed mutation-verified. |
| R | `tests/auth-provisioning.nix:29` | Actual SOPS-to-user CLI publication, ownership/traversability, missing/corrupt identity and repair, repeat activation, symlink refusal, CLI consumption and no journal leakage; catches lifecycle/security faults unit mocks cannot. Linux/KVM not run. |
| R | `tests/non-nixos-vm.nix:99` | Ubuntu system-manager/HM apply preserves distribution files, rejects absent/foreign identity before generation switch, recovers production and keeps account-owned state across bootstrap/production; catches real activation lifecycle regressions. Does not test installer valid-recipient mismatch (F2). Linux VM not run. |
| R | `tests/host-secrets.nix:32` | Real packaged stage/publish decrypts fake crypto, refuses bad identity/mode/symlink/SSH/token/schema, cleans staging, privately publishes and rotates retired token twice; catches decryption/publication sequencing and cleanup failures. Distinct from platform activation/VM delivery. |
| R | `tests/sops-recipients.nix:27` | Actual repository metadata equality plus valid, comma-space, overlap-first, extra/missing/nested recipient, every non-age group, overlap-second, pgp-only, key-groups, no-rule/yml/plain/empty fixtures; catches first-rule mismatch and vacuous scans. Each rejection checks intended diagnostic. Keep metadata security guard independent of decryptability. |
| R | `tests/sops-recipients.sh:23` | Guard implementation supports the preceding Nix fixture table and live repository scan; preserve exact first-rule and age-only security contract, no independent replay suite to retire. |
| R | `tests/check_desktop_ssh_config.py:17` | NixOS SSH ciphertext/public recipient and uniqueness metadata; materialized ssh -G identity binding, launcher/service installation and bootstrap exclusion are distinct package/config/security contracts. Activation text alone is not execution proof; session VM is stronger for execution. Full related-owner/history review remains pending. |
| R | `tests/check_elf_load_segments.py:67` | Every ELF in supplied closure is inspected for intersecting virtual PT_LOAD ranges and empty scan fails; catches patchelf-induced loader protection overlap. Caller ELF check/dependency-history review remains pending. |
| R | `tests/desktop-ssh.nix:33` | Wires materialized config scanner and real Python protocol owner tests using packaged script. Source scan overlaps desktop-ssh-sources, but light standalone source check may be intentional; no file removal recommended without complete owner review. |
| R | `tests/desktop-ssh-sources.nix:8` | Light public-metadata security guard; retain independent of full host closures. Duplicate source invocation in desktop-ssh is a possible later consolidation, not a validated C finding here. |

### Retained support and routing (no independent test declaration)

- R `tests/check-shards.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/vm-checks.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/configurations.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/directories.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/disko-invariants.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/distribution-owned.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/etc-file.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/fake-secrets-module.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/fake-secrets.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/fixture-checks.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/fixture-entries.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/linux-fixtures.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.
- R `tests/lib/darwin-fixtures.nix`: shared host/variant enumeration, guarded materialized-path lookup, fake-secret delivery, distribution-ownership inventory, or shard/VM routing used by retained checks. Removing it would orphan current callers; no test-only production API removal established.

### Remaining inventory requiring completion

These files have no completed per-declaration disposition in this report. Some were read partly or wholly for overlap, but their complete owner/caller/history/dependency review and ledger are outstanding. They must not be silently counted as R.

- `tests/age-identity-helpers.sh`
- `tests/android-sdk.nix`
- `tests/baloo-extractor.nix`
- `tests/boot-splash.nix`
- `tests/darwin-config.nix`
- `tests/darwin-outputs.nix`
- `tests/desktop-autostart.nix`
- `tests/desktop-ssh-integration.nix`
- `tests/desktop-ssh-session.nix`
- `tests/emoji-font.nix`
- `tests/fixtures/hosts/hollyhock/default.nix`
- `tests/fixtures/hosts/hollyhock/host.nix`
- `tests/fixtures/hosts/juniper/default.nix`
- `tests/fixtures/hosts/juniper/host.nix`
- `tests/fixtures/hosts/magnolia/default.nix`
- `tests/fixtures/hosts/magnolia/host.nix`
- `tests/fixtures/openrouter-models/models-2026-10-23.json`
- `tests/iphone-restore.nix`
- `tests/kde-theme.nix`
- `tests/kubernetes-tools.nix`
- `tests/lib/android-pin.nix`
- `tests/lib/cross-model-peers.nix`
- `tests/linux-host-secrets.nix`
- `tests/linux-host-secrets.sh`
- `tests/minikube-autostart.nix`
- `tests/minikube-darwin-start.sh`
- `tests/mobile-devices.sh`
- `tests/nix-cleanup.nix`
- `tests/nixos-rebuild-helper.nix`
- `tests/non-nixos-outputs.nix`
- `tests/non-nixos-scripts.nix`
- `tests/nr-darwin.sh`
- `tests/nr-linux.sh`
- `tests/nr.sh`
- `tests/pinentry-card-darwin.sh`
- `tests/pinentry-card.sh`
- `tests/plasma-taskbar.nix`
- `tests/podman-containers.nix`
- `tests/podman-machine-resources.sh`
- `tests/podman-prune.nix`
- `tests/podman-registry-auth.nix`
- `tests/printing.nix`
- `tests/proton-vpn.nix`
- `tests/session-variables.nix`
- `tests/shell-utilities.nix`
- `tests/tailscale-provisioning.nix`
- `tests/test-audit-skill.nix`
- `tests/test_desktop_ssh.py`
- `tests/test_serve_html.py`
- `tests/test_synthetic_models_watch.py`
- `tests/udev-device-access.nix`
- `tests/vscodium.nix`
- `tests/wifi-provisioning.nix`
- `tests/wifiman.nix`
- `tests/winbox.nix`
- `tests/yubikey-fido.nix`

Inventory reconciliation: 103 manifest files; 47 have rows above (including conservative/pending-depth R rows and support files), 56 remain explicitly unclassified. This does not meet the campaign completion criterion.
