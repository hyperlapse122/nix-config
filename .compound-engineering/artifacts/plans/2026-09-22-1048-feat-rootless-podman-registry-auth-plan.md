---
title: Rootless Podman and Registry Credential Helper - Plan
type: feat
date: 2026-09-22
topic: rootless-podman-registry-auth
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Rootless Podman and Registry Credential Helper - Plan

## Goal Capsule

- **Objective:** After a reboot, the developer pulls and pushes images from the project's private registries with no manual login step, and no registry token is readable anywhere in the home directory.
- **Means:** One credential helper binary answers Podman's credential lookups by reading the SOPS-decrypted tokens the machine already holds, instead of storing credentials in `auth.json`.
- **Product authority:** This plan covers the container runtime and registry authentication. Declared container services, Kubernetes, and the wiring that would hand the Podman socket to an isolated agent are not active scope.
- **Open blockers:** None block planning. Two items block the hardware result: a Docker Hub credential does not exist and must be created and encrypted by the developer, and the existing tokens may lack registry scopes. Both are recorded under Dependencies and Assumptions.

---

## Product Contract

### Summary

Bring rootless Podman into the flake as declared configuration, and authenticate the four registries the developer uses through a credential helper backed by the machine's existing SOPS secrets. Credentials stay in the LUKS-protected runtime secret store; `auth.json` carries only the mapping that points Podman at the helper.

### Problem Frame

The repository configures this machine declaratively and holds the developer's GitHub, GitLab, and JPI tokens under SOPS, but it configures no container runtime at all. Podman, its storage, its user namespace allocation, and every registry credential are currently whatever the developer set up by hand, so a reinstall loses them and nothing in the repository records what they were.

The token side is the sharper problem. The reference dotfiles repository solves it by rendering `base64("user:PAT")` directly into `~/.config/containers/auth.json` on every apply. That works, but it writes long-lived registry tokens into a plain file in the home directory, where anything the developer runs can read them. This machine already decrypts the same class of token into a root-owned tmpfs at `/run/secrets`, which is a strictly better place for them to live — the repository just has no consumer that reads them for container use.

### Key Decisions

- KD1. **Credentials are served by a credential helper, not written into `auth.json`.** (session-settled: user-directed — chosen over rendering `base64("user:PAT")` entries at activation: the token source here is a local tmpfs file rather than a network secret manager, so the per-pull cost that made the reference repository abandon helpers does not apply.) Governs R5, R6, R9.
- KD2. **One helper binary, with the registry-to-secret routing table fixed at build time.** Adding a registry is one attribute-set entry plus one secret. Per-registry helper binaries were rejected: every helper would run as the same user, so splitting them buys no isolation and multiplies one template bug. Governs R5, R7.
- KD3. **The helper reads the decrypted secret at call time.** Nothing is staged, rendered, or copied at activation, so a rotated token takes effect on the next rebuild with no second materialization step to keep in sync. Governs R6, R9.
- KD4. **An unmapped registry or an absent secret is a silent credential miss, not an error.** This deliberately diverges from how `modules/nixos/secrets.nix:112-117` treats absent secrets, which is to fail activation loudly. A helper that errors instead of reporting "not found" breaks anonymous pulls of public images, which is exactly the state the bootstrap host runs in. Governs R8, R12.
- KD5. **`auth.json` stays a writable file owned by the user.** A read-only store symlink would make `podman login` fail for any registry outside the mapping. Governs R10.
- KD6. **Runtime configuration is split by secret dependency, not by subject.** Everything that needs a decrypted token sits behind the existing production-only gate; everything else is host configuration that the bootstrap host also evaluates. Governs R1, R4, R11.

### Requirements

**Runtime**

