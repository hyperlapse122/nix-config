# Systems platform audit

Review-only at `09e9f5aaf56f3bb549c69bc8499de9c208737e4d`. All 21 manifest files (3,506 lines) were read in full, with owners, entry points, shared enumeration, relevant dependencies, history, CI registration, and overlapping proof. No repository edits, staging, commits, pushes, nested agents, activation, credentials, or real container/device operations. R means retain; F means retain contract and repair proof. No C or D recommendation: these platform/package/security boundaries are independently useful.

## Evidence and limits

- Parent baseline: all-system flake evaluation and native `darwin-outputs` PASS; see `baseline-status.txt`. This is inherited evidence, not a new whole-suite run.
- New focused execution: `tests/podman-machine-resources.sh` and `tests/minikube-darwin-start.sh` against their source helpers PASS. `tests/mobile-devices.sh` against an executable, byte-identical source copy PASS. Logs: `platform-resources.log`, `platform-minikube.log`, `platform-mobile-rerun.log`. Initial mobile invocation used the non-executable repository source and failed with exit 126; the corrected invocation is the valid result. These are helper behavior runs using fake tools, not native package/VM/device integration evidence.
- Linux checks and both Podman VMs were not executed: native Darwin has no Linux builder/KVM; Podman remains stopped. Never count those as passes. Android Linux binaries were not run.
- Controls live only in `/tmp/nix-config-test-audit/platform-controls`, extracted with `git archive HEAD`, with no `.git`. The physical path uses `/private/tmp` on macOS. `missing-properties.sh` and `echo-auth.sh` execute exact assertion bodies in isolation; they do not claim full Linux check execution.
- Read the requested test-audit skill, `references/audit.md`, and `CAMPAIGN.md`. Relevant learnings include materialized output versus options, echo-only activation, decorative assertions, and copied-worktree index hazards. No cleanup campaign edits were authorized.

## Findings

### F1 — Missing NDK metadata passes its version assertion

`tests/android-sdk.nix:227-230`, used at line 168. `check_line` reports a bad existing file but explicitly skips a missing file. The NDK `source.properties` call has no preceding `check_file`; the package.xml and clang checks cannot establish that Gradle's version metadata exists. A package/layout regression dropping only `ndk/<version>/source.properties` leaves those other files intact and escapes this assertion.

Evidence: exact extracted helper with absent `source.properties` leaves `failed=0`; an existing wrong version sets `failed=1` (`platform-controls/missing-properties.sh`). This is a focused guard control, not a full SDK build mutation. The pinned androidenv composition links each NDK directory wholesale (`compose-android-packages.nix`, `linkNdkPlugins`), so metadata and compiler existence are independent properties.

Keeper/minimal fix: retain this SDK check; make `check_line` fail on missing files as well as wrong content, or explicitly require `source.properties` before this call. Keep package.xml, compiler startup, and literal API-level requirements. No sibling asserts Linux NDK source.properties: Darwin's SDK check covers different tools/layout. History: helper from `66a1cae`; NDK/CMake coverage added by `6c7edc3`; `5744b5f` fixed missing-file handling in `check_line_in`, leaving `check_line` unchanged. No production bug is alleged.

### F2 — Registry search proof ignores the installed target

`tests/podman-containers.nix:161-167,216-225`. It reads the specifically named xdg entry's `enable` and `text`, but never its resolved `target` or materialized home-files path. Retargeting that entry to `elsewhere.conf` preserves every compared value and passes this assertion while Podman no longer discovers the search registry configuration. Whole-line/structured parsing should also replace the unanchored regex, which accepts a commented line.

Keeper/minimal fix: retain this independent Podman configuration contract, inspect `.config/containers/registries.conf.d/10-unqualified-search.conf` in home-files (or locate enabled entries by their resolved target), then parse the TOML value. Keep rootless/system socket, package delivery, session and prune assertions. Home Manager's pinned `files.nix` filters enabled files and installs by `target`; option text alone does not prove delivery. The registry VM manually installs its own auth JSON and never checks the search drop-in; the prune VM also cannot substitute. History: text assertion `f05df46`; enabled-state repair `1deba4f`; neither added target validation. Evidence is direct source/dependency inspection; full Linux mutation execution unavailable.

