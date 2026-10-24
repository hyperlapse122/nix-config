# Systems security test audit

Revision: `09e9f5aaf56f3bb549c69bc8499de9c208737e4d`. Review-only; all 13 manifest files and 3,660 lines read, including fixtures and parameter rows. No repository edits, commits, pushes, real credentials, activation, or nested agents. The requested store test-audit SKILL, audit reference, and CAMPAIGN were read. This report completes the assigned manifest, not the other systems manifests. Prior systems findings and the parent's python3-runtime and gpg-agent-no-cache findings are excluded.

## Findings

### F1 — helper diagnostic cases discard the exit status

`tests/nr.sh:140` and `:145` retain stderr through `|| true` and only inspect its wording, although the reported contract explicitly requires nonzero status. The no-flake case at `:70` has the same weakness. Keep these CLI error contracts in this owner; no stronger sibling tests the NixOS helper's malformed-argument statuses. Minimal repair: capture status explicitly or fail if command substitution succeeds, then check stderr. The existing unknown-subcommand case already demonstrates the correct shape. History: `e12fe7a` introduced these cases. Credible regression: an error prints the right diagnostic but exits zero, so scripts continue after invalid input.

Evidence: a standalone `git archive` extraction, with no `.git`, lives at `/tmp/nix-config-test-audit/security-controls`. Native GNU-tool control and mutant each pass the entire `tests/nr.sh` suite (`nr-control.log`, `nr-mutant.log`, exit 0). The mutant changes only `die` for `missing value*` and `unexpected argument*` to exit 0. Physical `TMPDIR=/private/tmp` avoids the Darwin logical-path fixture mismatch seen in the first attempt. This establishes the missing-value and unknown-flag gap directly; no-flake is source-inspection evidence only.

The same defect occurs in `tests/age-identity-helpers.sh:123`: the missing-installer case only checks diagnostic text through `|| true`, despite claiming nonzero status. Its keeper is this recovery pipeline suite; neither real installer validation nor VM activation tests a missing executable in the recovery helper. Repair by asserting failure before checking the named path. History: the case was introduced in `e12fe7a`. Standalone `age-control.log` and `age-mutant.log` both pass the whole helper suite (exit 0); the mutant only changes `recover-age-identity`'s `die` to exit zero for `installer not found*`. No real GPG/card/install command is reached.

### F2 — key-loading test never supplies valid mismatched metadata

`tests/test_desktop_ssh.py:257` checks a correct encrypted pair and then a missing wallet entry. It never supplies a different valid public identity whose fingerprint has a wallet password that successfully decrypts the existing key. Thus removing only the public-key comparison in `scripts/desktop-ssh:635` is not distinguished by these inputs. Keep this independent load-time identity security contract here; `test_mismatched_metadata_and_unsafe_files_rejected` exercises provision, and the session VM only loads matching source/public material. Minimal repair: provision key A, create declared public key B, map B's fingerprint to A's password, and require `WorkingKeyUnavailable` on loading A against B; preserve the existing missing-entry test. Also include a wrong password as the distinct decryption failure row. History: `d2b8d79` introduced the declaration and comparator.

Evidence is source inspection, not a passing mutation claim. Attempted focused control/mutant executions both failed because the available Darwin Python environment lacks bcrypt (and dbus for native-wallet cases); logs `load-control.log` and `load-mutant.log` are not usable mutation evidence. Full Linux protocol execution is unavailable. The production comparator currently exists; this is a test gap, not a claim that production accepts the wrong key.

### F3 — pinentry render claim is assertion-free and tests raw source