- R1. The flake configures rootless Podman for user `h82`, with the `docker` command available as the Podman shim. No Docker daemon is installed and no rootful Podman socket is enabled.
- R2. The user namespace allocation for `h82` comes from the configuration, so container UID mapping does not depend on manual `usermod` state.
- R3. The rootless user-level Podman socket is enabled, and Docker API clients find it through `DOCKER_HOST` pointing at the socket under the user's runtime directory.
- R4. Unqualified image names resolve through a declared registry search configuration rather than Podman's built-in default.

**Registry authentication**

- R5. A single credential helper serves Podman's credential lookups for `ghcr.io`, `registry.jpi.app`, `registry.gitlab.com`, and `docker.io`.
- R6. The helper reads the token from the machine's decrypted secret store at the moment Podman asks for it, and returns the registry host, the username, and the secret in the credential-helper response format.
- R7. Each supported registry maps to one secret and one username, declared in configuration rather than inside the helper's own logic.
- R8. When the helper is asked about a registry it does not map, or the mapped secret is unreadable, it reports a credential miss and exits non-zero without emitting the miss as an error condition Podman would treat as a failure.
- R9. `auth.json` contains only the registry-to-helper mapping. It contains no token, no base64-encoded credential, and no `auths` entry for any mapped registry.
- R10. `auth.json` is a user-owned writable file, so `podman login` still works for registries outside the mapping.
- R11. The bootstrap host, which has no decrypted secrets, evaluates and builds without the credential helper's secret dependency, and anonymous pulls of public images still succeed on it.
- R12. No token value reaches standard error, the journal, or any build log, on success or on failure.

**Verification**

- R13. A repository check exercises the helper against a fixture secret directory and asserts: a mapped registry returns the expected response, an unmapped registry reports a credential miss, an absent secret directory reports the same miss, and no token appears in any output stream.
- R14. A repository check reads the materialized `auth.json` and asserts that each supported registry key points at the helper and that no `auths` entry carries a credential.
- R15. A VM check confirms the credential lookup path end to end for a mapped registry using a fixture secret, and confirms that the same lookup reports no credential on a node without secrets.

### Acceptance Examples

- AE1. Mapped registry, secret present.
  - **Covers R5, R6.**
  - **Given:** The machine has booted and SOPS has decrypted the tokens.
  - **When:** Podman requests credentials for `registry.jpi.app`.
  - **Then:** The helper returns the JPI username and token, and the pull proceeds without prompting.
- AE2. Unmapped registry.
  - **Covers R8.**
  - **Given:** `quay.io` is not in the routing table.
  - **When:** Podman requests credentials for `quay.io`.
  - **Then:** The helper reports a credential miss, and Podman falls back to an anonymous pull rather than failing.
- AE3. Bootstrap host, no secrets.
  - **Covers R8, R11.**
  - **Given:** The bootstrap host is running and `/run/secrets` holds nothing.
  - **When:** Podman requests credentials for `ghcr.io`.
  - **Then:** The helper reports the same credential miss as AE2, and an anonymous pull of a public image succeeds.
- AE4. Manual login to an unmapped registry.
  - **Covers R10.**
  - **Given:** `auth.json` exists with the mapping.
  - **When:** The developer runs `podman login` against a registry outside the mapping.
  - **Then:** The login succeeds and its entry persists in `auth.json` alongside the mapping.

### Scope Boundaries

- Declared container services. No Quadlet units and no service list; starting containers stays a per-project, manual action.
- Kubernetes and minikube. Not a stated use case, so the cgroup controller delegation the reference repository needs for rootless minikube is not carried over.
- Image and volume pruning. The reference repository runs a weekly prune timer; this work stops at the runtime.
- Agent sandbox wiring. The socket exists and nothing blocks an isolated process from being given it, but no mechanism in this repository hands it over.
- SELinux policy. The reference repository carries a `pasta` policy module for Fedora; this host does not run SELinux.
- Container-consumer environment variables. The reference repository's Testcontainers and Turborepo workarounds are project-level concerns, not host configuration.

### Dependencies and Assumptions