### F3 — Auth activation can print its JSON without writing auth.json

`tests/podman-containers.nix:200-214`; Darwin's corresponding check at `tests/darwin-config.nix:556-558` only requires the step's existence. Replacing the activation body with `printf` of the same credHelpers JSON satisfies all these predicates but leaves a fresh user without auth.json. Permissions, preservation of an existing file, and dry-run behavior also have no executed assertion here.

Evidence: exact extracted Linux assertion block accepts the print-only body with `failed=0` (`platform-controls/echo-auth.sh`). `tests/podman-registry-auth.nix:116-118` creates auth.json directly and therefore supplies the state whose creation is missing from this proof; its real Podman consumer assertion remains valuable but cannot catch this activation regression. This is a focused guard control, not a full Linux check mutation.

Keeper/minimal fix: execute the actual containersAuth step with HOME redirected to scratch; check parsed credHelpers and modes 0700/0600, existing custom file bytes unchanged, and no changes during DRY_RUN. Keep the VM as a distinct packaged credential-helper/SOPS/user-permission/Podman consumer boundary. Apply the scratch activation owner on Darwin too, where containersAuth shares the body. History: initial check `f05df46`; `1deba4f` updated mappings; macOS port in `cb88f7f` retained only step presence. Production owner is `home/h82/dev/containers.nix`; imported on all host kinds by `home/h82/dev/default.nix`.

### F4 — Darwin Codex merge is checked only by command substrings

`tests/darwin-config.nix:459-465`. An `echo` before the merger preserves the after-installPackages edge, `--format toml`, and `--settings` target, but writes no TOML. `tests/darwin-outputs.nix` executes Pi's merge, not Codex's. `tests/codex-settings.nix` enumerates NixOS/Linux users through configurations.nix and does not reach Darwin. The Codex package wrapper's flags protect some update settings independently, but do not prove the Home Manager merge or retired developer_instructions removal.

Keeper/minimal fix: add the actual redirected Codex step to `darwin-outputs`, assert literal declared values and stale-key removal in written TOML, and require a deliberately failing merger to fail the step. Keep Linux-evaluable configuration checks for target/order as distinct routing proof. History: `316f7e0` added these predicates during Codex restoration; `4dbf84b` repaired precisely this class for Pi, with no corresponding Codex execution. Evidence: complete source and sibling review; native control status appended below. This is a test gap, not an observed current merge failure.

## Declaration ledger

Locations identify declarations/assertion classes; whole Nix checks are split by distinct contracts. All implicit host/variant rows inherit the same mark unless noted. A credible regression follows each contract.

### SDK, tool delivery, environment

| Mark | Declaration | Contract / credible regression |
| --- | --- | --- |
| R | android-sdk.nix:211, guards and per-entry generation | NixOS production/bootstrap SDK proof cannot silently cover no host or missing user. |
| R | android-sdk.nix:124-157, link/license/pinned package.xml/literal API rows | SDK links into store, licensed packages and both API 36/37 remain usable; dropped pin level or missing image/jar fails. |
| R | android-sdk.nix:158-164, adb/emulator | Executable Linux tools report pinned versions; unpatched or stale binaries fail. |
| R | android-sdk.nix:165-173, aapt2/clang | Every pinned toolchain starts; patchelf/runtime dependency regressions fail independently of metadata. |
| F | android-sdk.nix:168, NDK metadata | F1: missing Gradle version metadata currently skips assertion. |
| R | android-sdk.nix:174-189, cmake/ninja/sdkmanager | Pinned native-build versions and executable manager exist; stale or broken packaged tool fails. |
| R | android-sdk.nix:190-208, shell/environment/rc/JDK | Stable SDK/NDK paths, appended PATH without bundled sqlite shadowing, CLI flag and usable JAVA_HOME; prepend or missing export fails. |
| R | kubernetes-tools.nix:44, version table | Installed home.path kubectl/helm/minikube actually start offline; absent/broken binary fails. |
| R | kubernetes-tools.nix:81, kubectl origin | Explicit kubectl wins over minikube's download-on-demand shim; removed priority fails. |
| R | kubernetes-tools.nix:87, completion table | Each command ships its own nonempty zsh completion; missing/foreign completion fails. |
| R | session-variables.nix:92, generation and peers | Actual shell and environment.d files carry one well-formed package-derived allowlist; missing/retargeted file, whitespace, missing peer or multiline value fails. |
| R | session-variables.nix:69, expectedVariables table | Container privilege, Turbo and telemetry policies reach shell and user manager; dropped/wrong export fails on either transport. |

