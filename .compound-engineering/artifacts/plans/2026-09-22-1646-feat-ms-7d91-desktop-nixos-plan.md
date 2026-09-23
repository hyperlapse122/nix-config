---
title: MS-7D91 Desktop NixOS Host Migration - Plan
type: feat
date: 2026-09-22
topic: ms-7d91-desktop-nixos
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# MS-7D91 Desktop NixOS Host Migration - Plan

## Goal Capsule

- **Objective:** Manage the MS-7D91 desktop workstation (Intel i7-13700F, NVIDIA GeForce RTX 3060, Samsung 980 PRO 1TB NVMe) in this repository's Nix flake, enforcing the same security baseline (Lanzaboote Secure Boot, TPM2-backed LUKS auto-unlock) and shared user environment (`home/h82`, KDE Plasma 6) as the existing ThinkPad X1 Carbon Gen 11.
- **Product Authority:** `h82` (Joosung Park).
- **Means:** Multi-host flake refactoring, dedicated `hosts/MS-7D91/` host definitions, pre-installation age identity provisioning via YubiKey, multi-recipient SOPS re-encryption for `secrets/tokens.yaml`, 1TB NVMe Disko configuration with 2TB secondary exFAT HDD auto-mount at `/mnt/data`, NVIDIA proprietary driver integration with Wayland and CUDA/Podman CDI support, and disabling `keyd` on desktop to preserve NuPhy Gem80 custom firmware key mappings.
- **Open Blockers:** None.

---

## Product Contract

### Summary

Introduce declarative NixOS support for the `MS-7D91` desktop workstation alongside `ThinkPad-X1-Carbon-Gen-11`. The host shares the established security architecture (Lanzaboote Secure Boot, TPM2-bound LUKS decryption), shared user environment, and secret workflows while introducing desktop-specific hardware support: proprietary NVIDIA graphics, CUDA and Podman container acceleration, 1TB NVMe system partitioning, non-destructive 2TB secondary storage auto-mounting at `/mnt/data`, and per-host age identity bootstrap material.

### Problem Frame

The repository currently defines and manages a single host, `ThinkPad-X1-Carbon-Gen-11`. Host configuration is tightly coupled in `modules/nixos/base.nix` (hardcoded `networking.hostName`) and `flake.nix` (single-host `mkHost` abstraction).

The developer's primary desktop workstation (`MS-7D91`) is currently running Fedora 44 with an Intel Core i7-13700F (which has no integrated GPU), an NVIDIA GeForce RTX 3060, a 1TB Samsung 980 PRO NVMe SSD, and a secondary 2TB Seagate HDD formatted as exFAT. To maintain a unified declarative environment, this desktop must be migrated to NixOS under the same repository with identical security guarantees (Secure Boot and TPM2 disk encryption). Because erasing the operating system discards the existing environment, the host's bootstrap age identity and re-encrypted secret tokens must be prepared from the running system prior to disk repartitioning.

### Key Decisions

- **Host naming convention**: **`MS-7D91`** (session-settled: user-directed — chosen over `desktop`: derived directly from `dmidecode -s system-product-name`). Governs R1, R2.
- **Pre-installation identity generation in scope**: **Generate bootstrap age identity and re-encrypt tokens as an explicit phase of the plan** (session-settled: user-directed — chosen over out-of-band manual prerequisite: guarantees secret decryptability before erasing Fedora). Governs R4, R5.
- **Storage partitioning strategy**: **Disko partitions 1TB NVMe SSD; secondary 2TB HDD preserved as exFAT and auto-mounted at `/mnt/data`** (session-settled: user-directed — chosen over formatting both disks or leaving secondary disk unmanaged: isolates OS/root storage while making secondary media accessible). Governs R9, R10.
- **GPU and compute capabilities**: **Proprietary NVIDIA drivers, Wayland display acceleration, CUDA toolkit libraries, and Podman CDI container passthrough** (session-settled: user-directed — chosen over basic display-only graphics: supports containerized AI/workstation workloads on desktop). Governs R6, R7, R8.
- **Keyboard input remapping**: **Disable keyd on MS-7D91** (session-settled: user-directed — chosen over remapping external keyboard: preserves NuPhy Gem80 QMK/VIA firmware settings and stock keyboard behavior). Governs R11.
- **Multi-host flake architecture**: **Refactor `mkHost` in `flake.nix` to accept host parameters and decouple `networking.hostName` from `base.nix`** (session-settled: user-approved — chosen over duplicating flake modules: keeps common configuration DRY across laptop and desktop). Governs R1, R3.

