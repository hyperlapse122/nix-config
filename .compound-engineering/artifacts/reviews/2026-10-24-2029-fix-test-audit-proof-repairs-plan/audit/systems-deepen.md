# Systems audit completion at 09e9f5a

Read-only review of all 47 files (4,336 lines) in `systems-deepen-files.txt`. Every assigned declaration is classified below; support/routing files are identified separately. R retains an independent contract; F repairs its proof; C moves its unique assertions into a named keeper before consolidation; D exercises no repository contract. No repository files, index, commits, branches, remotes, host state, cards, or real secrets changed. No nested agents. The report and controls are outside the checkout.

Read the requested store `test-audit` skill, audit reference and campaign, root instructions, complete assigned files, production owners, relevant assembly/package/dependency source, callers, history and CI. This report supersedes the conservative/pending rows for these files in `systems.md`; it does not re-audit the platform/security/desktop manifests. Neighbor suites were read only to establish overlap. Parent-owned python3-runtime and gpg-agent-no-cache findings are excluded.

## Evidence and limits

Parent baseline at `09e9f5aaf56f3bb549c69bc8499de9c208737e4d`: all-system flake evaluation and native Darwin outputs PASS; source Python tests PASS except Linux-only desktop SSH, unavailable because Darwin lacks SO_PEERCRED. Corrected GNU-tool/TMPDIR source runners PASS, per `baseline-status.txt` and task handoff. No Linux build/VM or physical hardware result is inferred from those passes. Podman is stopped and no Linux builder is configured.

Fresh standalone archive: `/private/tmp/nix-config-test-audit/deepen-controls`, extracted with `git archive HEAD`, no `.git`. `results.json` records native passes for Android parity (12 declarations), Docker helper (11), publisher (3), root installer (6), user installer (10), and workflow baseline. `installer-ignores-equality.log` and `workflow-false-gate.log` record surviving bad mutations. `materialization.json` records successful evaluation and identical complete check derivation paths after delivery-breaking overrides, not executed Linux checks. `workflow-alpha-rename.log` records an incorrect failure for a semantics-preserving rename. Prior F3 saved builder scripts/logs and valid-wrong-recipient control logs were inspected; their evidence remains valid. No whole-suite rerun was necessary.

## Prior hypothesis disposition

| Prior ID | Verdict and added verification |
| --- | --- |
| F1 | Confirmed. Fresh baseline and quoted `false &&` prefix on flake-check both return 0. The job-level gate can permanently disable its contract. Keep the existing finding and complete-scalar/job-level repair from `systems.md`, not a second finding. |
| F2 | Confirmed. Fresh 10-test user installer baseline and equality-to-parse-success mutant both pass. The saved valid-wrong-recipient control rejects original and installs with mutant. Preserve corrupt-input coverage when repairing the valid mismatch case. |
| F3 | Confirmed. Full owner/recovery/metadata review and saved baseline/empty-recipient generated builders show the claimed false pass. `sops-recipients` never compares bootstrap recipient files; no alternate keeper replaces this contract. |
| C1 | Confirmed with carry-first condition. Exact successful Docker key set is unique to line 72; move it into the three-registry routing table before dropping line 66's one-off. Both call the same real subprocess, routing and helper. |
| D1 | Confirmed. Lines 391-396 invoke only Git twice and count its values; there is no repository owner in that path. Real linked-worktree commit cases at 364-389 retain hook delivery. No production/support seam is unlocked. |

These are validations of existing report IDs, not additional findings. Their original locations, minimal fixes and history remain in `systems.md`.

## New findings

### F4 — Logitech proof bypasses the installed rules directory

`tests/logitech-wakeup.nix:26-29` writes `services.udev.extraRules` into a new check-owned text file and greps that, rather than the rules NixOS installs. Concrete control: force `environment.etc."udev/rules.d".enable = false` on every evaluated host. The delivery is disabled but the entire Logitech check has the identical drvPath (`materialization.json`: sameBuilder=true, sameDerivation=true, enabled=false). This is stronger than matching a passing fragment; none of this check's inputs change. No native Linux execution is claimed.

Retain receiver-specific vendor/product/wakeup policy. Minimal fix: resolve the enabled, correctly targeted rules directory through `tests/lib/etc-file.nix`, inspect its uncommented installed rule(s), and fail on missing/disabled/retargeted output. A generic disabled-directory mutation also trips neighboring `udev-device-access`; that suite guards other devices, not the Logitech line. It cannot substitute for selective omission/corruption of this receiver rule. Keep its independent ordering/device contracts. History: `72980a0` introduced this proxy with the feature, `2defda5` generalized host iteration without changing the observation boundary. Owner is the Logitech rule in `modules/nixos/system/base.nix`; pinned nixpkgs `nixos/modules/services/hardware/udev.nix:14-16,508-515` compiles extraRules through a package into environment.etc, and `system/etc/etc.nix:10` filters disabled entries. Focused follow-up: build logitech-wakeup with baseline, missing-line, disabled and retargeted mutations on Linux, requiring builder diagnostics.