SDK history: `66a1cae`, `5744b5f`, `6c7edc3`, `55cbcf7`, Linux-only images corrected in `3b7acb9`. Kubernetes owner `home/h82/dev/kubernetes.nix`, introduced with check by `a3e4a6f`; package priority and completion are independent of minikube lifecycle. Session owner `tool-environment.nix`, containers.nix and agents/cross-model-peers.nix; `c26d98b` began materialized checks, `0458ec4` added standalone users, `08a7d06` added peers. Pinned Home Manager appends sessionVariablesExtra after generated exports; environment.d and login shell are distinct consumers, not duplicate tests.

### NixOS minikube and Podman

| Mark | Declaration | Contract / credible regression |
| --- | --- | --- |
| R | minikube-autostart.nix:181, positive unit | Materialized Type=exec, RemainAfterExit, configured ConditionUser, actual start/stop executables, wrapped Podman PATH, default.target link; blocking login or wrong-user startup fails. |
| R | minikube-autostart.nix:113-142, environment/delegation | Unit and both login environments choose same rootless profile/runtime and delegate cpuset/io; sudo driver or undelegated node fails. |
| R | minikube-autostart.nix:147, negative variants | Bootstrap, forced minikube-off and forced Podman-off carry no startup/delegation/environment; widened profile default fails independently of trait split. |
| R | minikube-autostart.nix:169-179, Linux fixtures | Standalone HM/system-manager have no minikube units; accidental NixOS service leakage fails. |
| R | podman-containers.nix:109-198, packages/socket/session | Podman, docker shim, SOPS helper installed; rootful socket not wanted; rootless socket/auth reach shell and user manager; enabling rootful or dropping helper fails. |
| F | podman-containers.nix:200-214, auth activation | F3: inspect written file rather than emitted JSON text. |
| F | podman-containers.nix:216-225, search drop-in | F2: prove consumer path, not just named option text. |
| R | podman-containers.nix:46, prune enabled | Materialized oneshot has correct account, wrapped executable and minikube exclusion; weekly persistent randomized timer is wanted and service is not directly wanted; changed filter/schedule/wiring fails. |
| R | podman-containers.nix:96, prune disabled | Trait-off has neither service nor timer; leaked unconditional units fail. |
| R | podman-prune.nix:43, live rootless pruning | Real user manager removes seeded stopped container/network/dangling image while keeping tagged image, named volume and minikube-labelled node/network; broadened destructive prune fails. |
| R | podman-prune.nix:114, other account | Wrong manager skips service via ConditionResult, rather than Result=success alone; removing user condition fails. |
| R | podman-registry-auth.nix:29, registry table | Four actual packaged helper routes decrypt distinct fake SOPS tokens as ordinary account; wrong username, token route, inaccessible secret fails. |
| R | podman-registry-auth.nix:109-114, negatives | Unsupported registry and absent secret configuration return protocol miss; unsafe fallback credentials fail. |
| R | podman-registry-auth.nix:116-123, Podman consumer | Actual Podman invokes credential protocol with auth config; broken helper discovery/transport fails. Auth file creation is fixture setup, not activation proof. |
| R | podman-registry-auth.nix:125-130, journal | Fake credentials never enter either system journal; logging decrypted data fails. |