### Requirements

#### Host Identity and Flake Architecture

- R1. The flake must export `nixosConfigurations.MS-7D91` (production) and `nixosConfigurations.MS-7D91-bootstrap` (bootstrap without private boot keys or secrets), in addition to the existing ThinkPad targets.
- R2. `networking.hostName` must evaluate to `MS-7D91` on the desktop host and remain `ThinkPad-X1-Carbon-Gen-11` on the laptop, decoupled from `modules/nixos/base.nix`.
- R3. Rebuild helper `scripts/nr` must resolve `MS-7D91` automatically via `uname -n` and accept `--host MS-7D91`.

#### Bootstrap and Secret Provisioning

- R4. Dedicated bootstrap age material must be generated under `secrets/bootstrap/MS-7D91/` (`age-key.asc` and `recipient.txt`) using the active YubiKey encryption subkey before erasing the existing OS.
- R5. `.sops.yaml` creation rules must include both `ThinkPad-X1-Carbon-Gen-11` and `MS-7D91` public age recipients for `secrets/tokens.yaml`, and `secrets/tokens.yaml` must be re-encrypted to allow decryption on both hosts.
- R6. `modules/nixos/secrets.nix` must continue decrypting tokens to `/run/secrets/cli-auth` and running `publish-cli-auth` on both hosts without changes to the secret format.

#### Hardware and Graphics Acceleration

- R7. `hosts/MS-7D91/hardware.nix` must declare CPU microcode updates (`hardware.cpu.intel.updateMicrocode = true`), initial ramdisk kernel modules for NVMe/SATA/USB, and kvm modules (`boot.kernelModules = [ "kvm-intel" ]`).
- R8. `hosts/MS-7D91/` must configure the proprietary NVIDIA driver (`services.xserver.videoDrivers = [ "nvidia" ]`), Wayland modesetting (`hardware.nvidia.modesetting.enable = true`), and graphics acceleration (`hardware.graphics.enable = true`).
- R9. CUDA libraries and NVIDIA container toolkit (CDI) integration must be configured for rootless Podman so containers can access the RTX 3060 GPU.

#### Storage and File Systems

- R10. `hosts/MS-7D91/disko.nix` must target the internal 1TB NVMe SSD by ID (`/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNF0WB26038A`), creating a 2GB ESP (`/boot`) and a LUKS2 partition labeled `disk-main-luks` containing Btrfs subvolumes (`/`, `/home`, `/nix`, `/var/log`, `/swap` with 64GB swapfile).
- R11. The secondary 2TB HDD (`/dev/disk/by-id/ata-ST2000DM008-2UB102_ZK30PHAD-part1`, UUID `FBDF-76E4`, filesystem `exfat`) must be declared as an auto-mounted filesystem at `/mnt/data` with `nofail` and user access ownership (`uid=1000`, `gid=100`).

#### User Environment and Peripherals

- R12. The `keyd` service must be disabled on `MS-7D91` so that the NuPhy Gem80 external keyboard operates according to its on-board firmware without virtual keyboard intervention.
- R13. The desktop host must import the shared Home Manager profile (`home/h82/`), provisioning the KDE Plasma 6 desktop, Ghostty terminal, 1Password integration, zsh configuration, and coding agent tooling identically to the laptop.

#### Verification and Tooling