`tests/pinentry-card.sh:513` through `:515` claims gnome/kde/none/darwin renders compile and select matching delegates, but executes only `pass`. At `:24`, the script only compiles its single argument; `flake.nix:309` passes a raw copy of `scripts/pinentry-card`, with unresolved package placeholders. The top assertions pin platform/backend constants, but cannot prove Linux package substitution or installed executable/symlink delivery. Minimal repair: replace the stale claim with a real Linux package render check using `packages/gpg-tools.nix`'s installed package, assert all placeholders resolved and both installed entry points, and compile/run that artifact. Keep Darwin's separate installed-package render check (`tests/pinentry-card-darwin.sh:29`) and the shared raw-source behavioral tests. No gnome/kde/none variant API exists in the current package, so those obsolete labels should disappear. History: the unconditional claim dates to `d83b74b`; current package has Linux Qt/curses and Darwin macOS branches. Evidence: complete caller/package inspection; no mutation execution required to show a declaration with no assertion. This is F, rather than deleting the independent package-delivery contract.

### C1 — percent-encoding case replays an already exercised happy path

`tests/pinentry-card.sh:470` (case 16) repeats the same prompt, keyring PIN, and owner as case 2's `14963605` row (`:290`) and case 1 (`:277`), all already assert the encoded value. Its useful extra assertion is that raw `D te%st pin` never appears. Carry that negative into case 1 (or the common answered-case assertion) before removing case 16's invocation. Keeper: case 1 plus its strengthened no-raw-PIN assertion; normalization remains in case 2. History: case 16 dates to `d83b74b`, and its own comment explicitly acknowledges coverage by every answered scenario. Evidence: identical fixture bytes and executable boundary; distinct alignment fixtures in cases 1 and 17 remain. No production seam is removed; no deletion-count target.

## Ownership, dependencies, history, and routing

- Recovery/preparation: complete `scripts/recover-age-identity`, `scripts/prepare-age-identity`, `packages/gpg-tools.nix`, `secrets/README.md` recovery entry points, and GPG Home Manager wiring inspected. Helpers are public operator commands, not test-only seams. Fake GPG is a reversible transport stub; fake age-keygen derives a different recipient from tampered material, rather than supplying an unconditional verification receipt. Real crypto/installer validation belongs to retained installer and host-secrets suites reviewed in the prior lane. Relevant SOPS permissions, card provisioning, materialized-output, converged-state, decorative-check, evaluator-only mutation and scratch-worktree learnings were consulted.
- Rebuild helpers: complete three script owners, `packages/nix-tools.nix`, shell alias caller, non-NixOS assembly/activation overlap, and Nix wrapper declarations inspected. `NR_SYSTEM_OUT`/`NR_HOME_OUT` have production VM callers; dry-run is public diagnostic behavior. Runtime override knobs also support fixture isolation; none is a removal candidate without replacing the remaining boundary proof. `nr.sh` history `e12fe7a`; Linux `5d357bf`, expanded `03e69a7`; Darwin `b6d2273`. Marker/package iteration expanded through `2defda5`, `0458ec4`, `03e69a7`.
- Secret-layout guard: entire shell implementation and Nix fixture builder inspected. Owner is repository `.sops.yaml` plus actual ciphertext metadata; production non-NixOS activation consumes tokens and host-only SSH, and deliberately excludes NixOS Wi-Fi/Tailscale. `a4908dc` introduced this boundary. The generic SOPS first-rule validator is distinct overlapping proof, not a substitute for host-class access policy. Fixture crypto is real age/SOPS over fake plaintext. Both metadata policy and executable activation should remain.
- Pinentry: complete both Python owners and package renderer inspected. Production GPG uses the package through `home/h82/security/gpg.nix`. Shared Assuan/keyring proof and Darwin two-process/filter/Keychain proof are independent transports. History includes `d83b74b`, card rotation `0203b7f`, Darwin Keychain `bc7c12e`, slow delegate `7b19071`, owed replies `243aa90`, piped output `f601104`, and full-stdout stall fix `60f25ec`. Slow-relay source instrumentation is coupled but intentionally creates an otherwise nondeterministic scheduler fault without adding a production API; retain it, with retarget-success checks. It does not claim real Keychain UI/card/hardware proof.
- SSH: complete `scripts/desktop-ssh` (803 lines), session gate, both package builders, NixOS provisioning/polkit module and HM SSH module inspected. Unit owner tests use real cryptography and Unix protocol endpoints; the transport VM uses packaged OpenSSH, Git/scp/sftp and real sshd; session VM uses actual PAM/logind/systemd/polkit/SOPS and a fake D-Bus wallet that persists only the state its methods actually write. These are distinct security and lifecycle boundaries. `d2b8d79` added KWallet identity protection, `6210140` fallback, `3e7d36d` session integration, `45c7afc` bounded connections, `6ce4935` signing-failure coverage, and `a439963` fixed real dbus-python overload selection. The overload test feeds overload introspection through actual dbus-python parser/proxy/marshaller; it is an SDK compatibility contract, not disposable mock call-shape proof. Dependency API calls and cryptography serialization/verification paths were inspected locally; native dbus execution is unavailable in the current environment.
- Routing: `flake.nix` declares `nr`, `age-identity-helpers`, `linux-host-secrets`, `nixos-rebuild-helper`, the three non-NixOS checks and `desktop-ssh`; common checks include pinentry Linux/Darwin tests. `tests/check-shards.nix` assigns ordinary Linux checks dynamically; the helper wiring check reads host closures. `tests/vm-checks.nix:24` and `:25` register SSH transport/session VMs outside ordinary checks. `.github/workflows/check.yml` builds dynamic x86 shards/VM matrices, native arm checks, and all native Darwin checks. Source/protocol desktop-ssh checks do not substitute for VMs. Docs-only workflow skips do not change this audit's unavailable execution status.