Owners: modules/nixos/services/podman.nix and minikube.nix, modules/nixos/profile.nix defaults, home/h82/dev/containers.nix, packages/docker-credential-sops.nix, scripts/docker-credential-sops. Pinned nixpkgs Podman module generates compatibility shim; systemd materialization matters beyond its options. Helper's --map source tests cover input/schema protocol; VM adds SOPS publication, unprivileged access and real Podman. `277e528` introduced prune, `fc6fe9e` added minikube survival; `0d9a557` introduced autostart and `295f48b` added review repairs. Keep VM and materialized policy separately: VM seeds one host and does not prove fleet/bootstrap routing or schedule.

### Darwin helper declarations

| Mark | Declaration | Contract / credible regression |
| --- | --- | --- |
| R | minikube-darwin-start.sh:52 | Wait for two failed info probes, start once with profile/driver/runtime/resource flags; premature or wrong launch fails. |
| R | minikube-darwin-start.sh:64 | Never-ready Podman returns failure without cluster start; unbounded polling/false success fails. |
| R | minikube-darwin-start.sh:68 | Hung info bounded by deadline without cluster start; removed timeout fails. |
| R | minikube-darwin-start.sh:75 | Failing minikube propagates failure after reaching start; launchd retry would otherwise disappear. |
| R | podman-machine-resources.sh:48 | Matching resources do nothing; unnecessary stop/reconfiguration fails. |
| R | podman-machine-resources.sh:52 | Absent machine remains creation owner's responsibility; treating absence as error or setting it fails. |
| R | podman-machine-resources.sh:56 | Memory change stops/sets correct machine and values; CPU-only comparator or wrong argument fails. |
| R | podman-machine-resources.sh:61 | CPU change retries watchdog race; memory-only comparator or no retry fails. |
| R | podman-machine-resources.sh:66-71 | Persistent failure stops after three sets, never starts machine; infinite retry/false success/start fails. Earlier cases also compare complete logs excluding inspect. |
| R | mobile-devices.sh:184 | First apply downloads missing runtime and creates both declared devices from proper runtime/image, answers no; wrong platform/id/version fails. |
| R | mobile-devices.sh:196 | Second apply creates/downloads nothing; missing idempotence fails. |
| R | mobile-devices.sh:203 | New versions coexist with old runtime/devices; destructive upgrade or old version reuse fails. |
| R | mobile-devices.sh:218 | Preserve hand-made and undeclared devices, create missing declaration only; cleanup sweep fails. |
| R | mobile-devices.sh:231, failing/missing rows | Xcode failure or absent binary skips iOS once with useful message while Android works; coupled platform failure fails. |
| R | mobile-devices.sh:244 | Missing avdmanager reports once while iOS works; platform coupling or repeated diagnostics fails. |
| R | mobile-devices.sh:253 | Explicit bad JDK surfaces avdmanager error and preserves iOS; implicit JAVA_HOME dependency fails. |
| R | mobile-devices.sh:263 | Unknown iOS model/failing AVD do not prevent later valid devices; abort-on-first-device fails. |
| R | mobile-devices.sh:274 | Explicit iOS/Android versions override defaults; ignored version fails. |
| R | mobile-devices.sh:284 | Duplicate declarations create each once despite stale listing; failure to record same-run state fails. |
| R | mobile-devices.sh:296 | Invalid device-type JSON ends iOS only with diagnostic; permissive parser/coupled abort fails. |
| R | mobile-devices.sh:308 | One stale CoreSimulator failure retries successfully without stale error; missing retry/noise regression fails. |
| R | mobile-devices.sh:318 | Permanently dead service stops after two listings and prints separate diagnostic lines; unbounded retry/error concatenation fails. |
| R | mobile-devices.sh:334 | Each model selects newest supporting runtime and repeated apply is inert; blindly choosing global newest fails. |
| R | mobile-devices.sh:349 | Explicit unsupported runtime skips instead of silently choosing another; compatibility bypass fails. |
| R | mobile-devices.sh:357 | Invalid runtime JSON never triggers download and Android continues; treating errors as absence fails. |
| R | mobile-devices.sh:367 | Failed runtime download attempted once, each affected model reported, no create; retry-per-device or false install fails. |
| R | mobile-devices.sh:379 | Missing old runtime is skipped without downloading newest; incorrect fallback fails. |
| R | mobile-devices.sh:388 | Patch runtime satisfies major.minor SDK and chosen runtime id; exact-string-only match fails. |
| R | mobile-devices.sh:399 | Numeric SDK ordering chooses 27.0 over 9.3; lexical sort fails. |

