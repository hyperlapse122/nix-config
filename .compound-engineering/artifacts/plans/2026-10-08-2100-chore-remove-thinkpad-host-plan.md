---
title: Remove the ThinkPad Host - Plan
type: chore
date: 2026-10-08
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Remove the ThinkPad Host - Plan

## Goal Capsule

- **Objective:** The flake describes only the machines the user still runs: the MS-7D91 desktop and the MacBook-Pro-Mac17-9 daily driver. Nothing in the tree builds, tests, or documents the retired ThinkPad X1 Carbon Gen 11, and `.sops.yaml` no longer names its recipient. The encrypted files drop it when the user re-keys them after merge.
- **Means:** Delete the host and the four hardware traits only it enabled (KTD1, KTD2). Drop its recipient from `.sops.yaml` (KTD3).
- **Authority:** Product Contract R-IDs, then KTDs, then units.
- **Stop conditions:** Stop if a check still needs a configuration that enables a removed trait and cannot get coverage by KTD5. Stop if MS-7D91 or the macOS host stops evaluating. Stop if a step would need to decrypt a real secret.
- **Execution profile:** One branch, one PR. The agent implements and verifies locally, and CI builds the aarch64 and macOS outputs.

---

## Product Contract

### Summary

Remove `hosts/ThinkPad-X1-Carbon-Gen-11` and every artifact that exists only for it: bootstrap and SSH secrets, its `.sops.yaml` rules and recipient, and the `my.keyd`, `my.fingerprint`, `my.thunderbolt`, and `my.laptop` traits with their modules, Home Manager config, scripts, packages, checks, and docs.

### Problem Frame

The user replaced the ThinkPad with `MacBook-Pro-Mac17-9` as their daily driver. The ThinkPad still costs CI time on every change. It also keeps four hardware traits alive that no other host enables. Their checks use a `withTrait` guard that fails when no production configuration enables the trait, so the host cannot be removed alone.

### Key Decisions

- **Remove the ThinkPad host.** (session-settled: user-directed — chosen over keeping the host in the flake: MacBook-Pro-Mac17-9 replaced it as daily driver.) Governs R1, R2.
- **Remove the traits only the ThinkPad enabled, with their modules and checks.** (session-settled: user-directed — chosen over keeping the modules and changing `withTrait` to force a trait on when no host enables it: code no host uses is dead, and git history preserves it.) Governs R3, R4.

### Requirements

**Host and secrets**

- R1. `hosts/ThinkPad-X1-Carbon-Gen-11`, `secrets/bootstrap/ThinkPad-X1-Carbon-Gen-11`, and `secrets/hosts/ThinkPad-X1-Carbon-Gen-11` no longer exist, and `nixosConfigurations` lists only `MS-7D91` and `MS-7D91-bootstrap`.
- R2. The ThinkPad recipient `age12wg7w2uex5nc8tdrgynv3an9ywkmd937fmqunk9jldvtd65l9y8s87hmnv` no longer appears in `.sops.yaml`, and its per-host SSH rule is gone.

**Orphaned traits**

- R3. The options `my.keyd.*`, `my.fingerprint.enable`, `my.thunderbolt.enable`, and `my.laptop.enable` no longer exist, nor do the modules, Home Manager files, scripts, and packages that implement them.
- R4. The checks that guarded only those traits are gone, and every remaining check passes, including the guard checks (`host-name-guard`, `vm-checks-guard`, `check-shards-guard`, `bootstrap-recipients`).

**Documentation**

- R5. User-facing docs (`README.md`, `AGENTS.md`, `CONCEPTS.md`, `docs/`, `secrets/README.md`) describe no ThinkPad host and no removed trait. Historical artifacts under `.compound-engineering/artifacts/` stay unchanged.

### Scope Boundaries