### F5 — sysctl proof ignores the effective destination

`tests/kernel-sysctl.nix:34-45` checks source contents and enable but never target. Force the entry target to `disabled-sysctl.conf`: it is no longer in `/etc/sysctl.d`, so systemd-sysctl cannot consume this configuration. The complete check drvPath remains identical (`materialization.json`). Pinned nixpkgs etc builder uses each entry's target, not its attribute name (`system/etc/etc.nix:23-38,62`).

Retain all four independent numeric defaults and enabled delivery. Minimal fix: use `tests/lib/etc-file.nix` to require the expected effective path before inspecting bytes, or inspect `system.build.etc/etc/sysctl.d/60-nixos.conf`. No other assigned check proves these rendered values at the consumer destination; host compilation alone permits a valid retarget. History: `cff6fad` intentionally added rendered-file proof; `aed6f7e` changed boolean rendering and `2defda5` host enumeration, leaving target unchecked. Owner is base.nix; systemd-sysctl is the consumer. Linux follow-up: baseline and retarget/remove-line controls; no VM is needed for the generated-file contract.

### F6 — Darwin target assertion fails an identifier-only refactor

`tests/check-workflow-docs-skip.sh:238` requires the literal Nix lambda `map (n: ...${n}...)`. Rename that lambda's bound variable consistently to `checkName` in workflow source: target list and behavior are unchanged, but the suite exits 1 with `job 'hosts' does not list the aarch64-darwin checks in darwin_targets` (`workflow-alpha-rename.log`). This is implementation-shape proof, not a stable spelling of a public key or byte contract.

Keep the independent contract that both variants of every Darwin host and every Darwin check enter the matrix, with globbing disabled for splitting. Minimal fix: run the workflow's actual extracted Nix list expression against a small flake fixture containing distinct host/check sentinels, assert the resulting list, and drive target splitting with a recording nix stub; do not duplicate the expected expression in the test. Keep native runner and matrix-consumer checks. History: introduced with Darwin support `64f5c67`, refined in `817fc07`; same exact expression survives. Existing `darwin-outputs` builds systems but does not prove workflow matrix enumeration. Follow-up control: alpha rename stays green; omit one variant/check and turn globbing on with a matching fixture filename, each turns red. No changes were made.

## Owners, dependencies, overlap and CI routing

All ordinary assigned Nix checks are declared in `flake.nix` and included exactly once through `check-shards.nix`; `check-shards-guard` checks missing/unknown/duplicate membership and empty shards. `hostClosureChecks` places desktop-ssh, user-avatar and the ELF closure scan in the hosts shard. ghq, git-lfs and git-trim are light-shard checks: their direct inputs are the user package environment and rendered Git config, rather than the full host toplevel. The remaining config/routing guards are light checks. The workflow dynamically lists shards, separate vmChecks and native architecture outputs. Bootstrap and production are separate inputs, not duplicate fixtures: profile gating and lifecycle differ. `fmt` always runs, markdown-lint runs alone only for definitive docs-only PRs. Source classifiers and workflow routing are distinct owners.