Each mobile scenario also rejects destructive delete/erase/rename/move/unpair calls. Stubs implement external tool state, while production helper chooses devices, arguments, versions and retries; they do not fabricate those decisions. Owners are scripts of matching names, packaged with writeShellApplication in packages/. Production caller is containers.nix activation, kubernetes.nix launch agent, or mobile-devices.nix activation. History: container helpers `cb88f7f`, bounded-probe repair `212416e`; mobile `65cac3e`, JDK `9429e8c`, runtime compatibility/retry `5329334`, review repairs through `7d9d7d7`. Exact CLI flags are external tool contracts, not private call-shape cleanup candidates. These tests do not prove real VM creation or Simulator compatibility; preserve hardware verification.

### Darwin configuration and materialized outputs

`darwin-config.nix:865` is one Linux-evaluable declaration, with the independent classes below. `darwin-outputs.nix:489` is a native Darwin declaration; materialized classes are listed separately. Differences between them are meaningful cross-platform rendering/delivery risks, not an automatic reason to consolidate.

| Mark | Declaration/class | Contract / credible regression |
| --- | --- | --- |
| R | darwin-config.nix:130, zap filter controls | Store hash/name spelling zap is ignored while real --zap remains visible; over/underbroad path normalization fails. |
| R | darwin-config.nix:148, discovery | Exactly discovered Darwin fixtures, both variants, no misclassified Linux kind; dropped host/variant fails. |
| R | darwin-config.nix:198, mapping | Every NixOS-only GUI package has exactly one cask/Nix/omission decision; unreviewed GUI addition or ambiguous mapping fails. Literal required casks and Telegram flavor survive mapping changes. |
| R | darwin-config.nix:439-473, Homebrew | Enable bootstrapping, cask-set parity, cleanup none, updates/upgrades, trusted third-party taps and mapped Nix apps; accidental app removal or untapped cask fails. |
| R | darwin-config.nix:451, T3 fixture | Enabled nightly desktop remains a positive fixture; disabling trait cannot silently omit native assertions. |
| R | darwin-config.nix:454, registry routing | docker.io present and retired index alias absent in packaged routing data; stale alias migration fails. |
| R | darwin-config.nix:457-458, Codex package/peer | Codex installed and allowed; removed package/peer fails independently of config merge. |
| F | darwin-config.nix:459-465, Codex merge | F4: target/format/order substrings miss a print-only step. |
| R | darwin-config.nix:474-482, secret/SSH routing | Production-only host-secrets steps, no OrbStack merger, host-key config without agent; bootstrap secret step/foreign socket fails. This is routing proof, not decryption proof. |
| R | darwin-config.nix:483-506, machine/provider/reconciliation | One rootful libkrun machine with 8192/4, resources after initialization and outside dry run with correct TMPDIR; incorrect provider/default-machine collision/resource settings fails. |
| R | darwin-config.nix:507-529, launchd/socket | Watchdog survives process-group teardown at interactive priority; shell/GUI socket matches machine and no Linux Ryuk privileges; reload-kills-VM/wrong socket fails. |
| R | darwin-config.nix:530-553, peers | Enabled at-load two-command launchd agent and shell set package-derived peers/max=2; whitespace/wrong max/missing GUI transport fails. |
| F | darwin-config.nix:556-558, auth file | F3: step presence does not prove auth.json creation. |
| R | darwin-config.nix:555,559, container exclusions | Docker compatibility package, no store-linked registry drop-in; unavailable Docker CLI/dangling VM store links fail. |
| R | darwin-config.nix:560-578, minikube/nr | Production-only retrying agent with required PATH/resources and correct Darwin rebuild helper; bootstrap cluster or Linux nr fails. |
| R | darwin-config.nix:579-597, pinentry/editor/terminal | Darwin pinentry filter and unticked Keychain default, Application Support editor path, cask Ghostty and font order; Linux paths or unwanted PIN saving fail. |
| R | darwin-config.nix:598-611, system policy | Store optimisation off, shared fonts, auto appearance without fixed style, host/variant marker; Darwin unsafe defaults or wrong variant fail. |
| R | darwin-config.nix:612-687, Xcode/KakaoTalk | Primary-user launchctl identity, guarded install/get/upgrade, setup guards/diagnostics, order before HM; root session, apply-aborting command or wrong App Store id fails. |
| R | darwin-config.nix:688-721, retired casks | User sudo with absolute brew/PATH, exact missing/error distinction, guarded force-uninstall after KakaoTalk, never zap, no reinstalling mapping/mas modules; accidental data deletion or apply abort fails. |
| R | darwin-config.nix:722-760, skills | Enabled resolved targets, pinned skill source/version and exact four-root distribution with no legacy roots; mistargeted, disabled or extra delivery fails. |
| R | darwin-config.nix:761-784, SDK | User Library root, no Linux data link, emulator PATH and arm64-only image count; wrong ABI or Linux root fails. Actual per-API presence is independently checked natively below. |
| R | darwin-config.nix:785-802, devices integration | After linkGeneration, dry-run/nonzero containment and xcrun/SDK/JDK/API/device arguments, one Android default; wrong platform/default or activation ordering fails. |
| R | darwin-config.nix:825, valid option control | Valid explicit iOS device accepted; universal type rejection cannot make negatives pass. |
| R | darwin-config.nix:833,841, invalid option rows | Empty model and empty explicit version rejected; helper usage-error entries cannot reach apply. |
| R | darwin-config.nix:853, Linux exclusion | No Linux fixture has mobileDevices activation; widened import gate fails. |
| R | darwin-outputs.nix:136-150, secret stage/publish | Actual rendered activation order around writeBoundary/linkGeneration and bootstrap exclusion; lost DAG edge/step fails. |
| R | darwin-outputs.nix:152-174, containers | Materialized shell sockets/auth/socket override, no Ryuk or store systemd/containers, libkrun config and docker resolves to profile podman; rendering/link failure fails. |
| R | darwin-outputs.nix:176-196, watchdog/GUI socket | Actual plist preserves process-group/priority and GUI socket transport; disabled/incorrect plist generation fails. |
| R | darwin-outputs.nix:197-205, peers | Shell and actual at-load plist deliver expected peers/max=2, Codex included; launchd or shell serialization loss fails. |
| R | darwin-outputs.nix:206-215, minikube | Native plist present/retry/abandon/PATH in production only; disabled/missing generated login agent fails. |
| R | darwin-outputs.nix:216-245, GPG | Real gpg-agent/scdaemon paths, Darwin filter and backend, zero TTL, imported UseKeychain false; missing home file, wrong backend, cached PIN default fails. Parent's separate gpg-agent-no-cache finding is not repeated here. |
| R | darwin-outputs.nix:247-259, terminal/nr | Delivered font order and actual nr path point to Darwin helper; missing/foreign home file or wrong executable fails. |
| R | darwin-outputs.nix:261-277, Pi keys | Real installed helpers use user secret-state files for both providers; Linux /run/secrets default leakage fails. |
| R | darwin-outputs.nix:279-303, Antigravity/serve-html | Pinned runtime exec/sibling route, seeding wiring/no SSL_CERT_FILE and packaged serve-html delivered; wrong binary, SSL breakage or missing sibling fails. Runtime token semantics remain sibling owner tests. |
| R | darwin-outputs.nix:305-343, Pi settings | Executes exact redirected activation, independently validates declarations and applied file; echo-only merge or lost settings fails. This is the keeper pattern for F4. |
| R | darwin-outputs.nix:346-347, VSCodium path | Actual activation targets Application Support; Linux XDG path leakage fails. |
| R | darwin-outputs.nix:349-382, SDK | Native avdmanager/adb paths, each pinned arm64 image, emulator env wrapper and real executable, session/PATH; empty image set/wrong wrapper/missing tool fails. |
| R | darwin-outputs.nix:380-402, devices | Actual activation after links calls built helper with xcrun/SDK/API/devices and runnable JDK; missing packaged helper or invalid JAVA_HOME fails. |
| R | darwin-outputs.nix:404-416, T3 | Native nightly bundle executable equals release archive bytes, update agent exists; repacking signed main executable or dropping agent fails. Positive trait guard resides in darwin-config. |
| R | darwin-outputs.nix:418-440, system/Brew | Native nix.conf, marker, exact mapped Brewfile and autoMigrate setup; absent output/stale cask/first-apply takeover regression fails. |
| R | darwin-outputs.nix:442-470, root activation | Materialized brew/Xcode/KakaoTalk/retired-cask/HM order and primary-user execution; assembled activation ordering loss fails. Static order is not a claim of real App Store execution. |
| R | darwin-outputs.nix:472-486, fonts/appearance | Fonts present and automatic appearance command emitted without fixed style; failed font delivery/forced dark-light style fails. |