- Prerequisite, developer-performed: a Docker Hub credential does not exist. `secrets/tokens.yaml` holds only `github_token`, `gitlab_token`, and `jpi_token`, and no Docker Hub username appears anywhere in the repository. Covering `docker.io` under R5 requires the developer to issue a Docker Hub access token, add it and the username to the SOPS file, and re-encrypt to the real age recipients. An agent cannot perform this step. Planning and implementation proceed without it; only the `docker.io` half of R5 and the hardware confirmation of it wait on it.
- The rootless socket must exist for `DOCKER_HOST` to mean anything, so R3 depends on R1.
- Assumption: `registry.jpi.app` is the container registry for the `git.jpi.app` GitLab instance. The reference repository's `glab` registry-domain mapping states this. A live probe also showed `git.jpi.app` itself answering as a dependency proxy rather than a registry, but no committed configuration records that, so treat the `git.jpi.app` half as observed rather than established.
- Assumption: `jpi_token` authenticates `registry.jpi.app`, because the registry's token realm is on `git.jpi.app`.
- Assumption: the helper resolves from the user systemd manager's PATH, not only an interactive shell's, because socket-mediated pulls run under the user Podman service. R15's socket-path coverage is what would disprove this.
- The existing tokens were issued for the `gh` and `glab` CLIs. Registry scopes are unverified; see Outstanding Questions.
- `docs/verification.md` does not currently describe every registered check — seven have no entry — so adding one there is a judgment call for this work, not an established repository invariant.

### Outstanding Questions

**Deferred to planning**

- Whether the existing tokens carry registry scopes — `read_registry` or `write_registry` for GitLab, `read:packages` or `write:packages` for GitHub. Without them the configuration is correct and the pull still returns 401. Planning determines how this is checked and whether re-issuing tokens becomes a prerequisite step.
- Whether `docker.io` needs both the bare domain and the legacy `index.docker.io` form in the mapping, since Podman and the Docker CLI disagree about which key a Docker Hub lookup uses.

### Sources and Research

- `modules/nixos/secrets.nix:10-19,110` — the existing pattern for consuming a decrypted secret as the target user.
- `modules/nixos/secrets.nix:112-117` — the absent-secret failure branch that KD4 deliberately diverges from.
- `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix:16` — the production-only gate on secret-dependent configuration.
- `flake.nix:36-58` — the shared module list both hosts instantiate, which is why the bootstrap host evaluates the Home Manager modules too.
- `packages/gpg-tools.nix:4-19` — the packaging pattern for a repository script.
- `flake.nix:91-100` — the script-level check shape; `flake.nix:116-129` — the materialized-output assertion shape.
- `tests/auth-provisioning.nix:3-17` — the fixture that encrypts fake tokens under a test age key.
- `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md` and `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md` — why R14 asserts on the rendered file and why a store path must be interpolated behind a guard.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Serve credentials via a standalone helper script rather than embedding tokens in `auth.json`.** (session-settled: user-directed — chosen over rendering `base64("user:PAT")` entries at activation: the token source here is a local tmpfs file rather than a network secret manager, so the per-pull cost that made the reference repository abandon helpers does not apply.) Reading `/run/secrets/` at execution time preserves local token protection. Governs R5, R6, R9.
- KTD2. **Package one helper binary with a static routing table compiled in.** Adding a registry requires one configuration entry rather than a new binary derivation. Governs R5, R7.
- KTD4. **Emit the miss on stdout as exactly `credentials not found in native keychain`, with a non-zero exit.** containers/image compares that message for equality and only inside its error branch, so any other text or a zero exit turns an anonymous-pull fallback into a hard failure. Governs R8, R11, R12.
- KTD6. **Point reads and writes at `~/.config/containers/auth.json` with `REGISTRY_AUTH_FILE`.** Podman otherwise writes to `$XDG_RUNTIME_DIR/containers/auth.json`, which sits ahead of the configured file in the read order, so a later `podman login` would shadow the helper with a plaintext entry. Governs R9, R10.
- KTD7. **Configure registry search domains via a drop-in file in `registries.conf.d`.** Avoids creating `~/.config/containers/registries.conf`, which would shadow the system-level configuration generated by NixOS. Governs R4.
- KTD8. **Install the helper binary into `environment.systemPackages`.** Ensures the helper is available in `/run/current-system/sw/bin` for systemd user services without relying on shell-only PATH expansions. Governs R3, R5.
- KTD9. **Rely on NixOS automatic subuid and subgid range allocation.** User `h82` is configured with `isNormalUser = true` and no explicit ranges, so NixOS allocates the standard 65536 range automatically. Governs R2.
- KTD10. **Enable rootless Podman while explicitly disabling the rootful system socket.** Prevents root-equivalent daemon socket creation while providing the rootless user socket and Docker compatibility shim. Governs R1, R3.
- KTD11. **Evaluate container runtime and helper packages on both production and bootstrap hosts.** Decouples runtime package evaluation from secret availability so the bootstrap host builds successfully and supports anonymous pulls. Governs R1, R11.
- KTD12. **Verify materialized file contents, helper protocol compliance, and offline login in checks and VM tests.** Asserts against materialized activation artifacts and exact helper protocol strings across both hosts, using distinct fake token fixtures. Governs R13, R14, R15.