- R14. Flake checks in `flake.nix` must continue to pass, and CI build verification (`.github/workflows/check.yml`) must build the toplevel systems for both hosts: `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, and `MS-7D91-bootstrap`.
- R15. Documentation in `docs/` (`install.md`, `provisioning.md`, `recovery.md`, `README.md`) must be updated to cover `MS-7D91` installation targets, disk identifiers, and multi-host recovery commands.

### Key Flows

- F1. **Pre-Migration Identity and Secret Provisioning**
  - **Trigger:** Developer prepares to migrate `MS-7D91` while Fedora is still running.
  - **Actors:** Developer (`h82`), YubiKey, local nix shell.
  - **Steps:**
    1. Run `./scripts/prepare-age-identity --host MS-7D91 --recipient <YubiKey-Fingerprint>` to create `secrets/bootstrap/MS-7D91/`.
    2. Add the derived recipient to `.sops.yaml` alongside ThinkPad's recipient.
    3. Re-encrypt `secrets/tokens.yaml` using `sops --encrypt --age <recipients> ...`.
    4. Commit and push the bootstrap material and updated encrypted tokens to git.
  - **Covered by:** R4, R5, R6.

- F2. **Bootstrap Installation via NixOS Installer USB**
  - **Trigger:** Developer boots NixOS installation media on `MS-7D91`.
  - **Actors:** Developer, Disko, `nixos-install`.
  - **Steps:**
    1. Clone repository on live media.
    2. Partition Samsung 980 PRO using `disko --mode disko hosts/MS-7D91/disko.nix` (secondary HDD remains untouched).
    3. Install bootstrap system: `nixos-install --flake .#MS-7D91-bootstrap --no-root-passwd`.
    4. Reboot into newly installed bootstrap system.
  - **Covered by:** R1, R10, R11.

- F3. **First Boot, Identity Recovery, and Secure Boot Enrollment**
  - **Trigger:** Initial boot of `MS-7D91-bootstrap` on bare metal.
  - **Actors:** Developer, YubiKey, `sbctl`, `recover-age-identity`, `nr`.
  - **Steps:**
    1. Log in as user `h82`.
    2. Run `./scripts/recover-age-identity --host MS-7D91` with YubiKey plugged in to install `/var/lib/sops-nix/key.txt`.
    3. Enroll Secure Boot keys using `sbctl create-keys` and `sbctl enroll-keys --microsoft`.
    4. Bind LUKS key to TPM2: `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-main-luks`.
    5. Switch to production configuration: `sudo nr switch --host MS-7D91`.
    6. Verify CLI authentication, NVIDIA graphics, and Lanzaboote boot signing.
  - **Covered by:** R1, R2, R3, R6, R8.

### Acceptance Examples

- AE1. **Multi-host Flake Evaluation and Build**
  - **Covers:** R1, R2, R14.
  - **Given:** The flake is evaluated on an x86_64-linux machine.
  - **When:** Running `nix eval .#nixosConfigurations.MS-7D91.config.networking.hostName` and `nix eval .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.networking.hostName`.
  - **Then:** The first returns `"MS-7D91"` and the second returns `"ThinkPad-X1-Carbon-Gen-11"`. Both system toplevels build without evaluation error.

- AE2. **Secondary Disk Mount Safety**
  - **Covers:** R10, R11.
  - **Given:** Disko format execution during initial provisioning on `MS-7D91`.
  - **When:** Disko executes formatting actions.
  - **Then:** Only `/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNF0WB26038A` is partitioned. The secondary drive `/dev/disk/by-id/ata-ST2000DM008-2UB102_ZK30PHAD` (`sda1`) is mounted under `/mnt/data` with permissions granted to UID 1000 without formatting. If the secondary drive is unplugged, boot succeeds without blocking due to `nofail`.

- AE3. **SOPS Multi-Host Decryption**
  - **Covers:** R5, R6.
  - **Given:** `secrets/tokens.yaml` encrypted with both recipients.
  - **When:** `sops --decrypt` is run on either `ThinkPad-X1-Carbon-Gen-11` or `MS-7D91` with their respective local age identities.
  - **Then:** Decryption succeeds on both hosts and yields identical plaintext tokens without modifying the SOPS service unit definitions.

- AE4. **NuPhy Keyboard Bypass**
  - **Covers:** R12.
  - **Given:** `MS-7D91` desktop system booted.
  - **When:** Key presses are sent from the connected NuPhy Gem80 external keyboard.
  - **Then:** `services.keyd.enable` is false on `MS-7D91`, and keystrokes pass directly to evdev/Wayland without remapping CapsLock.

### Scope Boundaries

#### In Scope

