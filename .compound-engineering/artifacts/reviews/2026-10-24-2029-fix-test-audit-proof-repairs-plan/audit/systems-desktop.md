# Desktop and remaining systems test audit

Pinned revision: `09e9f5aaf56f3bb549c69bc8499de9c208737e4d`.

Read-only completion of the 22-file, 6,096-line manifest in `systems-desktop-files.txt`. All assigned files were read, including both Python suites, parameter rows, embedded Nix builder programs, and all six OpenRouter fixture records. No shared repository edits, commits, pushes, activation, or nested agents. This supplements `systems.md`; it does not repeat that report's findings or the parent's python3-runtime and GPG/Zsh/Ghostty delivery findings.

R = retain; F = retain contract, repair proof; C = consolidate after carrying unique proof; D = delete assertion and unused test-only seam. No whole test file is recommended for deletion. The only D is one assertion class in test-audit-skill.

## Evidence and limits

Parent baseline (`baseline-status.txt`): native aarch64-darwin; all-systems evaluation PASS; Darwin outputs PASS; both assigned Python suites PASS. Linux check builds, Linux host builds, VM execution, physical devices, printer connectivity, and Plasma session behavior unavailable here. The Darwin outputs pass is separate platform proof, not a pass for these Linux desktop checks. `serve-html` deliberately skips its 127.0.0.2 bind case on Darwin; its unreadable-file case may skip for a mode-bypassing user.

Focused controls use public scripts and fake values in standalone temporary directories without copied `.git`. `desktop-controls.py/json` demonstrates printer recreation, dead taskbar activation, and a GET before the Tailscale state guard. These replay the relevant source predicates, not complete Nix builders. `vscodium-activation-controls.json` evaluates the actual production activation text, then demonstrates identical merger/destination/document extraction and no status-swallow match after wrapping it in `if false`; the wrapped script exits 0. This is source/extraction evidence, not a Linux build. `vscodium-controls.json` rejects the suspected nested-set gap: the actual merger rejects object-valued `set`, so that candidate is not a finding.

Read the requested store test-audit skill, audit reference, and campaign, root instructions, relevant activation/materialization/mutation/trait/copy-worktree learnings. Examined the locked nixpkgs Tailscale and NetworkManager module implementation and Home Manager file delivery/filtering. Dependency source roots: nixpkgs `/nix/store/87lfqfz7mc5dm4w75qikxhd6lkr9jisr-source`, Home Manager `/nix/store/0ql2valpm8n9qqavz2bmkg9f4q8s5f59-source`.

## Findings

### F1 — printer queue reconciliation is never executed

- `tests/printing.nix:214` (assertLabel), especially lines 222 and 225; owner `modules/nixos/services/printing.nix:15`.
- Contract: a queue already pointing at its configured URI survives an offline printer; descriptions still update, while absent or changed-URI queues are created with IPP Everywhere.
- Flaw: the test greps assignments and lpadmin lines without executing reconciliation. Deleting the lpstat conditional retains every checked command and leak guard while recreating an existing queue, which queries an offline printer and fails. A dead branch can also preserve those lines while doing no work.
- Evidence: `desktop-controls.json`: control logs only `-p office -D Fake printer`; unconditional-create logs the extra `-E -v ... -m everywhere`. Both retain all four positive line predicates. Removing only the guard adds no prohibited literal or alternate assignment, so the remaining source predicates are unchanged.
- Keeper/minimal repair: keep printing.nix's independent materialized CUPS/Avahi/DNS/firewall/filter and secret-leak classes. Execute the rendered ExecStart script with lpstat/lpadmin protocol stubs and fake env; assert unchanged URI causes description only, absent/different URI creates then describes, and errors propagate. Make the offline fixture fail an unnecessary create. No stronger existing automated queue-runtime keeper was found; host builds and hardware checklist do not substitute.
- History: `6f7a83d` introduced printer support; `ba0531a` deliberately separated always-update description from guarded creation and strengthened these text assertions. Later `a1a0dd2` repaired the filter glob, a distinct retained guard.
- Validation needed after repair: actual `checks.x86_64-linux.printing`, including guard-removal and dead-script mutations. No repair applied.

### F2 — taskbar activation can be a successful no-op

- `tests/plasma-taskbar.nix:51`, particularly line 62; owner `home/h82/desktop/kde/plasma.nix:24`.
- Contract: activation writes ordered launchers and groupingStrategy=0 into both supported task-manager applet types, with T3 omitted when its trait is off.
- Flaw: nonempty data plus two substrings observes neither applet discovery nor KConfig writes. Wrapping the entire activation in `if false; then ... fi` passes all predicates and exits 0 while preserving stale configuration.
- Evidence: `desktop-controls.json` has identical nonempty/launchers/grouping results for control and no-op. The trait-off variants protect data selection, but not execution.
- Keeper/minimal repair: retain this suite as owner. Execute the real step against a scratch HOME containing divergent taskmanager and icontasks applets plus unrelated applets/keys, then read resulting groups with KConfig. Keep production/bootstrap and forced-off trait rows. `tests/kde-theme.nix` demonstrates this boundary for a different file; it does not prove taskbar writes. No complete file deletion.
- History: `8d5d4c8` introduced launchers; `077a300` replaced the Orca pin with T3, and `15f460a` supplied trait variants. None replaced textual activation proof.
- Validation needed: Linux taskbar check with dead-step and broken-discovery mutations. No Linux execution claimed.

### F3 — VSCodium tests reconstruct the call instead of executing activation