Product Contract preservation: restructured, no scope change. R2 kept its intent — container UID mapping must not depend on manual `usermod` state — but planning found that intent already satisfied without a declaration, so KTD9 records the automatic allocation rather than adding one. No R-ID was split, renamed, or removed.

### Implementation Constraints and Sequencing

- The credential helper must emit exact string `credentials not found in native keychain` on stdout and exit with code 1 on any lookup miss.
- The helper must strip trailing whitespace and newlines from secret values before emitting JSON output.
- The helper must never output token values, exceptions, or sensitive data to stderr or process logs.
- The `auth.json` file must be created via `home.activation` using the `run` helper function with an existence check to avoid overwriting manual logins.
- `REGISTRY_AUTH_FILE` and `DOCKER_HOST` must be declared in both `home.sessionVariables` and `systemd.user.sessionVariables`.
- The rootful Podman socket must be disabled using `systemd.sockets.podman.wantedBy = lib.mkForce [ ];`.
- User `h82` must never be added to the `podman` group.
- All repository checks must guard store path interpolations, avoid `! cmd` constructs in builders, assert materialized outputs on both production and bootstrap hosts, and use distinct fixture tokens.

Sequencing:
- U1 (Podman NixOS runtime) and U2 (credential helper script and unit tests) can be developed independently.
- U3 (helper packaging and NixOS wiring) depends on U1 and U2.
- U4 (Home Manager containers configuration) depends on U1 and U3 for environment variables and helper references.
- U5 (repository checks and VM test) depends on U1, U2, U3, and U4.
- U6 (documentation) depends on U5 for registered check naming and hardware verification steps.

### Assumptions

- Provisioning `docker.io` credentials in `secrets/tokens.yaml` is a developer-performed prerequisite; until provisioned, the helper returns a clean miss for `docker.io` and anonymous pulls succeed.
- User namespace UID and GID ranges for `h82` are automatically assigned by NixOS without manual `subUidRanges` declarations.
- `registry.jpi.app` authenticates with the token provided by `jpi_token`.
- Existing GitHub and GitLab tokens carry necessary package and registry scopes (`read:packages`, `read_registry`); scope validation is an operational check documented in `docs/provisioning.md`.
- Systemd user units resolve binaries in `/run/current-system/sw/bin` via `/etc/environment.d/50-systemd-path.conf`.

---

## Implementation Units

### U1. Podman runtime NixOS module

- **Goal:** Declare rootless Podman and the Docker CLI compatibility shim for user `h82` with the rootful socket disabled.
- **Requirements:** R1, R2, R3; per KTD9, KTD10, KTD11.
- **Dependencies:** none.
- **Files:**
  - `modules/nixos/podman.nix` (new)
  - `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`