- Creation of `hosts/MS-7D91/` (`default.nix`, `hardware.nix`, `disko.nix`).
- Flake architecture refactoring to parameterize `mkHost` and support multiple targets (`ThinkPad-X1-Carbon-Gen-11` and `MS-7D91`).
- Generating `secrets/bootstrap/MS-7D91/` age identity on the live Fedora system using `./scripts/prepare-age-identity`.
- Updating `.sops.yaml` and re-encrypting `secrets/tokens.yaml` for dual-host access.
- NVIDIA proprietary driver, Wayland support, and Podman GPU container passthrough (CDI).
- Auto-mounting 2TB HDD (`sda1`, exFAT) at `/mnt/data` with `nofail` and user permissions.
- Updating rebuild script `scripts/nr` and test suites to accommodate both hosts.
- Updating documentation in `docs/` and `README.md`.

#### Out of Scope / Deferred

- Formatting, resizing, or repartitioning the secondary 2TB Seagate HDD.
- Adding laptop-specific features (battery conservation, thermal throttling profiles, Copilot key chord) to the desktop host.
- Modifying the existing user account structure or creating multi-user configurations.

### Dependencies / Assumptions

- The active YubiKey carries the encryption subkey corresponding to `keys/signing.asc` (`621512777E6933FEB4458FDC4945855D4F283F05`).
- The internal SSD remains at `/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNF0WB26038A`.
- The motherboard UEFI firmware supports TPM2 and Secure Boot custom key enrollment (`sbctl`).
- The proprietary NVIDIA kernel modules build cleanly against `pkgs.linuxPackages_latest` used by `modules/nixos/boot.nix`.

### Sources / Research

- `flake.nix`: Current `mkHost` implementation hardcoding `ThinkPad-X1-Carbon-Gen-11`.
- `modules/nixos/base.nix`: Hardcoded `networking.hostName`.
- `modules/nixos/boot.nix`: Lanzaboote and TPM2 LUKS auto-unlock (`tpm2-device=auto`, `tpm2-pcrs=7`).
- `secrets/README.md` and `docs/provisioning.md`: Detailed protocol for multi-host age identity provisioning and `.sops.yaml` re-encryption.
- `scripts/nr`: Rebuild helper targeting `uname -n` or `--host`.
- Hardware scan: Intel i7-13700F, NVIDIA GeForce RTX 3060 (GA104), Samsung SSD 980 PRO 1TB NVMe, Seagate Barracuda 2TB HDD (exFAT UUID `FBDF-76E4`), NuPhy Gem80 keyboard.

---

## Planning Contract

### Key Technical Decisions

- **KTD1. Parameterized Flake Host Builder**: Parameterize `mkHost` in `flake.nix` with `{ hostModule, bootstrap }`, and set `networking.hostName` within the host's own module (`hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` and `hosts/MS-7D91/default.nix`). (session-settled: user-approved — chosen over separate builders: keeps shared inputs, home-manager instantiation, and module lists unified). Governs R1, R2.
- **KTD2. Dual-Recipient SOPS Provisioning**: Add the new `MS-7D91` recipient (`age1...`) to `.sops.yaml` under `secrets/tokens.yaml$` alongside the existing `ThinkPad-X1-Carbon-Gen-11` recipient and re-encrypt the file using `sops --encrypt`. (session-settled: user-directed — chosen over separate per-host token files: allows single credential source to be decrypted by either machine with local age keys). Governs R4, R5, R6.
- **KTD3. Desktop Hardware and Graphics Configuration**: In `hosts/MS-7D91/hardware.nix`, configure `services.xserver.videoDrivers = [ "nvidia" ]`, `hardware.graphics.enable = true`, `hardware.nvidia.modesetting.enable = true`, `hardware.nvidia.powerManagement.enable = false`, `hardware.nvidia.open = false`, and enable NVIDIA Container Toolkit (`hardware.nvidia-container-toolkit.enable = true`) for rootless Podman CDI passthrough. (session-settled: user-directed — chosen over open-source nouveau or CPU rendering: satisfies display requirements of the i7-13700F without integrated graphics). Governs R7, R8, R9.
- **KTD4. Disko Single-Disk Partitioning with Fstab Secondary Mount**: `hosts/MS-7D91/disko.nix` declares only the 1TB NVMe disk (`/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNF0WB26038A`), generating the exact same layout as ThinkPad (2GB ESP, LUKS partition `disk-main-luks`, Btrfs subvolumes `/root`, `/home`, `/nix`, `/var/log`, `/swap`). The 2TB HDD (`sda1`) is mounted as a standard filesystem in `hosts/MS-7D91/default.nix` via `fileSystems."/mnt/data" = { device = "/dev/disk/by-id/ata-ST2000DM008-2UB102_ZK30PHAD-part1"; fsType = "exfat"; options = [ "nofail" "uid=1000" "gid=100" "dmask=0022" "fmask=0133" ]; };`. (session-settled: user-directed — chosen over managing secondary drive with Disko: prevents accidental wipe during initial disko partitioning). Governs R10, R11.
- **KTD5. Keyd Omission on Desktop**: `hosts/MS-7D91/default.nix` omits `../../modules/nixos/keyd.nix` entirely. (session-settled: user-directed — chosen over configuring keyd rules for external keyboards: preserves NuPhy Gem80 QMK/VIA firmware settings without input interception). Governs R12.