- `tests/vscodium.nix:353` and `tests/vscodium.nix:375`; owner `home/h82/dev/vscodium.nix`'s vscodiumSettings step.
- Contract: the scheduled step actually merges settings, preserves user additions, and lets refusal fail activation after package installation.
- Flaw: regexes extract the merger and arguments from any script location, then the test independently invokes the merger. `if false; then <original call>; fi` leaves all extracted values, declared document checks, and direct merge results unchanged, while actual activation writes nothing. An echo-only invocation has the same boundary problem. The blacklist for a few exit-status spellings cannot establish error propagation.
- Evidence: `vscodium-activation-controls.json` records identical merger/settings/declared values, no swallowed-status match, and zero no-op exit. Existing `vscodium-controls.json` confirms the real merger boundary works and rejects object-valued `set`; do not report a nested-set failure.
- Keeper/minimal repair: retain independent package, code-wrapper, extension, legacy keybindings, unmanaged-settings, declaration, and ordering contracts. Redirect the actual step's real settings destination to a scratch divergent file, run that step under activation's shell error mode, and inspect the file; exercise a merger refusal through the step too. `tests/darwin-outputs.nix` has step-execution machinery for other settings, and the agent-settings Python suite covers merger semantics, but neither proves this Linux VSCodium step runs.
- History: `85f73a5` introduced extraction/direct replay; `37d48c9` added competing-writer protection. The latter remains independently valuable.
- Validation needed: actual Linux VSCodium check and dead-call/refusal controls. No repository fix or full builder execution here.

### F4 — Tailscale scenario B cannot observe its no-query promise

- `tests/tailscale-provisioning.nix:204`, assertion at line 211; supporting observer `tests/tailscale-mock-api.py:26`.
- Contract: an existing tailscaled state file skips API traffic entirely on ordinary reboot or key-expiry reauthentication.
- Flaw: only deletes.log is cleared/read. GET requests are never logged. Moving the existing-state guard after the successful devices GET still gives an empty delete list, satisfying the scenario while querying needlessly.
- Evidence: `desktop-controls.json`: original existing-state execution has zero GET/DELETE; query-before-state-guard has one GET and zero DELETE, exit 0. The real mock API confirms GET has no persistent observation; source proof establishes that the VM assertion cannot distinguish these outcomes. This is not a VM pass.
- Keeper/minimal repair: retain the VM's materialized unit wiring, real tailscaled preference restoration, secret rendering/isolation, fresh-install selective deletion, and store-leak proof. Log method/path for every mock request, reset after startup settles, and require no requests for scenario B. Keep DELETE ID assertions for scenario A. No sibling has this observation.
- History: `40aa3b2` introduced API-backed VM proof; `62334d1` moved dedup before registration and explicitly changed scenario B to promise no queries, but retained the delete-only observation. `e19d469` fixed settling before preference checks, a separate runtime contract.
- Validation needed: VM on Linux/KVM with guard-after-GET mutation. No fix applied.

### D1 — test-only skill provenance registry repeats the shipped attribution

- `tests/test-audit-skill.nix:180` and registry assertions at lines 184-214; production seam `home/h82/agents/test-audit.nix:10`.
- Flaw: my.testAuditSkill is an internal read-only attrs option whose description says it exists for repository checks. Its upstream/path/rev values have no runtime consumer; repository search finds only this checker and prose describing it. The option and test repeat the same three literals while the actual distributed SKILL.md attribution is checked independently.
- Remaining keeper: retain the final exact attribution-line check (`tests/test-audit-skill.nix:246`), license presence/header, byte-for-byte materialized directory comparison, frontmatter validity, forbidden tooling tokens, four resolved enabled targets, and non-symlink SKILL.md. These preserve attribution and delivery contracts with no registry.
- Minimal removal: remove only the registry assertion class and unused my.testAuditSkill option/provenance binding; update the single documentation sentence describing the registry. Do not remove vendored attribution, LICENSE, root inventory, or delivered-content assertions. Production deletion is about 17 lines of option/let scaffolding; no new production seam is needed.
- History: `04c3ef9` introduced the registry as a record for the checker; `2290d24` renamed/simplified wiring but left it test-only. No evidence of a non-test caller after the refactor.
- Evidence is full source/caller/history inspection, not an applied-deletion check. Validate test-audit-skill and sibling korean-skills on Linux after any approved removal. This is a review-only recommendation, not permission to alter a documented decision silently.

## Owners, history, overlap, and CI routing

All ordinary Nix files below are declared under `checks.x86_64-linux` in flake.nix. CI `check.yml` evaluates in flake-check and builds via check-shards; host-closure entries listed below go to hosts, others to generated light shards. VM files are exclusively tests/vm-checks.nix entries, built individually in the KVM vm-checks matrix. Docs-only PRs skip these by design; evaluation alone never establishes their assertions passed. Non-NixOS architecture and Darwin jobs prove distinct host/platform assembly.