- Plans and solutions under `.compound-engineering/artifacts/` are history and stay. `AGENTS.md` keeps its links to them, including the ThinkPad EFI-variables solution: its efivarfs lesson applies to any firmware.
- Re-encrypting `secrets/tokens.yaml`, `secrets/wifi.yaml`, and `secrets/tailscale.yaml` without the ThinkPad recipient (`sops updatekeys`, then `sops rotate`) needs a real decrypting identity, which an agent must never use. That step is for the user after merge (see Documentation / Operational Notes).
- `my.nuphyGem80`, the MS-7D91 keyboard trait, stays. So do the generic udev and iPhone restore modules, which other hosts use.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Delete the trait code outright instead of adding test-only scaffolding.** `tests/lib/configurations.nix` `withTrait` fails a check when no production configuration enables the trait. With the ThinkPad gone that holds for keyd, fingerprint, thunderbolt, and laptop, so their checks go with their modules. This instantiates the second Key Decision (R3, R4).
- KTD2. **Remove the laptop trait from the non-NixOS fixture too.** `tests/fixtures/hosts/hollyhock/default.nix` sets `my.laptop.enable = true`, and `tests/non-nixos-outputs.nix` asserts that the laptop trait brings no desktop config to a non-NixOS host and requires a fixture that enables it. With the option gone, these go: hollyhock's laptop line and its comment, the `kdePowerLid` absence check, the `laptopFixtures` guard, and the laptop clause in the check's header. The account override that hollyhock exists for stays. The GUI-package and desktop-file absence assertions stay as plain absence checks. No fixture asks for anything desktop-shaped any more, which is accepted. (R3)
- KTD3. **Edit `.sops.yaml` only, not the encrypted files.** `bootstrap-recipients` pairs `hosts/` with `secrets/bootstrap/` and checks that each live recipient appears in `.sops.yaml`. `linux-host-secrets` reads file recipients only for non-NixOS hosts. Neither fails on a stale extra recipient inside an encrypted file. The files keep the ThinkPad stanza until the user runs `sops updatekeys` (R2).
- KTD4. **Find the trait footprint by search, not by this plan's file list.** The units name the known files, but the implementer re-greps (`keyd`, `fingerprint`, `fprintd`, `thunderbolt`, `bolt`, `laptop`, `lid`, `copilotKey`, `kdePowerLid`, `ThinkPad`) outside `.compound-engineering/` after each unit. Unrelated hits stay: GPG `with-fingerprint`, the SSH key `fingerprint()` in `scripts/desktop-ssh`, and SSH fingerprints in `secrets/README.md`.
- KTD5. **Keep both branches covered in checks that assumed a second NixOS host.** With MS-7D91 the only NixOS host, a check that guards both sides of a hardware split loses one side. Known case: `tests/boot-splash.nix` fails when every production configuration uses NVIDIA, and the Intel ThinkPad was the only one that did not. Do not drop the guard. Follow the `withTraitForcedOff` pattern in `tests/lib/configurations.nix`: when no production configuration takes the missing branch, re-evaluate a production configuration with `extendModules` so it does, and run that branch's assertions on the variant. For boot-splash the variant forces `services.xserver.videoDrivers` to `[ "modesetting" ]` and `hardware.nvidia.modesetting.enable` to false, and adds a KMS driver to `boot.initrd.kernelModules`. Any other check that `nix flake check` shows failing for the same reason gets the same treatment. (R4)

### Assumptions

- `MS-7D91` and the macOS host enable none of the removed traits. `hosts/MS-7D91/default.nix` only mentions keyd in a comment, which goes with the trait.
- `tests/check-shards.nix` assigns checks to shards without naming them, so removing a check needs no shard edit. If it does list them, U3 removes the entries.

### Sequencing

U1 deletes the host. U2 and U3 remove the trait code and its checks together, because a module without its check, or a check without its module, fails evaluation. U4 updates the docs. U5 verifies everything.

---

## Implementation Units

### U1. Remove the host and its secrets