Owners read: lib/{hosts,darwin-host,linux-host}.nix; modules/darwin/{profile,homebrew,xcode,app-store,retired-casks,nix,host-marker,fonts,defaults}.nix; modules/shared/darwin-apps.nix; home/h82/dev/{default,containers,kubernetes,android,mobile-devices}.nix; agents/{cross-model-peers,codex}.nix; packages/{android-sdk,mobile-devices,minikube-darwin-start,podman-machine-resources,docker-credential-sops}.nix and matching scripts. Related Pi and Codex settings checks were inspected for scope and overlap. Dependency source review included pinned HM file target/enable materialization, session-variable ordering, Podman config copy/machine init/watchdog; pinned nix-darwin activation set -e/postActivation ordering and brew bundle; pinned nixpkgs Android composition and Podman shim. No claim was made that a source fragment alone proves App Store/network/hardware operation.

History: Darwin assembly `64f5c67`, output check `ee60ead`, Podman migration `cb88f7f`, Android `4268f7e` and `bf25d9a`, Pi scratch execution `4dbf84b`, OpenRouter helper `ff18cc0`, Codex restore `316f7e0`, current no-iOS default `4122a69`, startup correction `8ed6938`. These explain independent migration/platform guards; none establishes a redundant removable layer.

### Standalone Linux outputs and support files