| Assigned file | Owner, callers/dependencies and overlap | History inspected; routing |
| --- | --- | --- |
| baloo-extractor.nix | desktop/desktop.nix drop-in via NixOS profile; effective unit fragment/drop-in resolution and actual Qt extractor/indexer, not generic host closure proof | 0ad1975 offscreen fix, 8ba3dec review; hosts shard |
| boot-splash.nix | system/boot-splash.nix, boot.nix, locked Plymouth/lanzaboote/initrd generation; boot-layout VM proves disk/boot composition, not these quiet/graphical initrd contracts | c66e81e review, e857618 removal, a236aca variants; light |
| desktop-autostart.nix | home desktop/kde/autostart.nix via KDE imports, system desktop 1Password and tailscale module; generated desktop files and drop-ins differ from tailscaled preference VM proof | 48f07af launch apps, 39ce5c3 review, 9aecc82/8ed6938 ChatGPT changes; light |
| emoji-font.nix | desktop/fonts.nix and shared/font-packages.nix, fontconfig configuration/cache and fonttools; Ghostty font-family proof does not establish emoji fallback/color table | cf0aaad introduced, 06db3a0 review, afa08d5 pipe repair; hosts |
| tests/fixtures/openrouter-models/models-2026-10-23.json | scripts/openrouter-catalog-snapshot + catalog_snapshot.py, tests/test_openrouter_catalog_snapshot.py; six full API-shaped inputs with text/image/audio, prices, optional cache/reasoning and null caps; Pi rendering/load checks prove a separate consumer contract | 6125c2b whole-catalog tools; fixture copied by openrouter-catalog-snapshot check, light |
| iphone-restore.nix | hardware/iphone-restore.nix via profile; usbmuxd, overridden libirecovery and idevicerestore, dl linkage; udev suite owns DFU seat access rather than duplicating it | 37dde8f restore, bdf6368 device support; hosts |
| kde-theme.nix | desktop/desktop.nix baseline and home desktop/kde/theme.nix; KConfig real cascades and package scheme; taskbar is a different file/activation owner | 27169fa schedule, be11e57 review; hosts |
| nix-cleanup.nix | system/nix-cleanup.nix + boot.nix; locked nh module units/timer and loader bounds; host build doesn't prove retention relationship | 15f460a review, 5d68122 gcroots/flags, 44946b3 path move; hosts |
| plasma-taskbar.nix | home desktop/kde/plasma.nix activation via KDE import; kread/kwrite task discovery; theme suite has no overlapping taskbar effects | 8d5d4c8 initial, 077a300 T3, 15f460a review; light |
| printing.nix | services/printing.nix via profile; CUPS/Avahi/resolved/NSS/firewall and sops rendered placeholders; no automated queue-runtime sibling | 6f7a83d feature, ba0531a reconciler review, a1a0dd2 glob; hosts |
| proton-vpn.nix | services/proton-vpn.nix + resolved.nix/profile/base firewall; locked NM OpenVPN plugin/resolved integration; printing proves separate mDNS exclusion | fdda113 unit-content repair, 2defda5 host iteration, 6c1a554 cache fix; hosts |
| shell-utilities.nix | home shell/utilities.nix via shell default; executed home.path tools. No deletion for dependency behavior: packaging/PATH/interpreter and chosen yq implementation are user contracts | 466fe1a process tools, 5e182bb tighter proof, e2ba19f scheduling; light |
| tailscale-provisioning.nix | services/tailscale.nix, tailscale-dedup-device, mock API and real sops/tailscaled; actual stored pref restoration distinct from desktop tray command bytes | 40aa3b2 VM, 62334d1 state guard, e19d469 queued-unit wait; vmChecks |
| test-audit-skill.nix | agents/test-audit.nix + skills.nix, home import and vendored text; korean-skills owns root population, this suite owns exact content/provenance delivery | 04c3ef9 initial, 5370b27 frontmatter review, 001265b root cleanup; light |
| test_serve_html.py | scripts/serve-html packaged by agent-tools.nix and installed by home/default; actual HTTP/fork/session behavior; serve-html-profiles and Darwin outputs independently prove installed executable/interpreter | e39ad8a utility, 0181b2a hardening; serve-html check, light |
| test_synthetic_models_watch.py | scripts/synthetic-models-watch + catalog_snapshot.py; real synthetic-models.nix source, fixture catalog; workflows synthetic-models.yml/model-catalogs.yml and agent-tools package are callers. Reconcile shell suite owns gh workflow state; Pi owns rendered model schema/load | 6125c2b snapshots, 38f386a source cleanup, bbaedd4 retention/validation; synthetic-models-watch, light |
| udev-device-access.nix | hardware nuphy/sennheiser/dualsense/iphone modules and services/podman.nix; actual rule filename ordering + tmpfiles. Physical uaccess/libinput/container device use remains separate | 37dde8f Apple, 7e00428 KVM, f3d29da ordering; light |
| vscodium.nix | home/dev/vscodium.nix via dev default; Home Manager VSCode platform paths, packaged agent-settings, code wrapper; agent-settings unit/CLI suite protects generic merger semantics, not step invocation | 85f73a5 guard, 37d48c9 second writer; light |
| wifi-provisioning.nix | modules/nixos/wifi.nix, SOPS, locked NetworkManager ensureProfiles envsubst/UMask/service; auth-provisioning proves different credentials and lifecycle | 5261c0f initial, 44a26e1 simplify, 197746a path move; vmChecks |
| wifiman.nix | services/wifiman.nix, packages/wifiman-desktop.nix, home/default trait gate; wrapper/runpath/Go startup/state helper tests distinct from release-pin parser | d5adc6c check, a1e8010 review; hosts |
| winbox.nix | desktop/winbox.nix -> nixpkgs programs.winbox; generated package/desktop/firewall permissions differ from a host's successful build | 862921a initial, 5c996fc anchored interface scope; hosts |
| yubikey-fido.nix | hardware/yubikey.nix and base pcscd, home/default GUI, systemd/vendor rules; card/signing/recovery VMs protect other security boundaries | 7076c88 initial, 1851447 materialization hardening; hosts |

## Nix assertion-class ledger

A row groups internal assertions only when they have the same observable boundary. Within each file, the following named classes account for its substantive assertions; empty fleet/trait population and absent-tree diagnostics remain R support because they prevent vacuous coverage.