- **Approach:**
  1. Create `modules/nixos/podman.nix` declaring `options.my.podman.enable`.
  2. In module configuration, set `virtualisation.podman.enable = true` and `virtualisation.podman.dockerCompat = true`.
  3. Disable the rootful systemd socket using `systemd.sockets.podman.wantedBy = lib.mkForce [ ];`.
  4. Ensure `virtualisation.podman.dockerSocket.enable` and auto-prune timers remain disabled.
  5. Verify no explicit `subUidRanges` or `subGidRanges` are declared, allowing NixOS automatic allocation for `h82`.
  6. Import the module into `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` and enable it unconditionally (`config.my.podman.enable = true;`) so both production and bootstrap hosts evaluate it.
- **Patterns to follow:** `modules/nixos/keyd.nix` for `my.*` option and module structure; `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` for imports.
- **Test scenarios:**
  - `Test expectation: none -- pure declarative configuration; U5 carries the assertions that prove options and services materialized.`
- **Verification:** Both production and bootstrap host system toplevel configurations build successfully.

### U2. Credential helper script and standalone protocol tests

- **Goal:** Implement the credential helper script adhering to the docker-credential helper protocol and verify it with standalone Python unit tests.
- **Requirements:** R5, R6, R8, R12; per KTD1, KTD2, KTD4, and KD3.
- **Dependencies:** none.
- **Files:**
  - `scripts/docker-credential-sops` (new)
  - `tests/test_docker_credential_sops.py` (new)
- **Approach:**
  1. Implement `scripts/docker-credential-sops` in Python 3 supporting `get`, `store`, `erase`, and `list` subcommands.
  2. In `get`: read the registry domain from standard input, stripping whitespace. Look up the domain in a static routing table.
  3. If found, read the mapped secret file from disk. Strip trailing newlines and whitespace. If the file is missing, empty, or unreadable, or if the registry is unmapped: print `credentials not found in native keychain` to standard output and exit with code 1.
  4. If the secret file is valid, output JSON `{"ServerURL": "<domain>", "Username": "<user>", "Secret": "<token>"}` with a trailing newline to standard output and exit with code 0.
  5. In `store`: consume standard input and exit with code 0 without writing credentials to disk.
  6. In `erase`: consume standard input and exit with code 0.
  7. In `list`: emit a JSON map of configured registry URLs to usernames and exit with code 0.
  8. Ensure error handling suppresses tracebacks and never writes tokens or secrets to standard error.
  9. Implement `tests/test_docker_credential_sops.py` with unit test cases for all subcommands, exact miss message equality, newline stripping, and absent secret handling.
- **Patterns to follow:** `scripts/publish-cli-auth` for Python script design; `tests/test_publish_cli_auth.py` for standalone script unit testing.
- **Test scenarios:**
  - Covers AE1. Mapped registry with valid secret: invoke `get` with `registry.jpi.app` on stdin and fixture secret file; expect exit code 0 and stdout JSON containing ServerURL, Username, and Secret.
  - Covers AE2. Unmapped registry: invoke `get` with `quay.io` on stdin; expect exit code 1, exact stdout `credentials not found in native keychain`, and empty stderr.
  - Covers AE3. Absent secret file: invoke `get` with `ghcr.io` on stdin when secret file is missing; expect exit code 1, exact stdout `credentials not found in native keychain`, and empty stderr.
  - Trailing newline stripping: invoke `get` with secret file ending in newlines; expect emitted Secret string in JSON to have trailing newlines removed.
  - Subcommands `store`, `erase`, `list`: invoke helper with `store`, `erase`, and `list`; expect exit code 0 and valid response structure.
  - Secret leakage prevention: invoke `get` with invalid inputs; verify stderr contains no token values or tracebacks.
- **Verification:** Run standalone Python tests (`python3 tests/test_docker_credential_sops.py`).

### U3. Registry secret wiring and helper package build