- **Goal:** R1, R2.
- **Files:** delete `hosts/ThinkPad-X1-Carbon-Gen-11/`, `secrets/bootstrap/ThinkPad-X1-Carbon-Gen-11/`, and `secrets/hosts/ThinkPad-X1-Carbon-Gen-11/`. Edit `.sops.yaml`.
- **Approach:** In `.sops.yaml`, remove the `secrets/hosts/ThinkPad-X1-Carbon-Gen-11/ssh\.yaml$` rule, and remove the ThinkPad recipient from the `tokens`, `wifi`, and `tailscale` rules. Leave the encrypted files as they are (KTD3).
- **Test scenarios:** `bootstrap-recipients` passes with two paired hosts. `nix eval .#nixosConfigurations --apply builtins.attrNames` lists only the MS-7D91 pair. `check_desktop_ssh_config.py` (in the `desktop-ssh` check) still finds a headed host and passes.
- **Verification:** `rg -n 'ThinkPad|age12wg7w2uex5' --glob '!.compound-engineering/**'` returns only these: docs that U4 handles, comments that U2 and U3 handle, and the recipient stanzas in `secrets/tokens.yaml`, `secrets/wifi.yaml`, and `secrets/tailscale.yaml`, which wait for the post-merge re-key (KTD3).

### U2. Remove the trait modules, options, and Home Manager config

- **Goal:** R3.
- **Files:** delete `modules/nixos/hardware/keyd.nix`, `fingerprint.nix`, `thunderbolt.nix`, `laptop.nix`, `home/h82/desktop/kde/power-lid.nix`, `scripts/enroll-fingerprint`, and `packages/enroll-fingerprint.nix`. Edit `modules/nixos/profile.nix` (imports), `modules/shared/host.nix` (four options), `home/h82/desktop/kde/default.nix` (import), `hosts/MS-7D91/default.nix` (the keyd comment), `tests/fixtures/hosts/hollyhock/default.nix` (KTD2), and wherever `packages/enroll-fingerprint.nix` is wired into the flake or the modules.
- **Approach:** Delete the modules, then remove each reference the search finds (KTD4). `lib/host-facts.nix` derives its paths from `modules/shared/host.nix`, so it needs only a comment touch if its example names a removed option.
- **Test scenarios:** `host-options` and `darwin-config` still evaluate. The MS-7D91 toplevel and the hollyhock/juniper Home Manager outputs still evaluate.
- **Verification:** Done together with U3, since evaluation fails until the checks that read the removed options are gone.

### U3. Remove the trait checks

- **Goal:** R4.
- **Files:** delete `tests/keyd-remap.nix`, `tests/logind-lid-switch.nix`, `tests/pam-fingerprint.nix`, `tests/thunderbolt.nix`, and `tests/enroll-fingerprint.sh`. Edit `flake.nix` (the `keyd-remap`, `thunderbolt`, `pam-fingerprint`, `enroll-fingerprint`, and lid-switch registrations, their `hostClosureChecks` entries, and the `enroll-fingerprint-tests` derivation), `tests/vm-checks.nix` if it registers any of them, `tests/non-nixos-outputs.nix` and the hollyhock fixture (KTD2), `tests/boot-splash.nix` (KTD5), the `my.keyd.enable` example in the `tests/lib/configurations.nix` header comment (switch it to a live trait such as `my.printing.enable`), and the "the ThinkPad's" example in the `tests/host-name-guard.nix` header comment (reword it to a generic host).
- **Approach:** Remove the registrations and their files. A check that also asserted something unrelated to the traits keeps that part. Read each check before deleting it. Then apply KTD5 to every check that fails only because one NixOS host is left.
- **Test scenarios:** `vm-checks-guard` and `check-shards-guard` pass with the shorter lists. `boot-splash` passes with only the MS-7D91 pair, and its non-NVIDIA assertions run on the forced variant. Mutation check for that variant: make the variant load `nvidia` in its initrd, and `boot-splash` must fail. `nix flake check --no-build` evaluates cleanly.
- **Verification:** `nix flake check` passes. The KTD4 search finds no live reference.