## Execution evidence and limits

Parent baseline: all-system evaluation and Darwin output check PASS. Parent GNU-shell baseline records nr, nr-linux, nr-darwin, and age-identity-helpers PASS. Full desktop SSH Python suite is not a native Darwin test (SO_PEERCRED/Linux lifecycle); its attempted environment also lacks bcrypt/dbus, so do not count its unrelated errors as production failures or a suite pass. Both SSH VMs, Linux secret policy/check derivations, and Linux rendered pinentry behavior remain unexecuted here: no Linux builder/KVM and stopped Podman. No whole-suite rerun was needed. The focused nr and recovery-helper control/mutant pairs succeeded in this review. Evaluation does not prove builder assertions. Hardware PIN entry/Keychain UI remain separate manual evidence.

## Declaration ledger

R = retain; F = repair proof while retaining contract; C = move named proof into keeper first; D = delete. No D recommendation is necessary. Row locations identify declarations or end-of-scenario assertions. Table rows inside one scenario retain the same disposition unless noted. Credible regressions are stated per row.

### tests/age-identity-helpers.sh

| Mark | Line | Contract and credible regression |
| --- | --- | --- |
| R | 47 | GPG is moved under sudo or recipient/ciphertext resolution changes. |
| R | 55 | unknown host succeeds or hides available hosts. |
| R | 62 | rescue hostname failure omits explicit-host recovery hint. |
| R | 112 | executed pipeline loses stdin key bytes or recipient argv. |
| R | 120 | installer success masks GPG failure without pipefail. |
| F | 126 | missing installer is reported only as broken pipe. |
| R | 137 | user mode silently infers distribution hostname. |
| R | 144 | user recovery selects privileged installer. |
| R | 152 | actual user installer never receives decrypted stdin. |
| R | 245 | successful preparation omits one public recovery artifact. |
| R | 248 | successful cleanup leaves runtime plaintext. |
| R | 253 | identity is copied into repository rather than encrypted. |
| R | 259 | preparation overwrites existing host recovery material. |
| R | 269 | tampered round-trip ciphertext is accepted or partial files remain. |
| R | 272 | failure cleanup leaves runtime identity. |
| R | 298 | failed encryption leaves half-written host recovery directory. |
| R | 336 | termination leaves ciphertext or runtime key material. |
| R | 359 | root bypasses user-agent/card boundary. |
| R | 368 | status output prints identity bytes. |

### tests/nr.sh