### Technical Architecture

```text
flake.nix
├── outputs.nixosConfigurations
│   ├── ThinkPad-X1-Carbon-Gen-11          (hosts/ThinkPad-X1-Carbon-Gen-11, bootstrap=false)
│   ├── ThinkPad-X1-Carbon-Gen-11-bootstrap(hosts/ThinkPad-X1-Carbon-Gen-11, bootstrap=true)
│   ├── MS-7D91                            (hosts/MS-7D91, bootstrap=false)
│   └── MS-7D91-bootstrap                  (hosts/MS-7D91, bootstrap=true)
│
modules/nixos/
├── base.nix (system locale, users.users.h82, nix settings - hostName decoupled)
├── boot.nix (Lanzaboote, systemd-boot, TPM2 LUKS autounlock on /dev/disk/by-partlabel/disk-main-luks)
├── desktop.nix (KDE Plasma 6, SDDM Wayland, 1Password GUI, Fcitx5 Hangul)
├── secrets.nix (SOPS /var/lib/sops-nix/key.txt, /run/secrets/cli-auth, publish-cli-auth)
└── podman.nix (rootless podman, docker alias, registry auth)
│
hosts/
├── ThinkPad-X1-Carbon-Gen-11/
│   ├── default.nix (networking.hostName = "ThinkPad-X1-Carbon-Gen-11", keyd enabled)
│   ├── hardware.nix (Intel Iris Xe graphics, microcode, bluetooth)
│   └── disko.nix (KIOXIA 512GB NVMe layout)
└── MS-7D91/
    ├── default.nix (networking.hostName = "MS-7D91", fileSystems."/mnt/data", no keyd)
    ├── hardware.nix (NVIDIA RTX 3060, nvidia-container-toolkit, microcode)
    └── disko.nix (Samsung 980 PRO 1TB NVMe layout)
```

### Implementation Constraints

- **Never wipe or format developer disks during evaluation or testing**: Disko formatting and `systemd-cryptenroll` must only run on target hardware during explicit installation runbooks (`docs/install.md`).
- **Never store plaintext secrets in git or the Nix store**: `secrets/bootstrap/MS-7D91/age-key.asc` must be encrypted to the YubiKey subkey before commit.
- **Maintain backward compatibility for ThinkPad**: All existing flake checks (`checks.x86_64-linux.*`) and toplevel builds for `ThinkPad-X1-Carbon-Gen-11` must continue to pass without regression.

### Sequencing and Dependencies

1. **U1 (Decouple Hostname & Parameterize Flake)**: Foundation for multi-host exports.
2. **U2 (Live Age Identity & SOPS Provisioning)**: Can be run on live Fedora immediately with the connected YubiKey.
3. **U3 (MS-7D91 Host Modules)**: Implements desktop hardware, disko, and graphics configurations.
4. **U4 (Flake Integration, CI & Checks)**: Connects the new host to flake outputs, CI workflow, and rebuild tests.
5. **U5 (Documentation & Runbooks)**: Updates guides for physical installation, recovery, and rebuilds.

---