| File / declaration class | Mark | Concrete contract; credible regression |
| --- | --- | --- |
| baloo: fragment precedence, mask/ExecStart | R | Effective user unit runs packaged baloo_file; catches a higher-priority replacement or mask. |
| baloo: drop-in basename precedence/order, Service env reset/quoting | R | Effective offscreen setting with inherited session PATH; catches wrong section, reset, or PATH replacement. |
| baloo: extractor empty stdin startup | R | Actual extractor starts without display variables; catches Qt platform abort independently of service config bytes. |
| baloo: dbus content indexing/search | R | Spawned extractor really indexes probe content; catches a service that starts but never extracts. |
| boot splash: wants/start daemon and password path/service | R | Graphical initrd starts Plymouth and handles unlock fallback; catches masking or disconnected password agent. |
| boot splash: theme file/config | R | bgrt selection and packaged theme agree; catches omitted asset with otherwise correct name. |
| boot splash: production loader timeout/kernel quiet parameters | R | Silent boot data and loader argument point at zero timeout; catches wrong loader document or lost independent quiet parameter. |
| boot splash: KMS + NVIDIA/non-NVIDIA classes | R | Native initrd display driver and modeset, no early UVM; catches missing modeset, premature UVM, or NVIDIA leakage into Intel variant. |
| boot splash: bootstrap exclusions/menu | R | Recovery remains textual with visible menu; catches widening production condition. |
| autostart: all-host CLI enable | R | 1Password CLI available in bootstrap too; catches profile gating. |
| autostart: six app entries, resolved targets, enabled/forced/desktop metadata/exact Exec | R | Scanner sees enabled entries running installed app with tray-safe flags; catches disabled/retargeted entries or stale paths. Six app transport contracts remain independently relevant. |
| autostart: Tailscale package swap/off branch | R | Tray follows service package and is absent without service; catches hardcoded default derivation. |
| autostart: materialized up/reset and set/operator commands | R | Reauthentication and existing-node preference commands carry operator/reset; catches missing up flag that set-only runtime proof cannot see. |
| autostart: restart drop-ins/no full shadowing unit | R | Generated Discord/Telegram unit keeps its ExecStart with restart policy; catches replacing the fragment or wrong section. |
| autostart: bootstrap absence | R | Bootstrap avoids card-touching/GUI startup; catches unguarded files. |
| autostart: materialized ChatGPT manual-launch exclusion | R | No startup entry/unit launches ChatGPT through alternate target/name; catches home.file bypass, independent of absence from one declared app list. |
| emoji: seven family/codepoint requests | R | Color emoji chosen through actual fontconfig fallback including named-family emoji language; catches monochrome DejaVu taking precedence. |
| emoji: font color table | R | Chosen font has CBDT/COLR usable by GTK/Qt/Chromium; catches SVG-only build despite color=true. |
| emoji: full alias fallback ordering | R | Twemoji first and Noto fallback remains; catches trimming fallback font. |
| emoji: primary ASCII/Korean preservation | R | Space/digit/hash keep text font and Korean matches sans primary; catches emoji font promoted above primary. |
| iphone: materialized usbmuxd command/user/want | R | Restore-mode daemon actually wired as usbmux; catches masked or unwired unit. |
| iphone: vendor group rule + three executable tools | R | Restore transport and user tools delivered; catches missing group handoff or profile executable. |
| iphone: newest device in executable and loaded library | R | Both irecovery and idevicerestore's own linked device table support model; catches updating only standalone utility. |
| theme: effective system identities + every packaged color entry, nested groups | R | Complete light baseline and locale/terminal survive; catches scheme-name-only or incomplete nested colors. |
| theme: light/dark contrast + switcher plugin | R | Independent distinct fixture schemes and runtime switcher asset; catches wrong scheme package or missing kded plugin. |
| theme: three real activation fixtures, scheduled keys/preserved unrelated value | R | Off/stale keys become scheduled config without erasing user data; catches dead or destructive activation. |
| theme: deleted identity/hash/icon keys and no deletion markers | R | User entries stop masking kdedefaults; catches kwrite deletion leaving Key[$d]. |
| theme: KConfig cascade + dark package/color preservation | R | Night schedule wins and activation doesn't force day colors; catches wrong XDG cascade or destructive light rewrite. |
| cleanup: service command/retention flags/no disable flags | R | Real generated nh command preserves count/window/gcroots and collects; catches no-gc/no-gcroots or lost keep-one. |
| cleanup: nullable loader bound/count comparison | R | Retention covers offered boot entries with finite bound; catches null limit or count below menu. |
| cleanup: weekly persistent timer/want/no competing GC | R | Cleanup actually scheduled once and catches missed boot; catches unwired timer or second collector. |
| cleanup: production executable/bootstrap absence | R | Manual tool reaches production and installer stays free of cleanup; catches package gate independent of service gate. |
| taskbar: nonempty step, launchers order/T3 split/grouping | F | F2: preserve all distinct expectations but observe resulting applet file. |
| printing: CUPS effective listener/drop-ins/socket want | R | Socket activation retains listener; catches empty ListenStream reset/mask/unwiring. |
| printing: Avahi daemon/want, no cups-browsed | R | Discovery enabled without legacy browsing listener; catches masked Avahi or exposed cups-browsed. |
| printing: NSS mDNS order/resolved exclusion/firewall | R | mDNS reaches Avahi before resolve without duplicate responder; catches wrong backend order, responder conflict, blocked UDP. |
| printing: actual driver filters | R | CUPS tree carries executable HPLIP and Gutenprint filter; catches package list that doesn't deliver filters. |
| printing: trait-off absence/defaults | R | Opt-out has no listeners/NSS override; catches widened trait effect. |
| printing: queue unit/want/env/template and no-queue/bootstrap absence | R | Secret-backed reconciliation wired only where declared; catches missing template, wrong env path, or bootstrap service leak. |
| printing: queue assignment/create/description source strings | F | F1: actual unchanged/changed/missing queue effects must be observed; keep source secret-origin constraints as complementary security proof. |
| printing: no literal URI/IP or alternate -v/-D | R | Public store text carries no printer endpoint; catches accidental literal credentials/addresses. Runtime queue stub alone cannot establish store confidentiality. |
| proton: app/desktop/OpenVPN plugin production/bootstrap | R | Complete app transport path delivered only in production; catches missing plugin or bootstrap leak. |
| proton: NM backend, resolv symlink, resolved executable/want | R | Split DNS plumbing reaches materialized host; catches stale stub link or masked resolved. |
| proton: LLMNR and negative cache config | R | Security/query policy and new DNS records preserved; catches default restoration. |
| proton: loose reverse path filter | R | Full tunnel replies beside tailscale survive; catches strict rpfilter rule. |
| shell utilities: jq/yq/rg/fd/fzf/bat/tree/file rows | R | Installed chosen tool resolves expected public behavior; catches missing executables/wrong yq implementation or broken wrappers. |
| shell utilities: zip/unzip, shellcheck/shfmt, sponge result | R | Packaged archive/lint/format/pipeline tools operate; catches interpreter/runtime delivery failures, plus no-op sponge. |
| shell utilities: wget/wl-copy/wl-paste versions | R | Installed binaries run without sandbox display/network; catches missing loader/package. Does not claim clipboard transfer proof. |
| shell utilities: pgrep/pkill owned child/status | R | Installed process tools identify and terminate actual child; catches pgrep args/no-op pkill rather than trusting zero exit. |
| shell utilities: lsof held descriptor | R | Installed lsof reports current process's real file; catches unusable binary or wrong platform wrapper. |
| tailscale: routing mode/up flag sets/UDP input option assertions | R | Distinct client/router declarative API contract; catches routing wrong branch/omitted reset. These do not substitute for materialized/runtime checks. |
| tailscale: queued-unit settle + actual set prefs/operator/wanted-by | R | Already-registered node gets prefs restored through real unit; catches set missing, late startup race, or operator ignored. |
| tailscale: dedup before/want/enabled and route after/enabled/client absence | R | Installed lifecycle graph and role split; catches a declared but uninstalled service or wrong ordering. |
| tailscale: route secret presence/isolation and rendered subnet list | R | Only router receives route document, API token not handed to advertiser; catches secret cross-routing or missing subnet. |
| tailscale: fresh state selective API deletion | R | Real script deletes same-host device and preserves other host; catches wrong hostname predicate. |
| tailscale: existing state no API/no delete | F | F4: observe every method, retain no-delete expectation. |
| tailscale: closure fake-token absence | R | Plain secrets never embedded in system closure; catches interpolation into derivation. |
| skill: four resolved target counts/enable flags | R | One enabled target per harness; catches retargeting/duplicate/disabled declaration. Root population in korean-skills is distinct shared wiring inventory. |
| skill: home-files contents/frontmatter/no SKILL symlink/license/source equality | R | Harness reads valid complete actual vendored skill; catches recursive individual symlinks, bad metadata, omitted reference/license. |
| skill: generalized forbidden tooling tokens | R | Shipped runtime instructions remain project-neutral, including negated tokens; catches accidentally copied upstream-specific commands. Static prompt-byte contract remains valid. |
| skill: final exact attribution line | R | Delivered source records correct upstream/path/revision independently; catches erased or drifted attribution. |
| skill: my.testAuditSkill registry | D | D1: redundant test-only runtime option; attribution and delivered directory remain keepers. |
| udev: default/uaccess anchors + BTD after-default | R | Rules apply after USB mode reset; catches moving BTD MODE rule too early. |
| udev: Apple/NuPhy before-uaccess and trait-off NuPhy | R | Tagged device participates in seat ACL assignment only where opted in; catches 99-local placement or trait leakage. |
| udev: both DualSense touchpad identities | R | USB and Bluetooth touchpads ignored by libinput; catches dropping one transport name. |
| udev: last KVM mode/no MODE:= | R | Rootless container users see writable KVM despite distribution defaults; catches later mode reset or pinned earlier assignment. |
| udev: first effective tmpfiles entry/Podman-off absence | R | Static node gets correct permissions before udev and opt-out removes both mechanisms; catches conflicting earlier tmpfiles or unconditional rules. |
| VSCodium: home executables/code target | R | Noninteractive code resolves installed codium, nixd present; catches stale wrapper target or absent binary. |
| VSCodium: extensions/keybindings exact JSON/force | R | Nix IDE/Biome and legacy user bindings delivered despite old unmanaged file; catches extension path loss, binding drift, force omission. |
| VSCodium: no competing settings file/writers | R | Mutable settings owned by merger alone; catches later Home Manager writer. |
| VSCodium: activation presence/order | R | Failure happens after packages install; catches missing step or wrong DAG dependency. |
| VSCodium: call extraction/status blacklist/direct merge | F | F3: keep declaration contents and user-key preservation, execute actual step. |
| VSCodium: declared document independent settings equality/object ownership | R | Legacy settings leaf ownership remains; catches changed setting or owned whole dictionary. Generic merger rejects nested set, so no nested-set finding. |
| Wi-Fi: missing-secret boot/switch and absent profiles | R | Bootstrap without input activates safely without bogus connections; catches unguarded missing secret/profile generation. |
| Wi-Fi: distinct home/office SSID/PSK + anti-cross-routing | R | Real rendered files route each label's credentials correctly; catches key substitution/cross-network leakage. |
| Wi-Fi: root 0600/no DNS/gateway/routes | R | Private minimal connection files; catches umask changes or unwanted network overrides. |
| Wi-Fi: post-switch recheck/store absence | R | Activation remains idempotent without plaintext store leak; catches rebuild-only failure or evaluation-time secret interpolation. |
| WiFiman: GUI executable/wrapper/ldd/runpath tray/iW+awk/desktop | R | Package starts with dynamic/runtime tray dependencies; catches missing dlopen library or wrapper PATH. |
| WiFiman: daemon unit/want/BASE/private state | R | Correct daemon uses writable private key-bearing state directory; catches masked unit, read-only BASE, permissive mode. |
| WiFiman: executed preStart symlinks/copy/env/interpreter | R | Real daemon state helpers and mutable executable report installed; catches link-vs-copy chmod failure or /bin/bash shebang. |
| WiFiman: wg/wireguard-go and daemon startup log | R | Go binaries actually start after patching; catches runpath-induced segfault that ldd misses. |
| WiFiman: daemon PATH tool table | R | Every external subprocess tool resolves through service PATH; catches incomplete runtime deps. |
| WiFiman: trait-off no GUI/daemon, bootstrap trait-on | R | Profile policy distinct from opted-in delivery; catches disabling bootstrap or leaking service while off. |
| WinBox: binary/desktop | R | Admin GUI actually delivered; catches package declaration without linked executable. |
| WinBox: each anchored UDP port/range every interface | R | Discovery/MAC connection firewall permission stays global; catches per-interface suffix or missing one port. |
| YubiKey: system ykman and user GUI executable/desktop | R | Recovery/signing inventory and authenticator UI delivered; catches profile omission separate from rule presence. |
| YubiKey: package membership diagnostics | R | Diagnostic for absent explicitly required manager/GUI package; overlaps delivery but gives actionable package identity rather than replacement proof. No whole layer removal warranted. |
| YubiKey: vendor/FIDO/uaccess rules and pcscd socket file | R | Required USB/security stack artifacts exist; catches omitted rules/socket. No claim that file existence proves physical card access or actual signing. |
| OpenRouter fixture all six records | R | Full independent upstream-shaped data exercises optional/null/negative sentinel/extra field trimming and modalities; catches parser assumptions. Not a test declaration and no deletion solely for long descriptions/unused fields: these exercise projection away from upstream extras. |