| Mark | Line | Contract and credible regression |
| --- | --- | --- |
| R | 45 | build references the wrong output/path. |
| R | 49 | explicit target is ignored. |
| R | 54 | default stops following local hostname. |
| R | 65 | nonrepository invocation continues without explicit checkout. |
| F | 72 | missing flake diagnostic disappears (nonzero proof also needs F1 repair). |
| R | 78 | clean checkout emits false warning. |
| R | 85 | untracked input is silently omitted or warning aborts build. |
| R | 101 | bootstrap switch/boot/test silently targets production. |
| R | 105 | explicit bootstrap-to-production request remains blocked. |
| R | 109 | bootstrap marker blocks unprivileged build. |
| R | 114 | production marker blocks ordinary apply. |
| R | 119 | older generations lacking marker cannot apply. |
| R | 129 | switch/test dry-run names wrong diff source. |
| R | 134 | boot dry-run names running generation instead of profile. |
| F | 143 | malformed flag prints diagnostic but succeeds (F1). |
| F | 147 | unknown flag prints diagnostic but succeeds (F1). |
| R | 195 | unchanged generation invokes diff or hides no-change result. |
| R | 204 | switch diffs wrong order or source links. |
| R | 222 | boot compares current-system against profile with diverged initial state. |
| R | 240 | post-apply diff failure makes successful apply fail. |
| R | 252 | invalid subcommand succeeds or omits usage. |

### tests/nr-linux.sh

| Mark | Line | Contract and credible regression |
| --- | --- | --- |
| R | 55 | host inferred from distribution uname instead of marker or HM output omitted. |
| R | 60 | explicit host/bootstrap suffix ignored on either closure. |
| R | 66 | missing host triggers build before refusal. |
| R | 73 | system-manager current-system presence incorrectly selects NixOS mode. |
| R | 79 | unsupported boot/test mutates Linux system. |
| R | 98 | missing subuid or subgid reaches build. |
| R | 103 | missing private pcscd group reaches build. |
| R | 108 | distribution pcscd collision is ignored. |
| R | 113 | unregistered managed shell reaches apply. |
| R | 116 | production builds without recovery identity. |
| R | 121 | bootstrap wrongly requires an identity. |
| R | 126 | non-setuid uidmap prerequisites are ignored in either variant. |
| R | 135 | prebuilt closures still invoke Nix build. |

### tests/nr-darwin.sh

| Mark | Line | Contract and credible regression |
| --- | --- | --- |
| R | 81 | marker does not select Darwin system output. |
| R | 86 | explicit target/bootstrap suffix ignored. |
| R | 92 | host absence builds before refusal. |
| R | 101 | unsupported boot/test activates Darwin. |
| R | 110 | invalid command succeeds or lacks usage. |
| R | 125 | identity absence reaches build or loses recovery instruction. |
| R | 128 | bootstrap incorrectly requires recovery identity. |
| R | 140 | bootstrap marker silently advances to production or explicit selections blocked. |
| R | 153 | dry-run plan omits profile registration or reorders activation. |
| R | 163 | actual switch activates before profile registration or builds twice. |
| R | 169 | bootstrap apply builds production output. |
| R | 174 | build-only command mutates profile or activates. |
| R | 179 | prebuilt system still rebuilt or wrong activation target. |