## Implementation Units

### U1. Decouple Hostname and Parameterize Flake Host Builder

- **Goal:** Allow different hosts to set their own `networking.hostName` while unifying `nixpkgs.lib.nixosSystem` instantiation in `flake.nix`.
- **Requirements:** R1, R2.
- **Files:**
  - `modules/nixos/base.nix`
  - `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`
  - `flake.nix`
- **Approach:**
  1. In `modules/nixos/base.nix`, remove the hardcoded `networking.hostName = "ThinkPad-X1-Carbon-Gen-11";`.
  2. In `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`, set `networking.hostName = "ThinkPad-X1-Carbon-Gen-11";`.
  3. In `flake.nix`, update `mkHost` function signature to accept `{ hostModule, bootstrap }` and inherit shared modules (disko, home-manager, sops, lanzaboote).
- **Test Scenarios:**
  - Verify `nix eval .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.networking.hostName` returns `"ThinkPad-X1-Carbon-Gen-11"`.
  - Verify `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` succeeds.

### U2. Provision MS-7D91 Age Identity and Re-encrypt SOPS Tokens

- **Goal:** Create the bootstrap age identity for `MS-7D91` from the running Fedora machine using the plugged-in YubiKey, configure `.sops.yaml`, and re-encrypt `secrets/tokens.yaml` for both recipients.
- **Requirements:** R4, R5, R6.
- **Files:**
  - `secrets/bootstrap/MS-7D91/age-key.asc`
  - `secrets/bootstrap/MS-7D91/recipient.txt`
  - `.sops.yaml`
  - `secrets/tokens.yaml`
- **Approach:**
  1. Run `./scripts/prepare-age-identity --host MS-7D91 --recipient 621512777E6933FEB4458FDC4945855D4F283F05`.
  2. Update `.sops.yaml` so `creation_rules[0].age` lists both recipients separated by comma.
  3. Re-encrypt `secrets/tokens.yaml` with both recipients using `sops --encrypt`.
  4. Test that `sops -d secrets/tokens.yaml` decrypts successfully.
- **Test Scenarios:**
  - Verify `secrets/bootstrap/MS-7D91/recipient.txt` matches the age public recipient derived from `age-key.asc`.
  - Verify `sops -d secrets/tokens.yaml` decrypts without error.

### U3. Implement Dedicated MS-7D91 Host Modules

- **Goal:** Create the hardware, disk layout, and host module for `MS-7D91` supporting NVIDIA RTX 3060 graphics, CUDA, Podman CDI, 1TB NVMe Disko partition, and secondary 2TB exFAT HDD auto-mount at `/mnt/data`.
- **Requirements:** R7, R8, R9, R10, R11, R12, R13.
- **Files:**
  - `hosts/MS-7D91/default.nix`
  - `hosts/MS-7D91/hardware.nix`
  - `hosts/MS-7D91/disko.nix`
- **Approach:**
  1. Create `hosts/MS-7D91/disko.nix` matching `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` but with `device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNF0WB26038A";`.
  2. Create `hosts/MS-7D91/hardware.nix` declaring Intel CPU microcode, kernel modules (`xhci_pci`, `ahci`, `nvme`, `usbhid`, `usb_storage`, `sd_mod`, `kvm-intel`), `hardware.graphics.enable = true`, `services.xserver.videoDrivers = [ "nvidia" ]`, `hardware.nvidia = { modesetting.enable = true; open = false; powerManagement.enable = false; }`, and `hardware.nvidia-container-toolkit.enable = true`.
  3. Create `hosts/MS-7D91/default.nix` importing `./hardware.nix`, `./disko.nix`, shared modules (`base.nix`, `boot.nix`, `desktop.nix`, `fonts.nix`, `nix-ld.nix`, `podman.nix`, `secrets.nix`, `yubikey.nix`), setting `networking.hostName = "MS-7D91";`, adding `fileSystems."/mnt/data"`, and declaring `options.my.bootstrap`.
- **Test Scenarios:**
  - Verify `nix eval .#nixosConfigurations.MS-7D91.config.services.xserver.videoDrivers` contains `[ "nvidia" ]`.
  - Verify `nix eval .#nixosConfigurations.MS-7D91.config.fileSystems."/mnt/data".device` matches `/dev/disk/by-id/ata-ST2000DM008-2UB102_ZK30PHAD-part1`.
  - Verify `services.keyd.enable` is false on `MS-7D91`.