| Mark | Declaration/class | Contract / credible regression |
| --- | --- | --- |
| R | non-nixos-outputs.nix:76,265 | Nonempty fixtures, production/bootstrap pair and positive T3 CLI fixture; dropped variant/trait cannot erase assertions. |
| R | non-nixos-outputs.nix:114-133 | Account/home follows host facts, x86-only SDK, GUI exclusion and CLI trait; hardcoded account, unsupported architecture package, desktop leakage or ignored trait fails. |
| R | non-nixos-outputs.nix:134-165 | Production secret stages/order, Linux nr, identity installer, copied host-key SSH without agent, Codex package/peer/instructions/merge target; bootstrap secret activation or stale NixOS integration fails. Execution/decryption proof remains host-secrets/non-nixos-vm owners. |
| R | non-nixos-outputs.nix:166-169 | No Plasma/KDE/autostart resolved enabled config; unconditional desktop import fails. |
| R | non-nixos-outputs.nix:177, consumers | Built Tokscale/Pi/SOPS routing reads published state directory; Linux system secret paths leaking into standalone build fails. No executable-value claim beyond wiring. |
| R | non-nixos-outputs.nix:230, system ownership | System-manager never takes distribution account/id/shell/NVIDIA files or escapes etc; userborn/default file ownership regression fails. |
| R | non-nixos-outputs.nix:245-264, native system | Materialized pcscd/ccid/socket, nixbld/root trust and host/variant marker; missing driver, wrong daemon exec or unsafe Nix settings fails. VM additionally proves socket permissions and actual activation. |
| R | fixtures/hosts/hollyhock/default.nix:1 and host.nix:1 | x86 Linux fixture uses nondefault tester account/GPG and deliberately enables NixOS-only WiFiman; hardcoded user or leaking platform trait becomes visible. Support, not a test declaration. |
| R | fixtures/hosts/juniper/default.nix:1 and host.nix:1 | aarch64 Linux fixture keeps default user and enables T3 CLI; unsupported x86 package leakage and arm CLI install fail on native CI. Support, not a declaration. |
| R | fixtures/hosts/magnolia/default.nix:1 and host.nix:1 | aarch64 Darwin nondefault /Users account with both T3 traits; hardcoded /home/user and omitted nightly bundle proof become visible. Support, not a declaration. |
| R | lib/android-pin.nix:1 | Independent expected pin platforms/newest arm64 API/device argument rendering used by Darwin policy and materialized checks; owner selecting stale API/wrong platform is compared against this oracle. No production caller or test-only production seam; no standalone declaration. |
| R | lib/cross-model-peers.nix:15 | Installed-package-to-CE token oracle, independent of my.agents.crossModelPeers; module omitting Codex/Claude token fails consumer checks. No standalone declaration or production seam. |