### tests/pinentry-card.sh

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | :24 render constants | Invalid Python or wrong Linux backend/default timeout is caught; packaging remains F3. |
| R | :286 case 1 | aligned YubiKey prompt returns encoded cached PIN without delegated GETPIN; catches loss of that named protocol/lifecycle behavior. |
| R | :299 case 2 | older/plain and manufacturer-prefixed serial forms normalize to correct PIN; catches loss of that named protocol/lifecycle behavior. |
| R | :309 case 3 | second serial line cannot select a cached PIN; catches loss of that named protocol/lifecycle behavior. |
| R | :319 case 4 | invalid UTF-8 holder bytes do not hide valid serial; catches loss of that named protocol/lifecycle behavior. |
| R | :338 case 5 | malformed escape, overlong desc, raw CR and encoded prompt newline fail closed; catches loss of that named protocol/lifecycle behavior. |
| R | :348 case 5 | malformed escape, overlong desc, raw CR and encoded prompt newline fail closed; catches loss of that named protocol/lifecycle behavior. |
| R | :365 case 7 | EOF during open dialog terminates promptly rather than hanging; catches loss of that named protocol/lifecycle behavior. |
| R | :375 case 8 | admin PIN reaches delegate and reply returns; catches loss of that named protocol/lifecycle behavior. |
| R | :393 case 9 | reset/new/repeat and serialless old PIN never auto-submit user PIN; catches loss of that named protocol/lifecycle behavior. |
| R | :404 case 10 | remaining-attempts rejection clears only named cached entry and delegates; catches loss of that named protocol/lifecycle behavior. |
| R | :416 case 11 | SETERROR guards next GETPIN and clears rejected entry; catches loss of that named protocol/lifecycle behavior. |
| R | :432 case 12 | keyring failure/empty/timeout delegates instead of blocking or answering; catches loss of that named protocol/lifecycle behavior. |
| R | :441 case 13 | unregistered serial delegates; catches loss of that named protocol/lifecycle behavior. |
| R | :453 case 14 | insert-card confirmation cancels immediately while BYE still reaches delegate; catches loss of that named protocol/lifecycle behavior. |
| R | :466 case 15 | ordinary Assuan commands and replies cross proxy; catches loss of that named protocol/lifecycle behavior. |
| C | :476 case 16 | encoded PIN and absence of raw PIN; C1 moves extra negative into case 1; catches loss of that named protocol/lifecycle behavior. |
| R | :487 case 17 | separate alignment-byte layout remains recognized; catches loss of that named protocol/lifecycle behavior. |
| R | :496 case 18 | localized description never matches English-only automatic response; catches loss of that named protocol/lifecycle behavior. |
| R | :511 case 19 | headless selects curses fallback and DISPLAY selects desktop; catches loss of that named protocol/lifecycle behavior. |
| F | :515 case 20 | installed render delivery/compilation; F3 replaces assertion-free claim; catches loss of that named protocol/lifecycle behavior. |
| R | :528 case 21 | unsupported serial spellings never select stored PIN; catches loss of that named protocol/lifecycle behavior. |
| R | :546 case 22 | two cards with different PINs never cross-select values; catches loss of that named protocol/lifecycle behavior. |
| R | :574 case 23 | rejection deletes only one serial and later clean prompt delegates while other serial still answers; catches loss of that named protocol/lifecycle behavior. |
| R | :587 case 24 | SETERROR deletion preserves other serial; catches loss of that named protocol/lifecycle behavior. |
| R | :600 case 25 | repeated rejected GETPIN deletes once and both requests delegate; catches loss of that named protocol/lifecycle behavior. |
| R | :618 case 26 | failed/hung deletion stays bounded and never submits cached PIN; catches loss of that named protocol/lifecycle behavior. |
| R | :636 case 27 | admin or ambiguous rejection deletes no card; catches loss of that named protocol/lifecycle behavior. |
| R | :655 case 28 | EOF during active relay write preserves delegate status without interpreter abort; catches loss of that named protocol/lifecycle behavior. |
| R | :726 case 29 | idle SIGTERM reaps delegate promptly with its status; catches loss of that named protocol/lifecycle behavior. |
| R | :744 case 30 | SIGTERM during full-pipe main write cannot deadlock on output lock; catches loss of that named protocol/lifecycle behavior. |
| R | :760 case 31 | EOF during full-pipe relay write cannot deadlock on output lock; catches loss of that named protocol/lifecycle behavior. |
| R | :773 case 32 | slow healthy exit gets grace and all replies/status retained; catches loss of that named protocol/lifecycle behavior. |
| R | :785 case 33 | slow startup is not mistaken for pending stuck dialog; catches loss of that named protocol/lifecycle behavior. |
| R | :807 case 34 | SIGTERM shortens post-EOF exit grace; catches loss of that named protocol/lifecycle behavior. |
| R | :823 case 35 | owed replies drain despite unscheduled relay after delegate exits; catches loss of that named protocol/lifecycle behavior. |
| R | :838 case 36 | slow scheduled write on draining output is not mistaken for blocked reader; catches loss of that named protocol/lifecycle behavior. |