- **Goal:** Declare registry credentials and usernames in `modules/nixos/secrets.nix`, package the credential helper with its static routing table, and install it to system packages.
- **Requirements:** R5, R6, R7, R8, R11; per KTD2, KTD8, KTD11.
- **Dependencies:** U1, U2.
- **Files:**
  - `modules/nixos/secrets.nix`
  - `packages/docker-credential-sops.nix` (new)
- **Approach:**
  1. Add `dockerUser` option to `options.my.cliAuth` in `modules/nixos/secrets.nix` alongside existing user options.
  2. Create derivation in `packages/docker-credential-sops.nix` using `stdenvNoCC.mkDerivation`, substituting the fixed routing table into `scripts/docker-credential-sops`:
     - `ghcr.io` mapping to `cfg.githubUser` and `/run/secrets/cli-auth/github_token`
     - `registry.gitlab.com` mapping to `cfg.gitlabUser` and `/run/secrets/cli-auth/gitlab_token`
     - `registry.jpi.app` mapping to `cfg.jpiUser` and `/run/secrets/cli-auth/jpi_token`
     - `docker.io` mapping to `cfg.dockerUser` and `/run/secrets/cli-auth/docker_token`
  3. Add the packaged helper derivation to `environment.systemPackages` on both production and bootstrap hosts.
  4. Ensure the routing table reference to `/run/secrets/cli-auth/docker_token` remains functional even when the file does not yet exist on disk, producing clean not-found results.
- **Patterns to follow:** `packages/gpg-tools.nix` for script substitution and packaging; `modules/nixos/secrets.nix` for option declaration and user management.
- **Test scenarios:**
  - `Test expectation: none -- derivation packaging; verified via check registrations and VM testing in U5.`
- **Verification:** Both host system toplevels build successfully with the helper binary present in system packages.

### U4. Home Manager containers module

- **Goal:** Configure user-level container environment variables, search registries drop-in, and writable `auth.json` with helper mappings.
- **Requirements:** R3, R4, R9, R10; per KTD6, KTD7, and KD5.
- **Dependencies:** U1, U3.
- **Files:**
  - `home/h82/containers.nix` (new)
  - `home/h82/default.nix`
- **Approach:**
  1. Create `home/h82/containers.nix`.
  2. Declare `home.activation.containersAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''...''` using the `run` helper function. Check for existence of `~/.config/containers/auth.json`; if absent, seed a regular file containing `credHelpers` mappings for `docker.io`, `ghcr.io`, `registry.gitlab.com`, and `registry.jpi.app` pointing to helper suffix `sops`, with file mode 0600. Leave existing files untouched.
  3. Add drop-in configuration `xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".text = ''unqualified-search-registries = ["docker.io"]'';`.
  4. Set `REGISTRY_AUTH_FILE = "/home/h82/.config/containers/auth.json"` in both `home.sessionVariables` and `systemd.user.sessionVariables`.
  5. Set `DOCKER_HOST` to the rootless socket under the runtime directory in both `home.sessionVariables` and `systemd.user.sessionVariables`. Resolve the runtime directory through `XDG_RUNTIME_DIR` expansion rather than a literal uid — the repository does not pin `users.users.h82.uid`, so a hardcoded `/run/user/1000` would break if the uid ever changed.
  6. Import `./containers.nix` in `home/h82/default.nix` in alphabetical order between `./claude.nix` and `./fcitx5.nix`.
- **Patterns to follow:** `home/h82/kde/apps.nix` for `home.activation` DAG entry with `run`; `home/h82/default.nix` for sorted imports.
- **Test scenarios:**
  - Covers AE4. Writable `auth.json`: verify activation script creates regular file with 0600 mode if absent, and preserves existing content if already present.
- **Verification:** Host configurations evaluate and build with activation script and configuration drop-in present.

### U5. Repository checks and VM test coverage