| Boundary | Owner/callers/dependencies inspected | Keeper and why neighboring proof is distinct |
| --- | --- | --- |
| Boot | hosts' disko declarations; boot.nix; disko testLib assembly; boot-layout and disko-invariants helper | Invariants cover every NixOS layout. VM formats/boots one disposable layout with real imported boot module; LUKS2/subvolume/swap outcomes are not proven by raw options. Neither proves firmware/TPM hardware. |
| Secret publication | secrets.nix calls packaged publish-cli-auth as destination user through SOPS ExecStartPost; recover-age-identity invokes packaged root/user installers; non-nixos-secrets activation calls packaged host-secrets stage/publish | Publisher unit suite owns schema/validation; host-secrets owns real crypto/staging/failure cleanup; auth VM owns systemd/SOPS traversal/ownership/reactivation and real CLI consumption; Ubuntu VM owns distribution-preserving actual apply. No suite substitutes for the others. |
| Secret metadata | bootstrap directories, recover-age-identity; .sops.yaml; per-file encrypted metadata; shell yq first-match parser and fixture encryptions | bootstrap check owns paired recovery material and recipient association (F3); SOPS check owns exact file/rule recipients and non-age rejection. Decryptability does not establish authorization metadata and vice versa. |
| Git tools | home/h82/dev/{git,ghq}.nix; HM git.nix rendering including absolute LFS filters; nixpkgs ghq/git-trim/gh/glab package definitions; pinned libgit2 config-discovery learning | ghq runs installed binary against rendered config. LFS commits/checks out actual blob. trim uses linked worktree + distinct merged/unmerged remote refs and real libgit2 discovery path; CLI Git config reads cannot replace it. Route probes observe actual request host/path, not help flags, with reserved domains/fake tokens/offline sandbox. No destructive CLI probe was run natively. |
| Desktop SSH config | ssh.nix, system/desktop-ssh.nix, desktop-ssh package; checker sources/configuration functions; source wrappers and adjacent VM responsibilities in docs | Public metadata sources run as a cheap security guard and again when full closure config is checked. Configuration checks own launchers, effective ssh -G identity, units, absence in bootstrap/non-NixOS. Adjacent protocol/session VMs own execution, credential authorization and logout; no duplicate finding for the repeated cheap validator. Activation text is wiring evidence only, not a claimed execution receipt. |
| ELF | check_elf_load_segments.py caller elf-load-segments.nix, closureInfo roots and native system guard; nvidia.nix and patchelf-0-16 package | Scan owns virtual PT_LOAD overlap across every actual closure, all classes/endian formats handled. Package build success/ldd and limited binary startup checks cannot cover every closure member. Adjacent ranges allowed, real overlap rejected, zero scan rejected. Native Darwin cannot provide the Linux host closure scan baseline. |
| Config/hardware | base.nix, nix-ld.nix, bluetooth-audio.nix, avatar modules, shared host options/facts and assemblies; pinned NixOS etc/udev/nix-ld source | Keep independent defaults and output consumers. F4/F5 narrow the failed observation boundaries, not removal of static proof. Nix-ld options contract is separate from runtime linkability; avatar compares built consumer files, not just declaration. |
| Android parity | android-sdk-repo-parity.py, flake invocation against committed pin and nixpkgs repo.json, android-sdk-release converter consumer | Unit scenarios own revision/schema policy; live snapshot comparison owns converter parity. Skip-newer policy and require-at-least-one-comparison are intentionally both needed. No test-only production API introduced: parity script is check infrastructure. |
| Hook | scripts/lint-staged-markdown, .githooks/pre-commit, mise task/pins, markdownlint config and flake copied fixture | Real Git index/linked worktrees plus real markdownlint own staged-file and hook behavior. Trust stub checks the exact security environment passed to the external process; it does not claim real mise acceptance. D1 alone merely tests dependency replacement semantics. |

## Declaration ledger

Nix runCommand/nixosTest declarations group their internal assertion classes below, naming each distinct contract. Python methods and shell scenario calls have individual rows. Setup, fixture constructors and helper functions are support, not independent test declarations.

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

### Shell classifier and workflow declarations