## Python declaration ledger

Each table entry is one unittest declaration; parameter rows remain together because all rows have the same disposition. Fixtures/helpers (WatchTestCase, server cleanup, fake network/eval commands, catalog construction) support these contracts; they do not assert their own behavior. These stubs supply network responses and record actual transport arguments rather than fabricate repository outcomes. Both owners have real package/workflow callers; no test-only owner export is proposed.

### tests/test_serve_html.py

| Mark | Declaration | Contract; credible regression |
| --- | --- | --- |
| R | `tests/test_serve_html.py:88` `test_prints_one_target_line_and_returns_while_serving` | One exact target JSON line, prompt return and live HTTP bytes; catches blocking launcher or invalid target protocol. |
| R | `tests/test_serve_html.py:97` `test_response_headers` | HTML UTF-8 and no-store; catches cached stale report or wrong MIME. |
| R | `tests/test_serve_html.py:103` `test_page_without_an_html_suffix_is_still_served_as_html` | Named page always HTML in both root modes and normalized path; catches extension-only MIME dispatch. |
| R | `tests/test_serve_html.py:112` `test_only_loopback_host_names_are_answered` | Loopback Host allowlist rejects remote DNS names; catches DNS rebinding exposure independent of bind address. |
| R | `tests/test_serve_html.py:120` `test_a_silent_connection_does_not_block_requests` | Idle accepted peer cannot block another HTTP request; catches single-thread server regression. |
| R | `tests/test_serve_html.py:126` `test_reload_shows_current_content` | Disk edit appears on next request; catches cached body snapshot. |
| R | `tests/test_serve_html.py:133` `test_other_paths_are_404_by_default` | Single-file mode rejects sibling/traversal/near-match paths; catches accidental directory server. |
| R | `tests/test_serve_html.py:140` `test_root_serves_siblings_with_their_types` | Root serves CSS and nested JS with no-store; catches root lookup or CSS MIME regression. |
| R | `tests/test_serve_html.py:152` `test_root_serves_non_html_files_with_their_own_type` | Root JSON response has JSON UTF-8; catches forcing every root asset to HTML. |
| R | `tests/test_serve_html.py:159` `test_root_does_not_escape` | Encoded/raw traversal, symlink escape, missing and directory requests rejected; catches path confinement bypass. |
| R | `tests/test_serve_html.py:169` `test_root_prints_the_root_relative_path` | Nested spaced page yields encoded relative path and live bytes; catches basename-only root target. |
| R | `tests/test_serve_html.py:176` `test_file_outside_root_fails` | Outside-root page refuses before output/server launch; catches publishing escaped target. |
| R | `tests/test_serve_html.py:185` `test_root_that_is_not_a_directory_fails` | File root refused with empty stdout; catches root argument type omission. |
| R | `tests/test_serve_html.py:192` `test_server_start_failure_prints_nothing_and_fails` | Failed child readiness refuses target; catches parent announcing dead server. |
| R | `tests/test_serve_html.py:199` `test_missing_file_fails` | Missing page rejects without child/target; catches successful invalid launcher. |
| R | `tests/test_serve_html.py:206` `test_unreadable_file_fails` | Unreadable file rejects without target; catches delayed read failure. Conditional skip for privileged mode bypass is honest. |
| R | `tests/test_serve_html.py:216` `test_directory_argument_fails` | Directory cannot be named page; catches treating directory as HTML. |
| R | `tests/test_serve_html.py:221` `test_special_characters_in_the_name_are_percent_encoded` | Unicode/space/hash path round trips and serves; catches URL fragment/encoding truncation. |
| R | `tests/test_serve_html.py:230` `test_relative_path_resolves_from_the_callers_directory` | Caller cwd selects page; catches resolving relative path from script directory. |
| R | `tests/test_serve_html.py:235` `test_server_exits_after_the_idle_window_and_requests_extend_it` | Requests renew actual process lifetime, then idle exits; catches fixed lifetime or immortal daemon. |
| R | `tests/test_serve_html.py:248` `test_server_runs_in_its_own_session` | Detached child session differs from caller; catches terminal/session coupling after fork. |
| R | `tests/test_serve_html.py:253` `test_binds_loopback_only` | 127.0.0.1 works and 127.0.0.2 refuses on Linux; catches wildcard bind. Darwin skip is explicit. |
| R | `tests/test_serve_html.py:259` `test_default_idle_window_is_thirty_minutes` | Argparse help renders live 1800 default; catches changed configured default without a 30-minute wait. Owner uses the same args value for detach; retain default/config contract. |