### tests/pinentry-card-darwin.sh

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | :29 render | Installed filter/proxy, symlink, syntax, substitutions, macOS constants and delegate path; catches broken two-stage packaging independently of shared source. |
| R | :227 D1 | serial-derived key ID precedes GETPIN, consumes agent clear and replies once; catches loss of that named macOS transport/lifecycle behavior. |
| R | :240 D2 | remaining-attempts clears delegate key ID and deletes saved PIN once even on delete failure; catches loss of that named macOS transport/lifecycle behavior. |
| R | :251 D3 | SETERROR does same rejection handling; catches loss of that named macOS transport/lifecycle behavior. |
| R | :261 D4 | two rejected GETPINs delete only once with no derived ID; catches loss of that named macOS transport/lifecycle behavior. |
| R | :278 D5 | admin/passphrase after card retains agent key ID and no stale derived ID; catches loss of that named macOS transport/lifecycle behavior. |
| R | :286 D6 | macOS chooses pinentry_mac without display variables; catches loss of that named macOS transport/lifecycle behavior. |
| R | :299 D7 | base64/hex Keychain PIN is decoded/encoded and suppresses delegate GETPIN with one reply; catches loss of that named macOS transport/lifecycle behavior. |
| R | :309 D8 | late SETKEYINFO error is consumed rather than confused with cached GETPIN response; catches loss of that named macOS transport/lifecycle behavior. |
| R | :316 D9 | EOF preserves delegate status through both processes; catches loss of that named macOS transport/lifecycle behavior. |
| R | :343 D10 | SIGTERM exits filter promptly through child reap; catches loss of that named macOS transport/lifecycle behavior. |
| R | :359 D11 | two-stage owed replies survive slow relay; catches loss of that named macOS transport/lifecycle behavior. |
| R | :376 D12 | filter relay slow write on draining output keeps owed replies; catches loss of that named macOS transport/lifecycle behavior. |

### tests/test_desktop_ssh.py