- **Goal:** Register standalone script check, materialized configuration check, and full NixOS VM test enforcing helper compliance and secret leakage absence.
- **Requirements:** R13, R14, R15; per KTD12.
- **Dependencies:** U1, U2, U3, U4.
- **Files:**
  - `flake.nix`
  - `tests/podman-containers.nix` (new)
  - `tests/podman-registry-auth.nix` (new)
- **Approach:**
  1. Register standalone unit test check in `flake.nix`: `checks.${system}.docker-credential-sops` running `tests/test_docker_credential_sops.py`.
  2. Create `tests/podman-containers.nix` to assert materialized configuration on both `ThinkPad-X1-Carbon-Gen-11` and `ThinkPad-X1-Carbon-Gen-11-bootstrap`:
     - `environment.systemPackages` contains `podman` and `docker-credential-sops` with executable binaries.
     - Rootful socket `systemd.sockets.podman.wantedBy` is empty on both hosts. This is the live assertion: removing the `mkForce` override turns it red.
     - Do not assert that `systemd.user.sockets.podman.wantedBy` contains `"sockets.target"`. The nixpkgs module sets it unconditionally, so no mutation of this repository's code can turn that assertion red and it would fold to a constant compared against itself. Record it as a precondition in prose instead.
     - `home.sessionVariables` and `systemd.user.sessionVariables` define `REGISTRY_AUTH_FILE` and `DOCKER_HOST`.
     - `home.activation.containersAuth` contains expected `credHelpers` mappings and no embedded tokens.
     - `xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".text` sets `unqualified-search-registries`.
     - Wrap store paths in `findFirst ... null` and `lib.optionalString` guards. Use explicit `if ...; then echo >&2; exit 1; fi` constructs.
  3. Create `tests/podman-registry-auth.nix` using `pkgs.testers.nixosTest`:
     - Multi-node setup: `missing` (bootstrap/no secrets) and `machine` (secrets present).
     - Fixture generated with `age-keygen` and `sops` containing DISTINCT fake tokens: `FAKE_ghcr_token`, `FAKE_gitlab_token`, `FAKE_jpi_token`, `FAKE_docker_token`.
     - Test script verifies helper returns correct token for each mapped registry on `machine`.
     - Test script verifies helper returns exact string `credentials not found in native keychain` with exit code 1 for unmapped registry (`quay.io`) on `machine`.
     - Test script verifies helper returns exact string `credentials not found in native keychain` with exit code 1 for all registries on `missing` node.
     - Offline login assertion: `podman login --get-login <registry>` succeeds on `machine` and fails on `missing`.
     - Journal check: assert none of the fake token strings appear in `journalctl`.
- **Patterns to follow:** `flake.nix:91-100` (`publish-cli-auth`) for standalone test runner; `flake.nix:116-129` and `tests/nix-ld.nix` for materialized configuration check; `tests/auth-provisioning.nix` for VM test and journal leak assertions.
- **Test scenarios:**
  - Covers AE1, AE2, AE3. Run VM test:
    - Node `machine` credential query for `registry.jpi.app` returns `FAKE_jpi_token`.
    - Node `machine` credential query for `quay.io` returns exact not-found string.
    - Node `missing` credential query for `ghcr.io` returns exact not-found string.
    - `podman login --get-login ghcr.io` succeeds on `machine`, fails on `missing`.
    - Journal logs on both nodes contain none of the fake token strings.
  - Standalone script check: `nix build --no-link .#checks.x86_64-linux.docker-credential-sops`.
  - Materialized config check: `nix build --no-link .#checks.x86_64-linux.podman-containers`.
  - Mutation testing: verify removal of helper or config alters materialized check to red inside builder.
- **Verification:** All new checks build green via `nix flake check`.

### U6. Documentation

- **Goal:** Document rootless Podman setup, registry authentication, developer prerequisites, and verification procedures.
- **Requirements:** R5, R11; per KTD8, KTD11.
- **Dependencies:** U5.
- **Files:**
  - `docs/provisioning.md`
  - `docs/verification.md`