### tests/test_synthetic_models_watch.py

| Mark | Declaration | Contract; credible regression |
| --- | --- | --- |
| R | `tests/test_synthetic_models_watch.py:202` `test_the_snapshot_yields_no_difference` | Real declared source is clean against independent catalog; catches source drift or blanket drift classifier. |
| R | `tests/test_synthetic_models_watch.py:205` `test_a_model_the_source_no_longer_names_is_not_drift` | Unused Kimi removal ignored; catches whole-catalog rather than in-use drift reporting. |
| R | `tests/test_synthetic_models_watch.py:208` `test_missing_deepseek_is_removed_with_its_role_and_pointers` | Removal identifies model, roles, source pointers, title/body; catches lost actionable consumer context. |
| R | `tests/test_synthetic_models_watch.py:222` `test_an_alias_row_does_not_keep_a_removed_model_present` | Alias cannot satisfy current model presence; catches alias normalization masking removal. |
| R | `tests/test_synthetic_models_watch.py:228` `test_a_later_deepseek_build_is_a_new_version` | Same lineage later build reports candidate and uses; catches comparing semantic version alone. |
| R | `tests/test_synthetic_models_watch.py:243` `test_candidates_are_listed_newest_first` | Multiple candidates ordered by semantic version/build; catches ascending/string sorting. |
| R | `tests/test_synthetic_models_watch.py:258` `test_suffixed_products_and_lower_versions_are_not_newer` | Air/Lite/old variants excluded; catches overbroad lineage selection. |
| R | `tests/test_synthetic_models_watch.py:270` `test_a_newer_flash_and_a_newer_base_model_are_separate_new_versions` | Base and Flash candidates route separately; catches cross-product upgrades. |
| R | `tests/test_synthetic_models_watch.py:282` `test_missing_glm_flash_is_removed_with_no_uses_and_no_older_replacement` | Unused declared entry removal remains visible without invented uses/older candidate; catches dropping unused inventory. |
| R | `tests/test_synthetic_models_watch.py:291` `test_glm_flash_without_high_is_changed_for_its_default_effort_only` | Flash default high missing reports only defaultEffort; catches role/default conflation. |
| R | `tests/test_synthetic_models_watch.py:302` `test_a_higher_version_on_the_same_created_is_newer` | Higher semantic version wins tied creation time; catches strict timestamp gating. |
| R | `tests/test_synthetic_models_watch.py:308` `test_a_higher_version_with_an_earlier_or_missing_created_is_newer` | Higher version wins absent/older timestamp; catches timestamp precedence. |
| R | `tests/test_synthetic_models_watch.py:319` `test_an_equal_version_is_newer_only_with_a_later_created` | Equal versions require numeric later timestamp, excluding strings/missing/ties; catches accepting unknown date. |
| R | `tests/test_synthetic_models_watch.py:331` `test_an_equal_version_is_not_newer_when_the_model_in_use_has_no_created` | Unknown current timestamp prevents equal-version guess but higher version remains upgrade; catches assuming epoch. |
| R | `tests/test_synthetic_models_watch.py:342` `test_syn_rows_are_ignored_and_an_hf_alias_row_is_a_candidate` | syn IDs ignored while valid hf alias lineage can upgrade; catches dropping all aliases or accepting syn candidates. |
| R | `tests/test_synthetic_models_watch.py:355` `test_a_removed_model_lists_its_lineage_candidates` | Removal suggests same/newer lineage ordered semantically; catches suggesting older/different product. |
| R | `tests/test_synthetic_models_watch.py:368` `test_a_row_can_be_both_a_new_version_and_changed` | Upgrade and missing-effort findings coexist; catches exclusive-branch classifier. |
| R | `tests/test_synthetic_models_watch.py:382` `test_syn_rows_are_not_counted_as_rejected` | Ignored syn row does not inflate rejection count; catches conflating unsupported and malicious IDs. |
| R | `tests/test_synthetic_models_watch.py:387` `test_glm_without_max_is_changed_for_its_default_effort_only` | Base default max loss reports its default use; catches missing default-effort tracking. |
| R | `tests/test_synthetic_models_watch.py:401` `test_deepseek_without_low_is_changed_for_its_text_generation_role_only` | Missing role effort narrows affected use; catches adding unaffected default pointer. |
| R | `tests/test_synthetic_models_watch.py:413` `test_a_model_with_no_reasoning_parameters_is_changed_for_every_effort` | Absent capability data loses all required efforts; catches treating unknown capability as supported. |
| R | `tests/test_synthetic_models_watch.py:421` `test_unsafe_catalog_ids_are_reported_only_as_a_count` | Markdown/mention/instruction payloads never enter generated artifacts; catches unsafe third-party ID publication. |
| R | `tests/test_synthetic_models_watch.py:441` `test_every_catalog_value_in_the_body_sits_in_a_code_span` | Safe catalog values remain code-quoted; catches Markdown interpretation even for accepted IDs. |
| R | `tests/test_synthetic_models_watch.py:452` `test_same_findings_keep_the_fingerprint_and_new_ones_change_it` | Stable drift identity across time, changes for model or missing effort; catches issue churn or stale dedupe. |
| R | `tests/test_synthetic_models_watch.py:477` `test_offered_efforts_alone_change_the_body_digest_but_not_the_fingerprint` | Non-actionable catalog change silently refreshes body; catches inappropriate new notification fingerprint. |
| R | `tests/test_synthetic_models_watch.py:493` `test_the_detection_time_alone_keeps_the_body_digest` | Time refresh changes display but not body identity; catches daily workflow edits/comments. |
| R | `tests/test_synthetic_models_watch.py:503` `test_a_shorter_version_is_padded_before_it_is_compared` | Tuple versions pad zero components and compare numerically; catches (3) differing from (3,0). Distinct edge currently absent from CLI catalog cases; retain helper semantic proof. |
| R | `tests/test_synthetic_models_watch.py:525` `test_it_reads_back_the_marks_the_body_carries` | CLI issue-state reads persisted body markers; catches writer/reader protocol drift. |
| R | `tests/test_synthetic_models_watch.py:534` `test_a_body_without_marks_has_none` | Unmanaged issue state returns null markers; catches inventing reconciliation receipts. |
| R | `tests/test_synthetic_models_watch.py:540` `test_the_latest_notice_wins` | Latest recognized comment wins through human comments; catches first-notice or unrelated-comment selection. |
| R | `tests/test_synthetic_models_watch.py:550` `test_the_unreachable_notice_names_the_catalog_and_the_secret` | Failure notice actionable and machine marked; catches unparseable notice or lost recovery instruction. |
| R | `tests/test_synthetic_models_watch.py:564` `test_a_short_title_keeps_the_uses` | Short issue title keeps consumer context; catches premature elision. |
| R | `tests/test_synthetic_models_watch.py:568` `test_a_long_title_drops_the_uses_first` | Long title drops uses before actionable model request; catches exceeding forge limit or over-truncation. |
| R | `tests/test_synthetic_models_watch.py:578` `test_the_source_evaluation_has_a_default_time_limit` | Named evaluation timeout constant remains 300; catches configured default drift. Explicit timeout CLI behavior is independently tested below; this assertion alone is not runtime timeout proof. |
| R | `tests/test_synthetic_models_watch.py:581` `test_a_title_still_too_long_falls_back_to_a_count` | Bounded title falls back to count/source; catches overlong aggregate issue title. |
| R | `tests/test_synthetic_models_watch.py:594` `test_two_failures_exit_non_zero_with_no_issue_output` | Two transport failures stop without result/body; catches false clean result or stale issue creation. |
| R | `tests/test_synthetic_models_watch.py:599` `test_two_429_responses_exit_non_zero_with_no_issue_output` | HTTP rate-limit failures are retried then stop; catches treating curl-f HTTP failure as usable catalog. |
| R | `tests/test_synthetic_models_watch.py:604` `test_one_failure_is_retried` | First HTTP failure then valid drift succeeds with two calls; catches missing retry or ignored recovery. |
| R | `tests/test_synthetic_models_watch.py:610` `test_a_success_is_not_fetched_again` | One success stops fetching; catches unnecessary second API call. |
| R | `tests/test_synthetic_models_watch.py:615` `test_an_empty_catalog_exits_non_zero` | Empty/alias-only/malformed container cannot produce clean result; catches unavailable catalog treated as deletion/clean. |
| R | `tests/test_synthetic_models_watch.py:620` `test_a_body_that_is_not_json_exits_non_zero` | HTML server response rejected; catches publishing parse garbage. |
| R | `tests/test_synthetic_models_watch.py:623` `test_no_key_sends_no_header` | Unauthenticated catalog fetch uses correct URL without header/stdin; catches empty bearer header. |
| R | `tests/test_synthetic_models_watch.py:631` `test_an_empty_key_counts_as_unset` | Explicit empty environment key has unset semantics; catches sending Authorization Bearer empty. |
| R | `tests/test_synthetic_models_watch.py:637` `test_the_key_travels_on_stdin_only` | Retries send token only on stdin, absent argv/env/output artifacts; catches credential leakage boundary. |
| R | `tests/test_synthetic_models_watch.py:650` `test_a_failing_fetch_with_a_key_never_prints_it` | Echoing failed fetch diagnostics sanitized; catches secret leakage on error path. |
| R | `tests/test_synthetic_models_watch.py:657` `test_a_failing_fetch_without_a_key_reports_curl_s_reason` | Safe no-key failure retains actionable curl status/reason; catches opaque diagnostics. |
| R | `tests/test_synthetic_models_watch.py:661` `test_the_default_fetch_is_curl_with_a_time_limit` | Default PATH-selected curl receives bounded timeout and stdin auth; catches override-only testing missing real launch wiring. |
| R | `tests/test_synthetic_models_watch.py:710` `test_the_default_source_is_evaluated_with_nix` | Actual CLI launches nix eval of real source path; catches stale source/default command. |
| R | `tests/test_synthetic_models_watch.py:717` `test_a_hung_evaluation_times_out` | Explicit half-second timeout terminates hung source eval without result; catches omitted subprocess timeout. |
| R | `tests/test_synthetic_models_watch.py:725` `test_a_lineage_that_misses_its_own_id_is_refused` | Source regex must capture its own current model; catches silently unupgradeable source declaration. |
| R | `tests/test_synthetic_models_watch.py:735` `test_the_result_goes_to_stdout_without_result` | Default output is parseable clean result JSON; catches requiring file destination. |
| R | `tests/test_synthetic_models_watch.py:765` `test_it_writes_every_catalog_row_sorted_by_id_with_its_fields` | Snapshot keeps all 14 independent rows incl syn/infinite, only consumer fields and sorted IDs; catches in-use-only snapshot or lost modality/pricing fields. |
| R | `tests/test_synthetic_models_watch.py:795` `test_a_malformed_row_outside_the_source_is_skipped_and_named_or_keeps_its_previous_entry` | Malformed unrelated row warns/skips initially, retains previous good row later; catches poisoning whole snapshot or dropping installed catalog entry. |
| R | `tests/test_synthetic_models_watch.py:812` `test_a_snapshot_that_shrinks_below_the_retention_floor_is_refused` | Truncated response cannot replace full catalog, bytes preserved; catches missing shared shrink-floor invocation. |
| R | `tests/test_synthetic_models_watch.py:823` `test_a_row_without_reasoning_parameters_is_kept_with_no_efforts` | Optional reasoning omission preserved as absent; catches fabricated effort capabilities. |
| R | `tests/test_synthetic_models_watch.py:831` `test_an_empty_catalog_exits_non_zero_and_leaves_the_file` | Empty snapshot request preserves existing bytes; catches truncating before validation. |
| R | `tests/test_synthetic_models_watch.py:836` `test_a_second_run_leaves_the_file_as_it_is` | Identical snapshot leaves bytes and mtime unchanged; catches unconditional rewrite/workflow churn. |
| R | `tests/test_synthetic_models_watch.py:844` `test_a_catalog_missing_a_source_id_exits_non_zero_and_leaves_the_file` | Required in-use model missing aborts snapshot; catches dropping a configured model during refresh. |
| R | `tests/test_synthetic_models_watch.py:850` `test_efforts_that_are_not_a_list_of_strings_exit_non_zero` | Scalar/mixed/object efforts rejected with preserved output; catches malformed capability document reaching Pi. |
| R | `tests/test_synthetic_models_watch.py:860` `test_pricing_that_pi_cannot_parse_exits_non_zero_and_leaves_the_file` | Missing/numeric/currency/negative/double-dollar/empty/nonobject prices refused for in-use model; catches invalid Pi price schema. |
| R | `tests/test_synthetic_models_watch.py:884` `test_pricing_keeps_only_the_four_prices_and_accepts_every_shape_pi_parses` | Zero/scientific/dollar price strings accepted and extras projected out; catches validator overly narrow or leaking upstream-only prices. |

## Layer plan and handoff

Repair F1-F4 in their current owners. Carry no assertion into a generic host-build check: a successful closure build does not prove queue reconciliation, activation effects, API suppression, font fallback, unit wiring, or confidentiality. Delete only D1's repeated registry class and its unused option if the user approves changes. Keep the remaining exact attribution and actual materialized content as the provenance owner.

No C proposal: apparent repetitions here protect distinct entry points, platform/package delivery, input validation, or protocol/lifecycle paths. Synthetic/OpenRouter both call shared snapshot helpers, but each CLI must invoke retention, confidentiality, and projection correctly; replacing their boundary tests with one shared-helper unit test would lose that proof. Serve-html profile/Darwin checks protect delivery and interpreter closure, while Python protects HTTP/fork behavior. Retain both layers.

No tests or production files changed. There is no final line-count reduction or post-fix pass. Needed Linux/VM validation is stated per finding and remains pending. Review-only output is complete for the assigned manifest; parent owns whole-repository reconciliation and any decision to apply findings.