| Mark | Declaration | Contract and credible regression |
| --- | --- | --- |
| R | :98 `test_connection_overload_is_rejected_and_capacity_recovers` | connection cap rejects excess sockets, releases capacity after disconnect, preserves existing client; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :120 `test_thread_start_failure_does_not_stop_accepting_clients` | worker creation failure releases capacity and accept loop continues; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :156 `test_systemd_root_credential_acl_accepts_only_service_user_read` | systemd root credential ACL grants only service UID read; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :159 `test_credential_acl_rejects_every_extra_reader_or_writer` | malformed/version/trailing/extra-reader/group/duplicate/permission/foreign UID ACL rejects; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :176 `test_acl_exception_never_applies_to_working_or_user_owned_files` | ACL exception never admits working, user-owned or hardlinked credentials; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :225 `test_protected_key_and_unchanged_pair` | protected identity decrypts only with wallet password; unchanged pair keeps inode/bytes/wallet; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :236 `test_rotation_and_recovery_keep_source_identity` | rotation and lost-file/lost-wallet recovery preserve source identity and old wallet entries; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :250 `test_concurrent_provisioning_retains_one_pair` | concurrent provisioning publishes exactly one pair under real lock; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| F | :257 `test_loading_requires_matching_wallet_and_metadata` | correct pair loads and missing wallet rejects; F2 adds valid mismatched identity; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :267 `test_failures_preserve_usable_pair` | wallet write/readback/replace failures preserve existing pair and clean staging; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :291 `test_mismatched_metadata_and_unsafe_files_rejected` | metadata mismatch, world-readable state and destination symlink fail without replacing external data; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :312 `test_symlink_parent_and_lock_rejected` | parent/lock symlink cannot redirect provisioning; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :325 `test_wallet_backend_error_does_not_expose_credentials` | native wallet backend exception does not expose its sensitive detail; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :334 `test_wallet_calls_select_the_overload_kwalletd_declares_last` | real dbus-python overload marshalling uses wallet-name isOpen and handle close signatures; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :489 `test_primary_first_deduplicated_and_flags_preserved` | primary precedes deduplicated fallback; signature bytes verify and flags preserved; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :501 `test_unavailable_or_stalled_fallback_does_not_block_primary` | absent/stalled fallback cannot starve primary enumeration/signature; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :514 `test_primary_failure_allows_same_connection_fallback` | primary signing denial permits fallback on same frontend connection; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :521 `test_missing_primary_metadata_still_allows_fallback` | missing primary metadata still permits fallback authentication; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :528 `test_primary_unlock_uses_an_inherited_pipe_not_stdout` | raw unlock key crosses inherited pipe with stdout discarded; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :545 `test_responsive_delayed_fallback_remains_available` | responsive delayed fallback remains selectable/signable; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :551 `test_locked_native_wallet_does_not_open_or_read_failure_reprovision` | locked native wallet never opens; native read failure is not classified for reprovision; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :566 `test_failed_unlock_is_shared_by_waiters_but_fresh_request_retries` | concurrent failed unlock shared once, fresh request retries; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :593 `test_disconnected_queued_signer_never_unlocks` | disconnected queued signer cannot trigger unlock after obtaining lock; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :612 `test_binding_and_sign_share_backend_connection` | session binding and signature use one backend connection; another frontend gets another connection; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :626 `test_unsupported_binding_is_honest_without_hiding_unconstrained_keys` | unsupported session-bind returns honest extension failure without hiding unconstrained keys; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :635 `test_dead_backend_is_not_reconnected_without_its_session_binding` | dead backend cannot reconnect and discard session restrictions; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :643 `test_oversized_fallback_selection_is_not_silently_truncated` | oversized fallback identity reply fails closed without silent selection truncation; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :651 `test_unknown_mutation_extensions_and_malformed_packets` | unknown keys/mutation commands/extensions, malformed/trailing packets and oversized frames reject; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :669 `test_primary_caches_key_but_invalidates_rotated_metadata` | key cache avoids repeated unlock, invalidates changed protected state/metadata, rejects incompatible flags; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |
| R | :686 `test_transport_options_stop_at_remote_operands` | local options stop at first remote/source operand, preserving opaque remote arguments; regression is bypass/removal of the named admission, identity, transport or lifecycle guarantee. |

### Nix declarations and shell guard support