### U4. Update the documentation

- **Goal:** R5.
- **Files:** `README.md` (host table row), `AGENTS.md` (first project-structure paragraph and the trait list naming `my.keyd`, `my.fingerprint`, `my.thunderbolt`, `my.laptop`, plus the `modules/nixos/` hardware summary), `CONCEPTS.md` (the "physical laptop" hardware-check wording and the trait examples), `docs/install.md` (the ThinkPad section), `docs/verification.md` (the ThinkPad section, the trait hardware checks, and the "even with the laptop trait" clause in the `non-nixos-outputs` line), `docs/provisioning.md`, `docs/recovery.md`, and `docs/adding-a-host.md` (fingerprint, keyd, Thunderbolt, and lid passages). Check `secrets/README.md` for host-specific text.
- **Approach:** Delete the ThinkPad-only passages. Reword generic ones so they name traits that still exist (`my.nuphyGem80`, `my.printing`, `my.tailscale.advertiseRoutes`). Write through `ce-noslop`. Keep exact commands and link targets.
- **Test scenarios:** Docs-only, none.
- **Verification:** `rg -n 'ThinkPad|X1 Carbon|keyd|fingerprint|thunderbolt|[Ll]aptop' README.md AGENTS.md CONCEPTS.md docs secrets/README.md` returns only the AGENTS.md link to the EFI solution and unrelated hits (KTD4).

### U5. Verify the fleet

- **Goal:** R1 through R4.
- **Files:** none.
- **Approach:** Run the Verification Contract.
- **Verification:** Every command in the Verification Contract succeeds.

---

## Verification Contract

| Command | Proves |
|---|---|
| `nix fmt -- --ci` | formatting |
| `nix flake check` | every declared check, including the guard checks and the x86_64 fixtures (R4) |
| `nix build --no-link .#vmChecks.all` | the remaining NixOS VM tests (needs `/dev/kvm`) |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` and `...MS-7D91-bootstrap...` | the desktop still builds (R1) |
| `nix eval .#nixosConfigurations --apply builtins.attrNames` | only the MS-7D91 pair remains (R1) |
| `nix eval .#darwinConfigurations --apply builtins.attrNames` | the macOS host still evaluates. CI's `build-darwin` job builds it. |

`homeConfigurations` and `systemConfigs` stay empty, because `hosts/` holds no non-NixOS host.

---

## Definition of Done

- R1 through R5 hold, and every Verification Contract command passes.
- The KTD4 search finds no live reference to the host or the removed traits outside `.compound-engineering/`.
- No half-removed module, dangling import, or commented-out code remains.

---

## Documentation / Operational Notes

After merge, the user re-keys the shared secrets on a machine that holds a decrypting identity. This follows the order in [compromise or decommission of a non-NixOS host](../../../docs/provisioning.md#compromise-or-decommission-of-a-non-nixos-host), which applies to a retired NixOS host the same way:

```sh
for f in secrets/tokens.yaml secrets/wifi.yaml secrets/tailscale.yaml; do
  sops updatekeys -y "$f"
  sops rotate -i "$f"
done
```

`updatekeys` alone keeps the old data key, which the ThinkPad identity can read from any earlier ciphertext in git history. `sops rotate` replaces it. Write any new token, Wi-Fi, or Tailscale value only after the rotate. The ThinkPad identity can still decrypt the old values, so if the laptop leaves the user's hands, rotate those values at their services too.

Retire the ThinkPad itself before it is wiped or leaves the user's hands:

1. On the ThinkPad, run `fprintd-delete "$USER"` and confirm with `fprintd-list`. The templates live in the sensor's flash and survive a disk wipe.
2. Revoke the SSH public key from `secrets/hosts/ThinkPad-X1-Carbon-Gen-11/ssh.pub` on GitHub and remove it from every server's `authorized_keys`. Deleting the file revokes nothing.
3. Remove the ThinkPad node from the tailnet in the Tailscale admin console.