- **Approach:**
  1. In `docs/provisioning.md`, add section "Container runtime and registry authentication":
     - Describe Rootless Podman and the SOPS-backed credential helper architecture.
     - Document developer prerequisite: issuing a Docker Hub PAT, adding `docker_token` and `docker_user` to `secrets/tokens.yaml`, and re-encrypting with SOPS.
     - Document checking token scopes for GitHub (`read:packages`) and GitLab (`read_registry`).
  2. In `docs/verification.md`:
     - Add descriptions for `docker-credential-sops`, `podman-containers`, and `podman-registry-auth` checks in the catalog paragraph matching their registration order in `flake.nix`.
     - Add hardware verification checklist items for pulling images from `ghcr.io`, `registry.gitlab.com`, `registry.jpi.app`, and `docker.io`.
- **Patterns to follow:** `docs/provisioning.md:100-109` for tool provisioning section; `docs/verification.md` for check catalog paragraph and hardware checklist.
- **Test scenarios:**
  - `Test expectation: none -- documentation only.`
- **Verification:** Documentation matches check registration order and accurately describes reproduction and prerequisite steps.

---

## Verification Contract

Run from the repository root, in this order:

| Gate | Command | Applies to |
|---|---|---|
| Formatting | `nix fmt -- --ci` | U1–U6 |
| Evaluation | `nix flake check --no-build` | U1–U5 |
| Standalone script check | `nix build --no-link .#checks.x86_64-linux.docker-credential-sops` | U2 |
| Materialized config check | `nix build --no-link .#checks.x86_64-linux.podman-containers` | U1, U3, U4 |
| VM test | `nix build --no-link .#checks.x86_64-linux.podman-registry-auth` | U1–U5 |
| All checks | `nix flake check` | U1–U5 |
| Production build | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1, U3, U4 |
| Bootstrap build | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1, U3, U4 |

What these prove:
- `docker-credential-sops` proves protocol compliance, exact not-found string equality, trailing newline stripping, and absent secret handling in isolation.
- `podman-containers` proves that rootless Podman, disabled rootful socket, helper package, environment variables, registries search drop-in, and `auth.json` activation logic materialize correctly on both production and bootstrap hosts.
- `podman-registry-auth` proves end-to-end credential retrieval, anonymous fallback, offline `podman login --get-login` verification, and absence of token leakage in journal logs.
- Host toplevel builds prove system evaluation and generation succeed on both production and bootstrap hosts without secret dependencies during build.

---

## Definition of Done

Global:

- Both `ThinkPad-X1-Carbon-Gen-11` and `ThinkPad-X1-Carbon-Gen-11-bootstrap` system toplevels build successfully.
- `nix flake check` passes with all existing and new checks green.
- `nix fmt -- --ci` reports no changes.
- The new materialized output check has been mutation-tested with failure origins verified from build logs.
- VM test passes with distinct tokens across registries and zero journal leaks.
- `docs/provisioning.md` and `docs/verification.md` are updated to reflect the new checks and developer prerequisites.
- No rootful socket is enabled, user `h82` is not in the `podman` group, `auth.json` contains no embedded secrets, and no Quadlet or prune timers are added.
- Any code written during abandoned exploration has been cleaned up and removed.

Per unit:

- U1 — `modules/nixos/podman.nix` declared, rootful socket disabled with `mkForce`, imported and enabled on both hosts.
- U2 — `scripts/docker-credential-sops` created, implements full protocol, standalone tests in `tests/test_docker_credential_sops.py` pass.
- U3 — routing table declared, helper derivation created and added to `environment.systemPackages` on both hosts.
- U4 — `home/h82/containers.nix` created and imported in `home/h82/default.nix` in alphabetical order, managing writable `auth.json`, search registries drop-in, and environment variables.
- U5 — checks registered in `flake.nix`, materialized check and VM test implemented and passing.
- U6 — both documentation files updated, check catalog order matching `flake.nix`.