| Mark | Declaration | Distinct contract classes and credible regressions |
| --- | --- | --- |
| R | tests/linux-host-secrets.nix:27 runCommand | Live tree metadata policy plus valid fixture; catches repository or guard rejecting a correct non-NixOS layout. |
| R | tests/linux-host-secrets.nix:92 second-recipient | Extra SSH recipient rejected with intended diagnostic; catches shared host SSH key exposure. |
| R | tests/linux-host-secrets.nix:93 missing-ssh | Host missing required SSH ciphertext rejected. |
| R | tests/linux-host-secrets.nix:94 missing-recipient | Missing recovery recipient rejected rather than vacuous policy scan. |
| R | tests/linux-host-secrets.nix:95 not-in-tokens-rule | Host recipient missing from shared token creation policy rejected. |
| R | tests/linux-host-secrets.nix:96 tokens-not-rekeyed | Actual ciphertext omits host despite correct rule; catches unrekeyed token deployment. |
| R | tests/linux-host-secrets.nix:97 in-wifi-rule | Non-NixOS identity in forbidden Wi-Fi creation policy rejected. |
| R | tests/linux-host-secrets.nix:98 in-tailscale-rule | Same independent Tailscale policy excluded. |
| R | tests/linux-host-secrets.nix:99 wifi-file-only | Actual ciphertext exposure rejected even when creation policy is correct. |
| R | tests/linux-host-secrets.sh:43 host loop (guard implementation, not extra suite) | Exact host-only SSH metadata, tokens rule and materialized token recipients, Wi-Fi/Tailscale rule and actual ciphertext exclusion. Called by Nix live-tree and fixture cases above; no separate duplicate layer to retire. A new Darwin host also has host.nix and intentionally shares policy. Future multiple matching SOPS rules are additionally owned by sops-recipients first-rule proof. |
| R | tests/nixos-rebuild-helper.nix:116 runCommand aliases | User-facing nrs/nrb/nrt/nrd select promised nr subcommands; catches alias drift on any enumerated configuration. |
| R | same assertHelper :68 | Selected user package ships executable, substituted nvd/git paths and no placeholders; catches package missing or broken substitution. Source invocation grep is not full execution proof; nr.sh remains runtime keeper. |
| R | same assertMarker :96 | Enabled etc target and bootstrap-derived expected marker; catches disabled/mistargeted/mislabeled host variant. Enumeration guard prevents empty/no-bootstrap pass. |
| R | tests/non-nixos-scripts.nix:14 install-user-age-identity | Runs real copied installer subprocess suite in declared Python; catches installer security/atomicity defects. Prior systems F2 owns the wrong-recipient fixture issue, not repeated here. |
| R | tests/non-nixos-scripts.nix:24 nr-linux | Copies/patches and invokes Linux helper owner suite; catches declared dependency/interpreter harness break and source failures. |
| R | tests/non-nixos-scripts.nix:34 nr-darwin | Same independent Darwin helper entry point and native tool contract. |
| R | tests/desktop-ssh-integration.nix:149 nixosTest | Packaged ssh/scp/sftp/Git use primary with absent fallback; catches broken symlink dispatch/transport options or SSH handshake. |
| R | same runner :78 | Stalled fallback cannot delay primary; configured primary wins despite default fallback public key; catches key-order/config priority regression. |
| R | same runner :101 | Server rejects primary then accepts last fallback under MaxAuthTries; primary signing denial/stall/absence also falls back in one invocation; catches retry or starvation bugs. |
| R | same runner :123 | Remote failing command executes exactly once with original status; catches post-login reconnect/reexecution. |
| R | same runner :130 | Concurrent frontend peers retain actual SSH parents, invocation sockets removed on parent exit, rejected fallback cannot execute remote command; catches ancestry flattening/leak/unauthorized command. |
| R | tests/desktop-ssh-session.nix:103 nixosTest metadata/credential | Generated config names fixture public key; unprivileged user cannot read root recovery source; catches broken public metadata/credential boundary. |
| R | same :203 through :220 | No session, user-target-only, genuine tty, inactive graphical seat cannot provision; active local graphical PAM session can. Catches target-only or nonlocal authorization bypass. |
| R | same :223 through :228 | Other user, property mutation, transient replacement, locked wallet denied and no working key; catches polkit broadening or wallet-open bypass. |
| R | same :232 through :240 | Authorized account without its own session ID can provision; output mode/owner private and encrypted file decrypts with persisted native wallet password. Catches caller-session overrestriction or fake persistence/encryption receipts. |
| R | same :241 through :250 | Valid signature, cached signing after wallet locks, state loss invalidates cache and refuses while locked, recovery after unlock; catches plaintext/cache reuse or missing reprovision. |
| R | same :251 through :257 | Graphical target stop removes socket; session termination denies gate/provision and restart cannot resurrect agent without session. Catches stale-login signing capability. |

## Layer plan

Retain every file and all independent configuration, package, platform, protocol, security and lifecycle layers. Apply F1/F2 at existing owner tests; repair F3 at installed Linux package boundary. C1 carries the raw-PIN negative into the existing answered-case keeper before removing its duplicate invocation. No test-only production seam was proved removable. No implementation or test edits are authorized by this review. No finding above requires weakening a safety guard.

All 13 manifest paths have explicit dispositions above. Final shared checkout status was clean at the pinned revision. Report and standalone control artifacts only were written under `/tmp`.