| Mark | Location/declaration | Contract; credible regression |
| --- | --- | --- |
| R | `tests/ci-docs-only-paths.sh:31` docs roots | docs/*.md is eligible; removing the prefix rule loses the documented optimization. |
| R | `tests/ci-docs-only-paths.sh:32` artifact roots | plans and solutions are eligible; narrowing to docs alone misroutes them. |
| R | `tests/ci-docs-only-paths.sh:35` mixed root Markdown/docs | all eligible paths accepted; requiring one category rejects valid mixed changes. |
| R | `tests/ci-docs-only-paths.sh:36` one non-doc among docs | all paths must qualify; any-path logic skips Nix code validation. |
| R | `tests/ci-docs-only-paths.sh:37` nested README | only root Markdown is eligible; basename-only logic skips secret docs consumers. |
| R | `tests/ci-docs-only-paths.sh:38` docs2 prefix | directory boundary exact; loose prefix hides code. |
| R | `tests/ci-docs-only-paths.sh:39` root README alone | root Markdown accepted without docs companion; incorrect slash handling rejects it. |
| R | `tests/ci-docs-only-paths.sh:40` script path | runtime scripts require Nix validation; catch-all eligibility skips it. |
| R | `tests/ci-docs-only-paths.sh:41` non-artifacts compound path | configuration under .compound-engineering is not prose; broad root eligibility skips it. |
| R | `tests/ci-docs-only-paths.sh:43` empty input | unknown changes run full validation; all([]) would skip it. |
| F | `tests/check-workflow-docs-skip.sh:250` `assert_gated flake-check` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| F | `tests/check-workflow-docs-skip.sh:251` `assert_gated hosts` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| F | `tests/check-workflow-docs-skip.sh:252` `assert_gated build list` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| F | `tests/check-workflow-docs-skip.sh:253` `assert_gated build-linux list` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| R | `tests/check-workflow-docs-skip.sh:254` `assert_matrix_from_hosts build targets` | build consumes hosts.targets and depends on hosts; literal matrix misses new hosts. |
| R | `tests/check-workflow-docs-skip.sh:255` `assert_matrix_from_hosts build-linux linux_targets` | build-linux consumes linux_targets; wrong output loses standalone outputs. |
| F | `tests/check-workflow-docs-skip.sh:256` `assert_gated build-darwin list` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| R | `tests/check-workflow-docs-skip.sh:257` `assert_matrix_from_hosts build-darwin darwin_targets` | build-darwin consumes darwin_targets; wrong output loses Macs/checks. |
| R | `tests/check-workflow-docs-skip.sh:258` `assert_native_darwin` | Darwin builds on macos-15; Linux runner cannot build native outputs. |
| F | `tests/check-workflow-docs-skip.sh:259` `assert_darwin_targets` | F6: all Darwin variants/checks and safe target splitting; alpha rename wrongly fails. |
| R | `tests/check-workflow-docs-skip.sh:260` `assert_native_arm` | aarch64 Linux goes to arm runner; fixed x86 runner changes supported architecture. |
| F | `tests/check-workflow-docs-skip.sh:261` `assert_gated check-shard-names` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| F | `tests/check-workflow-docs-skip.sh:262` `assert_gated check-shards list` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| R | `tests/check-workflow-docs-skip.sh:263` `assert_empty_list_fails check-shard-names` | shard lister rejects empty before output; empty list could make green no-build CI. |
| R | `tests/check-workflow-docs-skip.sh:264` `assert_matrix_from check-shards check-shard-names names name` | check-shards consumes lister names; hardcoded list misses new checks. |
| F | `tests/check-workflow-docs-skip.sh:265` `assert_gated vm-check-names` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| F | `tests/check-workflow-docs-skip.sh:266` `assert_gated vm-checks list` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |
| R | `tests/check-workflow-docs-skip.sh:267` `assert_empty_list_fails vm-check-names` | VM lister rejects empty before output; empty list could skip every VM. |
| R | `tests/check-workflow-docs-skip.sh:268` `assert_matrix_from vm-checks vm-check-names names name` | vm-checks consumes lister names; fixed inventory misses newly registered VM. |
| R | `tests/check-workflow-docs-skip.sh:269` `assert_unconditional fmt` | fmt has neither classifier dependency nor gate; docs classifier outage must not skip formatting. |
| F | `tests/check-workflow-docs-skip.sh:270` `assert_docs_only_only markdown-lint` | F1: full event/classifier gate must run validation unless definitive docs-only (markdown is the complement); extra false prefix/true suffix passes substring guard. |

### Staged Markdown declarations

| Mark | Location | Contract; credible regression |
| --- | --- | --- |
| R | `tests/lint-staged-markdown.sh:48` | Declared mise TOML/lock/nixpkgs linter versions agree; divergent tools give different commit/CI verdicts. |
| R | `tests/lint-staged-markdown.sh:60` | Each mismatched version input is rejected; ineffective parity guard would accept divergence. |
| R | `tests/lint-staged-markdown.sh:109` | Bad staged docs fail with file/line/rule and repair guidance; lost failure propagation/diagnostics. |
| R | `tests/lint-staged-markdown.sh:118` | Clean staged docs pass; unconditional failure blocks commits. |
| R | `tests/lint-staged-markdown.sh:134` | Non-Markdown staging never invokes linter; unnecessary invocation can block unrelated commits. |
| R | `tests/lint-staged-markdown.sh:159` | Scratch subprocess receives resolved trusted path; shim refuses untrusted staged mise config. |
| R | `tests/lint-staged-markdown.sh:165` | Scratch subprocess receives MISE_SAFE=1; staged config must not gain environment execution. |
| R | `tests/lint-staged-markdown.sh:177` | Symlink TMPDIR trust resolves physical path; lexical /var path fails mise trust. |
| R | `tests/lint-staged-markdown.sh:191` | No persistent mise trust command; temporary validation must not mutate user trust store. |
| R | `tests/lint-staged-markdown.sh:200` | Outside-config globs ignored; staged secrets Markdown not included by policy. |
| R | `tests/lint-staged-markdown.sh:220` | Root README and artifact-plan errors both fail; narrowed globs silently omit one documented root. |
| R | `tests/lint-staged-markdown.sh:232` | Bad index/clean worktree fails; reading working tree would miss committed error. |
| R | `tests/lint-staged-markdown.sh:242` | Clean index/bad worktree passes; reading unstaged changes blocks valid commit. |
| R | `tests/lint-staged-markdown.sh:253` | Staged deletion passes; linting removed path spuriously fails. |
| R | `tests/lint-staged-markdown.sh:269` | Space-containing bad and clean names work; unquoted splitting drops/misroutes path. |
| R | `tests/lint-staged-markdown.sh:283` | Unborn staged bad file fails; HEAD-based diff cannot enumerate initial commit. |
| R | `tests/lint-staged-markdown.sh:298` | Failing lint preserves index and working bytes; accidental --fix changes user state. |
| R | `tests/lint-staged-markdown.sh:311` | Staged symlink target is linted; treating symlink text alone misses target errors. |
| R | `tests/lint-staged-markdown.sh:328` | Nested config reaches index scratch; copying only selected files loses inherited config. |
| R | `tests/lint-staged-markdown.sh:333` | Declared task points to script tested; stale mise task bypasses current behavior. |
| R | `tests/lint-staged-markdown.sh:370` | Real linked-worktree bad commit fails with MD032; hook path broken in linked checkout. |
| R | `tests/lint-staged-markdown.sh:376` | Real linked-worktree clean commit succeeds; malformed hook/task blocks all commits. |
| R | `tests/lint-staged-markdown.sh:389` | Branch without hook can commit; global hooks path must not break earlier branches. |
| D | `tests/lint-staged-markdown.sh:396` | D1: direct Git replace-value self-test, no repository owner; real hook commit scenarios remain. |

### Nix checks and scanners

| Mark | Declaration | Distinct contracts; credible regression |
| --- | --- | --- |
| R | `tests/auth-provisioning.nix:29` | Missing ciphertext makes actual switch fail; valid fake SOPS tokens become user-readable regular 0600 gh/glab configs; optional provider tokens remain 0400 and are excluded from CLI publisher; repeat switch/deleted config repair works; absent/corrupt age identity fails and packaged restore repairs 0600 root:root; planted config-dir symlink refuses outside writes; gh/glab consume auth; journal contains no canaries. Broken SOPS service ordering/umask/reactivation or privilege boundary fails these separate outcomes. Linux VM unavailable. |
| R | `tests/boot-layout-invariants.nix:17` | Nonempty fleet; disk/main partition shape, vfat /boot ESP, LUKS type/name/LUKS2 args, btrfs type, each root/home/nix/log/swap mount and swapfile. A new unbooted host layout drift fails even when first-host VM still boots. |
| R | `tests/boot-layout.nix:58` | Disposable upstream disko format/mount/install/boot with imported bootstrap boot module and passphrase; actual LUKS2 header; each of five btrfs subvolumes; swap file exists. Runtime assembly/boot errors are distinct from fleet shape guard. Linux VM unavailable. |
| F | `tests/bootstrap-recipients.nix:41,84` | F3 recipient association; retain bidirectional host/bootstrap directory pairing, no-empty inventory, both recovery files and exact authorized recipient. Missing side/file fails; empty/substrings currently evade association guard. |
| R | `tests/check-shards-guard.nix:36` | Every check appears in one shard, no unknown member, nonempty shard set and each shard nonempty; omissions silently skip CI, multiple-shard assignments waste jobs, stale names fail builds. Names-only observation avoids recursively building subjects. |
| R | `tests/check_elf_load_segments.py:19,62,67` | ELF32/64 little/big-endian executable/shared PT_LOAD virtual ranges; sorted adjacent range intersection; no-overlap result and nonempty scan; closure walk ignores non-ELF/symlink aliases and reports all overlaps. Patchelf produces new intersecting load ranges while package build succeeds. All invoked by elf-load-segments.nix, not orphan helpers. Linux closure unavailable. |
| R | `tests/check_desktop_ssh_config.py:17` `sources` | Exact ciphertext fields/provider constraints, recipient and first-rule host association, valid Ed25519 public metadata and cross-host uniqueness, nonempty NixOS scan; copied/wrong-host key, extra provider or missing source fails. Independent public security metadata, no decrypt. |
| R | `tests/check_desktop_ssh_config.py:61` `configuration` | User-owned config installation wiring rather than store link; NixOS fallback agent selection bytes; bootstrap/non-NixOS unit/config absence and legacy identity; production effective ssh -G identity/agent bound to this host public key; three packaged launcher destinations; unmasked lifecycle-bound user service and target wants link; unmasked credential-delivery provisioner with matching public/key argv and no boot target install. Wrong selected identity, dead launcher, masked unit or leaked bootstrap service fails. Static activation fragment proves wiring only; adjacent session VM owns execution. |
| R | `tests/desktop-ssh.nix:33` | Builds every relevant user/materialized system config for scanner and runs pinned packaged protocol suite. Lost wrapper substitutions/interpreter/crypto dependency or host/profile wiring fails; source-only scan cannot cover these. Linux-only suite unavailable natively. |
| R | `tests/desktop-ssh-sources.nix:8` | Closure-independent public-source security check invokes shared validator; omission of source metadata fails early without building desktops. Repeat shared validation is cheap; no separate predicate implementation or test-only production seam to remove. |
| R | `tests/ghq.nix:48` | home.path executable package, rendered Git config, root equals HOME/src, real ghq create initializes exact host/owner/repo path, list reports it. Installed program ignoring config or gated out in bootstrap fails. |
| R | `tests/git-cli-repo-flags.nix:73` | gh PR/repo forms reach named enterprise host; gh api also expands repository; glab MR/repo/API/delete forms reach host and correct encoded project/request method. Packages resolved from every user's actual package list, missing-package and nonempty-kind guards. Dependency routing drift to public forge is caught before offline connection; no native destructive probe executed. |
| R | `tests/git-lfs.nix:54` | Installed git-lfs and rendered filter, commit stores pointer to independently hashed fixture, checkout restores bytes. Missing filter delivery, wrong content or skipSmudge default fails; package presence alone cannot prove it. |
| R | `tests/git-trim.nix:59` | Installed trim, rendered confirm policy, real config discovery, merged local deleted while origin survives; unmerged local/remote kept; linked worktree remains on current branch; main survives. Upstream delete/detach defaults returning fails actual ref/HEAD assertions. Independent from LFS/ghq despite shared Git setup. |
| R | `tests/host-name-guard.nix:45` | Real/fixture host names dynamically forbidden in shared code, nonempty inventory and every scanned root exists, grep operational failure fails. Hardcoded host branching or missing scanner roots fails; host names are policy bytes, not private identifiers. |
| R | `tests/host-options.nix:49` | Every declared shared option equals system versus HM, no home source reads osConfig, nonempty/bootstrap guard. Dropped bridge field/trait or standalone coupling fails; declared paths enumerate cases but expected values come independently from system configuration. |
| R | `tests/host-secrets.nix:32` | Missing/foreign/loose/symlink identity, undecryptable SSH, invalid/missing token and invalid private key each fail with cause and cleanup/no canary; real stage then publish twice installs private configs/token modes and matching SSH public key; removes retired token; planted SSH symlink refuses write and staging remains absent. Broken stage cleanup/decryption order/rotation/publication fails at real package boundary. Linux package build unavailable. |
| F | `tests/kernel-sysctl.nix:49` | F5 target delivery; retain enabled file and whole-line inotify/IPv4/IPv6 numeric policy. Wrong number/removal fails, but retargeted file currently passes identical check. |
| F | `tests/logitech-wakeup.nix:35` | F4 installed-rule delivery; preserve Unifying/Bolt IDs and disabled remote wakeup policy, repair proxy observation. Source deletion/value drift fails; output disabled currently invisible. |
| R | `tests/nix-ld.nix:71` | Enabled loader config, expected ldso path, exact NIX_LD/NIX_LD_LIBRARY_PATH, baseline gcc/zlib/openssl package declarations. Loader/path/default library changes fail. This is declared platform config proof, not a claim arbitrary foreign ELF executes. Upstream defaults do not invalidate the independent resulting-config contract. |
| R | `tests/non-nixos-vm.nix:99` | Ubuntu bootstrap actually applies system-manager/HM; private pcscd socket, shell/marker/profile; no publication; absent/foreign identity refuses nr and direct HM before changing generation; documented installer valid path; production/repeat/bootstrap/production preserve private account-owned auth/key; ssh selects key, public key matches fixture; user databases/subids/shell list unchanged and canaries absent from output/journal. Actual activation lifecycle distinct from script stubs. Linux VM unavailable. |
| R | `tests/sops-recipients.nix:27` | Live repo metadata; valid/comma-space/overlap-first accepted; top/nested extra and missing recipient rejected; each of six non-age groups rejected; overlap-second/pgp-only/key_groups/no-rule/yml/plain/empty tree rejected for intended reason. Actual sops age encryptions create fixtures. Wrong first-match/authorization/provider policy fails. |
| R | `tests/sops-recipients.sh:23` | Shared guard implementation consumed by prior fixture suite and real-tree scan; exact sorted age sets, first matching creation rule, no key_groups/provider and nonempty encrypted inventory. Preserve as used test support; no production seam. |
| R | `tests/user-avatar.nix:60` | Built .face and .face.icon bytes match source; system-profile SDDM face independently matches asset; missing generation/file fails. Removing system path breaks private-home greeter even if user file remains, so neither consumer replaces the other. |
| R | `tests/vm-checks-guard.nix:39` | Ordinary check set contains no nixos-test feature; nonempty VM registry all recognized using raw lazy test derivation features. Misregistration fails and detector returning no results cannot pass vacuously. |
| R | `tests/wifi-assertions.nix:41` cases | Case-colliding labels rejected; hyphen rejected; digit-prefix rejected; valid distinct labels accepted. Removing uniqueness/identifier guard or rejecting ordinary labels fails. Same minimal module fixture with positive case constrains unrelated-assertion masking; diagnostics would be useful but no confirmed false pass from current fixture. |
| R | `tests/wireplumber-bluetooth.nix:65` | Service enabled, nonempty data path; actual loaded conf.d fragment supplies false and none supplies true (JSON or SPA assignment forms). Changed setting/overriding true fragment fails. Service lifecycle and real headset behavior remain separate manual proof. |

### Retained support/routing declarations

These contain no independent test methods to delete. Used test helpers and fixture assembly are not production seams merely because they reside under tests/lib.

| Mark | File and exported support | Concrete consumers/contract; regression |
| --- | --- | --- |
| R | `tests/check-shards.nix:25` members/shards | flake legacy checkShards and guard/CI; assigns sorted light checks modulo lightCount, host closure checks together, linkFarm forces each member; missing membership would omit actual checks and guard catches it. |
| R | `tests/vm-checks.nix:17` registry | flake vmChecks, VM guard and CI lister; each named actual VM plus aggregate outside ordinary checks; deleting registration would drop lifecycle proof, not obsolete fixture cleanup. |
| R | `tests/lib/configurations.nix:59` entryOf/entries/production/bootstraps | All host-dependent checks consume evaluated production/bootstrap config + HM user; new hosts must join automatically; absent HM becomes explicit check failure. |
| R | `tests/lib/configurations.nix:71` withTraitForcedOff/withTrait | Device/service checks consume positive and independent forced-off entries when fleet has no negative; guards reject absent positive production trait. Removal after last negative host would make negative branch empty. |
| R | `tests/lib/configurations.nix:82` linuxFixtures/userEntries/userGuard/guard | Architecture-filtered fixtures plus NixOS users feed shared HM checks; nonempty host/bootstrap/kind guards prevent vacuous scans. Foreign closure interpolation would demand unavailable builders. |
| R | `tests/lib/darwin-fixtures.nix:16` | flake darwin-config/darwin-outputs; discover Darwin fixture directories and call actual darwin assembly in both variants; handbuilt fake HM config would miss assembly regressions. |
| R | `tests/lib/directories.nix:4` | Production lib/hosts.nix as well as bootstrap/name guards; enumerate only real child directories. This already has a non-test caller; deleting as a test seam would break production discovery. |
| R | `tests/lib/disko-invariants.nix:15` diskOf/hostNames/problems | Both fleet invariant builder and first-host boot VM use it; distinct stable boot interface requirements with independent expected mountpoints. Removed/new non-NixOS host must not be treated as disk-bearing NixOS. |
| R | `tests/lib/distribution-owned.nix:3` | Ubuntu VM hashes files before/after and non-nixos-outputs forbids managed keys; independent seven-file policy inventory, not copied observed outputs. Missing shadow/subid/shells case could permit distribution takeover. |
| R | `tests/lib/etc-file.nix:4` | baloo, printing, WinBox check consumers; enabled + effective target lookup returns source or null; disabled/retargeted declared source must be treated as missing. Reusable keeper for F4/F5, not unused scaffolding. |
| R | `tests/lib/fake-secrets-module.nix:4` | fixture-entries injects into Linux/Darwin HM assembly; routes actual production secret owner to generated fake ciphertext without replacing its implementation. Deleting loses fixture buildability or accesses absent real-host metadata. |
| R | `tests/lib/fake-secrets.nix:19` | host-secrets, non-NixOS VM, fixture module; actual age/SOPS/Ed25519 data, distinct foreign identity and bad SSH/token/schema variants plus canaries. Distinctness makes wrong selection observable; fixtures supply inputs, not fabricated owner receipts. |
| R | `tests/lib/fixture-checks.nix:9` | flake x86/aarch64 check maps and hosts shard; native-architecture activation/system-manager outputs, both variants; omission loses architecture build evidence. |
| R | `tests/lib/fixture-entries.nix:8` | linux/darwin fixture constructors; maps both variant booleans through actual mkHost with fake source module; shared constructor is legitimate support. |
| R | `tests/lib/linux-fixtures.nix:16` | flake fixture checks, configurations and Ubuntu VM; discovery through lib/hosts + same lib/linux-host as production; fabricated alternative assembly would conceal host wiring regressions. |

## Layer recommendation

No entire assigned file is retired. F1-F6 repair proof at its current boundary. C1 carries exact Docker schema into existing routing table before removing one declaration; D1 removes only Git's direct self-test. Keep malformed/corrupt identities separately from valid wrong-recipient validation. Keep root/user installer boundaries separate; root fixture injection is used support for non-root test execution, and real root ownership/command packaging remains auth VM proof. No safe removal of production injection can be recommended before relocating those malformed/non-root scenarios to a verified privilege-boundary harness; no deletion was requested or performed.

No findings from other assigned lanes are repeated. No proposed repair, consolidation or deletion was applied. R means the test owns a useful contract after source review; it does not claim every theoretical mutation is caught or unavailable Linux execution passed.

## File history evidence

Full assigned files were read; latest-touch commits below anchor the exact revisions reviewed. Feature/review histories above explain each F/C/D disposition; shared evolution includes host-generic iteration `2defda5`, non-NixOS owner/fixture extraction `03e69a7`, Darwin assembly `64f5c67`/`817fc07`, removal-of-last-negative-host repair `e857618`, SOPS first-match/provider fixture hardening `24b5f31`/`d1bc6c3`, check sharding `ee95f9b`/`5b86547`, VM separation `110a58b`/`3f59103`, and optional secret expansion through `40a1b2e`.

| Assigned file | Latest touch |
| --- | --- |
| `tests/auth-provisioning.nix` | 40a1b2e feat(secrets): publish openrouter_api_key |
| `tests/boot-layout-invariants.nix` | a21a16c Merge branch 'main' into perf/separate-vm-checks-from-flake-check |
| `tests/boot-layout.nix` | 8766d16 test(boot): check disko invariants in flake check |
| `tests/bootstrap-recipients.nix` | ca7cab8 refactor(tests): share host directory listing and package asserts |
| `tests/check-shards-guard.nix` | ee95f9b feat(tests): partition flake checks into ci shards |
| `tests/check-shards.nix` | 5b86547 fix(review): apply review findings |
| `tests/check-workflow-docs-skip.sh` | 817fc07 fix(review): apply simplification and review findings |
| `tests/check_desktop_ssh_config.py` | 273a2a6 fix(home): install ssh config as a user-owned copy |
| `tests/check_elf_load_segments.py` | 8adfa7a test: fail on overlapping elf load segments |
| `tests/ci-docs-only-paths.sh` | 760aaaf feat(ci): add docs-only path classifier script and check |
| `tests/desktop-ssh-sources.nix` | 3e7d36d feat(ssh): integrate desktop session keys |
| `tests/desktop-ssh.nix` | 273a2a6 fix(home): install ssh config as a user-owned copy |
| `tests/ghq.nix` | 2defda5 test: iterate every host configuration in checks |
| `tests/git-cli-repo-flags.nix` | b7a47fd fix(review): set GITLAB_HOST on every glab command |
| `tests/git-lfs.nix` | 320854b feat(home): enable git lfs beside git |
| `tests/git-trim.nix` | 2defda5 test: iterate every host configuration in checks |
| `tests/host-name-guard.nix` | a236aca refactor(tests): clarify single-host check variants |
| `tests/host-options.nix` | 03e69a7 refactor(hosts): apply simplify and review findings |
| `tests/host-secrets.nix` | 40a1b2e feat(secrets): publish openrouter_api_key |
| `tests/kernel-sysctl.nix` | 2defda5 test: iterate every host configuration in checks |
| `tests/lib/configurations.nix` | e857618 chore(hosts): remove the thinkpad host and its traits |
| `tests/lib/darwin-fixtures.nix` | 817fc07 fix(review): apply simplification and review findings |
| `tests/lib/directories.nix` | ca7cab8 refactor(tests): share host directory listing and package asserts |
| `tests/lib/disko-invariants.nix` | a21a16c Merge branch 'main' into perf/separate-vm-checks-from-flake-check |
| `tests/lib/distribution-owned.nix` | 03e69a7 refactor(hosts): apply simplify and review findings |
| `tests/lib/etc-file.nix` | 5c996fc fix(review): share etc lookup, anchor winbox ports |
| `tests/lib/fake-secrets-module.nix` | 64f5c67 feat(darwin): add the darwin host kind and assembly |
| `tests/lib/fake-secrets.nix` | 40a1b2e feat(secrets): publish openrouter_api_key |
| `tests/lib/fixture-checks.nix` | 03e69a7 refactor(hosts): apply simplify and review findings |
| `tests/lib/fixture-entries.nix` | 817fc07 fix(review): apply simplification and review findings |
| `tests/lib/linux-fixtures.nix` | 817fc07 fix(review): apply simplification and review findings |
| `tests/lint-staged-markdown.sh` | fabad15 fix(review): run the hook lint in mise safe mode |
| `tests/logitech-wakeup.nix` | 2defda5 test: iterate every host configuration in checks |
| `tests/nix-ld.nix` | 2defda5 test: iterate every host configuration in checks |
| `tests/non-nixos-vm.nix` | 03e69a7 refactor(hosts): apply simplify and review findings |
| `tests/restore-age-identity.py` | d83b74b feat(nixos): make ThinkPad setup and credential rebuilds reproducible (#1) |
| `tests/sops-recipients.nix` | d1bc6c3 fix(review): apply review findings |
| `tests/sops-recipients.sh` | d1bc6c3 fix(review): apply review findings |
| `tests/test_android_sdk_repo_parity.py` | 5c91b2a fix(review): apply review findings |
| `tests/test_docker_credential_sops.py` | 72ed746 chore: simplify code per review |
| `tests/test_install_user_age_identity.py` | 03e69a7 refactor(hosts): apply simplify and review findings |
| `tests/test_publish_cli_auth.py` | d83b74b feat(nixos): make ThinkPad setup and credential rebuilds reproducible (#1) |
| `tests/user-avatar.nix` | 2defda5 test: iterate every host configuration in checks |
| `tests/vm-checks-guard.nix` | 3f59103 refactor(tests): list vm check names once in guard |
| `tests/vm-checks.nix` | 5ca1e1a test(podman): prove the weekly prune in a VM |
| `tests/wifi-assertions.nix` | 197746a chore(nixos): repoint wifi module and tests at moved secrets.nix |
| `tests/wireplumber-bluetooth.nix` | 2defda5 test: iterate every host configuration in checks |