### U4. Wire Flake Configurations, Flake Checks, and CI Pipeline

- **Goal:** Expose `MS-7D91` and `MS-7D91-bootstrap` in `flake.nix`, ensure `scripts/nr` rebuild helper recognizes the host, and update CI checks.
- **Requirements:** R1, R3, R14.
- **Files:**
  - `flake.nix`
  - `scripts/nr`
  - `.github/workflows/check.yml`
  - `tests/nixos-rebuild-helper.nix`
- **Approach:**
  1. Add `MS-7D91` and `MS-7D91-bootstrap` to `nixosConfigurations` in `flake.nix`.
  2. Update `tests/nixos-rebuild-helper.nix` to assert `--host MS-7D91` resolves appropriately.
  3. Update `.github/workflows/check.yml` matrix / build steps to include `.#nixosConfigurations.MS-7D91.config.system.build.toplevel` and `.#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel`.
  4. Run `nix flake check` and test builds.
- **Test Scenarios:**
  - Run `nix flake check` locally to ensure all checks pass.
  - Build `.#nixosConfigurations.MS-7D91.config.system.build.toplevel` and `.#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel`.

### U5. Update Installation, Provisioning, and Recovery Documentation

- **Goal:** Update all documentation to reflect the new host, detailing live pre-migration age identity preparation, disko partitioning, bootstrap installation, and recovery.
- **Requirements:** R15.
- **Files:**
  - `README.md`
  - `AGENTS.md`
  - `docs/install.md`
  - `docs/provisioning.md`
  - `docs/recovery.md`
- **Approach:**
  1. Update `README.md` and `AGENTS.md` to describe the multi-host setup (`ThinkPad-X1-Carbon-Gen-11` and `MS-7D91`).
  2. Update `docs/install.md` with explicit commands for `MS-7D91` and note the Samsung 980 PRO NVMe disk identifier.
  3. Update `docs/provisioning.md` and `docs/recovery.md` with multi-host instructions and verification procedures.
- **Test Scenarios:**
  - Verify all markdown links are intact and repo guidelines adhere to English documentation constraints.

---

## Verification Contract

### Automated Verification Commands

```sh
# 1. Format check
nix fmt -- --ci

# 2. Flake checks
nix flake check

# 3. Toplevel system builds for both hosts (production and bootstrap)
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel
```

### Manual Verification Runbook (Hardware Post-Install)

1. Verify graphical environment: KDE Plasma 6 Wayland session starts cleanly on RTX 3060 via DisplayPort/HDMI.
2. Verify GPU compute: `nvidia-smi` reports RTX 3060 with driver loaded, and rootless `podman run --device nvidia.com/gpu=all ...` accesses GPU.
3. Verify storage: `lsblk` shows Samsung 980 PRO mounted with LUKS Btrfs subvolumes, and `/mnt/data` mounted to `sda1` with `h82` read/write access.
4. Verify Secure Boot: `bootctl status` reports Secure Boot active and Lanzaboote managing UKI generation.
5. Verify TPM2 unlock: System boots without passphrase prompt on cold boot.
6. Verify keyboard: NuPhy Gem80 responds using native firmware keys without `keyd` virtual keyboard layer.

---

## Definition of Done

- `nixosConfigurations.MS-7D91` and `nixosConfigurations.MS-7D91-bootstrap` evaluate and build to store paths without error.
- All declared `checks` in `flake.nix` pass.
- `secrets/bootstrap/MS-7D91/` exists with valid GPG-encrypted age key and public recipient.
- `secrets/tokens.yaml` is encrypted with both ThinkPad and MS-7D91 recipients and decrypts cleanly.
- `modules/nixos/base.nix` does not hardcode `networking.hostName`.
- `hosts/MS-7D91/` contains fully declarative disko, hardware, and desktop host configurations.
- `.github/workflows/check.yml` builds all four toplevel configurations.
- Documentation in `README.md`, `AGENTS.md`, and `docs/` is updated and accurate.