Standalone history: `66c0e58` outputs/fixtures, `37f817c` pcscd/Nix system layer, `a4908dc` secret publication, `273a2a6` SSH writable copy, `baa9ad1` CLI trait, `64f5c67` Darwin fixture, `316f7e0` Codex. Support helpers remain shared test oracles rather than copied expected output: android-pin folds newest independently of owner's sorting and ties data to literal native paths; peer mapping derives expectations from installed packages rather than the production peer option. Preserve these contracts even though checks are static.

## Routing and layer plan

- `flake.nix:313-338` registers the three fake-tool helper suites and darwin-config in x86_64 Linux checks; CI ordinary `check-shards` builds sorted light shards. Native source helper runs above do not substitute for their packaged Linux checks.
- `flake.nix:820-842` registers SDK, session, Kubernetes, Podman and minikube checks; minikube is explicitly in hostClosureChecks; other checks remain declared light-shard members even though some pull host files. No check was found unregistered.
- `flake.nix:1838` registers standalone output inspection, with hostClosureChecks membership. Fixture output checks build HM/system-manager for each supported architecture, with aarch64 scheduled natively by build-linux. Native-specific branches in non-nixos-outputs remain honest platform limits, not redundant proof.
- `flake.nix:131` registers native darwin-outputs; check.yml build-darwin builds every Darwin check and real production/bootstrap output on macos-15. darwin-config gives independent Linux evaluation feedback before native output materialization.
- `tests/vm-checks.nix:28-29` registers registry-auth and prune outside ordinary checks. check.yml vm-checks lists/builds each on Linux/KVM. Their lifecycle/security evidence remains independent of configuration assertions.
- Keeper plan: retain all files; repair F1 locally, F2 at materialized Podman config, F3 at actual scratch containersAuth activation, F4 at actual scratch Darwin Codex activation. Carry configuration/variant routing proof forward. No retired test file, no production seam deletion, no deletion/LOC target, no repository change made.

Manifest reconciliation: all 21 files have explicit dispositions above, including six fixture files and two support libraries. No assigned file remains unaudited. This completes this manifest's review, not execution of unavailable Linux/VM/hardware checks and not the parent campaign's other manifests. Parent-owned python3-runtime and gpg-agent-no-cache findings and prior systems.md findings are deliberately not repeated.

## Native control completion

Native import/build of the entire darwin-config check using the archive's real Linux and Darwin fixtures and aarch64-darwin pkgs: baseline exit 0; mutation adding only `echo` before `${merger}` in the archived home/h82/agents/codex.nix activation: exit 0. Logs are `platform-darwin-config-control.log` and `platform-darwin-config-echo-codex.log`; the mutation diff is `platform-codex-control.diff` (mutant-to-original direction). The mutant emits the same successful check derivation, because every predicate still evaluates true. This confirms F4 with the complete check, not merely an extracted predicate. No Darwin system activation was run. Initial `path:/tmp/...` import was rejected because /tmp is a symlink; the corrected physical `path:/private/tmp/...` invocation supplies the successful runs.

Final shared repository status remained clean at the same pinned HEAD. Findings are review recommendations only; none was applied.
