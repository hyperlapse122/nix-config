---
title: ThinkPad Disko SSD Identifier Update - Plan
type: chore
date: 2026-09-23
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# ThinkPad Disko SSD Identifier Update - Plan

## Goal Capsule

- **Objective:** `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` and `docs/install.md` correctly identify the SSD physically installed in the ThinkPad, so a future reinstall targets the right disk and the install guide's by-id confirmation step matches what `lsblk` actually shows.
- **Means:** Replace the stale KIOXIA 512GB by-id device path and capacity description with the Samsung SSD 980 PRO 1TB identifiers already confirmed on the running system (KTD1, KTD2).
- **Authority hierarchy:** Facts confirmed live on the running ThinkPad (`lsblk`, `findmnt`, `/sys/class/nvme`) outrank the stale text being replaced.
- **Stop conditions:** None — no partitioning, formatting, or `nixos-rebuild switch` is performed. This is a text-only correction to a device identifier and matching prose.
- **Execution profile:** Single small commit; no rollout.
- **Who finishes:** The implementer completes both files and the verification commands in one pass.

---

## Product Contract

### Summary

The ThinkPad's internal NVMe SSD was physically replaced, and NixOS was reinstalled onto the new drive with the disk manually substituted before `disko` formatted it. The repository's `disko.nix` and `docs/install.md` still describe the old drive, so they no longer match the hardware or the currently booted system.

### Problem Frame

`hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` names `/dev/disk/by-id/nvme-KBG5AZNV512G_LA_KIOXIA_44FPD2S3QAMU`, a 512 GB KIOXIA drive that no longer exists in the machine. `docs/install.md` repeats that model and by-id pattern in two places (the host summary and the by-id confirmation step). Because installation always erases the target disk, a future reinstall or recovery run following the current text would fail the by-id match check in `docs/install.md` against `lsblk` output, or — if that check were skipped — could target the wrong device. The system is already installed and booting correctly from the new drive; only the repository's record of the hardware is stale.

### Requirements

- R1. `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix`'s `disko.devices.disk.main.device` identifies the actual installed SSD by a stable `/dev/disk/by-id` path.
- R2. `docs/install.md`'s ThinkPad hardware summary (line 4) and by-id confirmation example (line 32) describe the actual installed SSD's model, capacity, and by-id pattern.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Use `/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNL0W417359X` as the disko device path.** `lsblk`, `/dev/disk/by-id/`, and `/sys/class/nvme/nvme0/{model,serial}` on the running ThinkPad confirm the drive is a Samsung SSD 980 PRO 1TB, serial `S5GXNL0W417359X`. Rejected: the redundant `_1`-suffixed udev alias (no semantic difference) and the `nvme-eui.002538b431a6dc61` alias (an opaque hex identifier that is harder to eyeball against `lsblk` output during the by-id confirmation step `docs/install.md` already prescribes). The chosen path matches the `nvme-<model>_<serial>` naming convention `hosts/MS-7D91/disko.nix` already uses for the identical drive model, keeping by-id naming consistent across hosts (Governs R1).
- KTD2. **Describe the new capacity as "1TB" rather than the precise 931.5 GiB figure.** `docs/install.md`'s existing MS-7D91 line already describes the identical drive model as "Samsung 980 PRO 1TB NVMe"; matching that phrasing keeps both hosts' hardware summaries consistent in style (Governs R2).

### Assumptions

None — every fact this plan relies on (drive model, serial, by-id path, capacity, and that the partition/subvolume layout is unchanged) was confirmed directly on the running ThinkPad via `lsblk`, `findmnt`, and `btrfs subvolume list /` rather than inferred.

---

## Sources & Research

Captured directly on the running ThinkPad-X1-Carbon-Gen-11 (this planning session executed on that host):

```sh
$ lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINT
NAME            SIZE MODEL                   SERIAL          FSTYPE      MOUNTPOINT
nvme0n1       931.5G Samsung SSD 980 PRO 1TB S5GXNL0W417359X
├─nvme0n1p1       2G                                         vfat        /boot
└─nvme0n1p2   929.5G                                         crypto_LUKS
  └─cryptroot 929.5G                                         btrfs       /home

$ ls -la /dev/disk/by-id/ | grep -i nvme
nvme-Samsung_SSD_980_PRO_1TB_S5GXNL0W417359X -> ../../nvme0n1
nvme-Samsung_SSD_980_PRO_1TB_S5GXNL0W417359X_1 -> ../../nvme0n1
nvme-eui.002538b431a6dc61 -> ../../nvme0n1
(matching -part1/-part2 entries exist for each alias)

$ cat /sys/class/nvme/nvme0/model /sys/class/nvme/nvme0/serial /sys/class/block/nvme0n1/size
Samsung SSD 980 PRO 1TB
S5GXNL0W417359X
1953525168

$ findmnt -t btrfs,vfat -o TARGET,SOURCE,FSTYPE,OPTIONS
/              /dev/mapper/cryptroot[/root]  btrfs  ...subvol=/root
├─/home        /dev/mapper/cryptroot[/home]  btrfs  ...subvol=/home
├─/swap        /dev/mapper/cryptroot[/swap]  btrfs  ...subvol=/swap
├─/nix         /dev/mapper/cryptroot[/nix]   btrfs  ...subvol=/nix
└─/boot        /dev/nvme0n1p1                vfat
```

Three independent sources (`lsblk`, the `/dev/disk/by-id/` symlink, and `/sys/class/nvme/nvme0/{model,serial}`) agree on model `Samsung SSD 980 PRO 1TB` and serial `S5GXNL0W417359X`, corroborating KTD1. `1953525168` 512-byte sectors ≈ 931.5 GiB, corroborating KTD2's "1TB" label choice. `findmnt` and `btrfs subvolume list /` (subvolumes `home`, `log`, `nix`, `root`, `swap`, all at the filesystem's top level) confirm the existing `/root`, `/home`, `/nix`, `/log`, `/swap` layout is already mounted and unchanged, corroborating the Assumptions above.

---

## Implementation Units

### U1. Correct the ThinkPad SSD identifier in disko.nix and install docs

- **Goal:** Replace every stale KIOXIA 512GB reference in `disko.nix` and `docs/install.md` with the confirmed Samsung SSD 980 PRO 1TB identifiers, leaving the partition and subvolume layout untouched.
- **Requirements:** R1, R2
- **Dependencies:** None
- **Files:**
  - `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix`
  - `docs/install.md`
- **Approach:**
  1. In `disko.nix`, replace the `disko.devices.disk.main.device` string with the by-id path from KTD1. Leave every partition, LUKS, and btrfs-subvolume setting unchanged — the live system's mounts already match the existing layout.
  2. In `docs/install.md` line 4, replace "internal KIOXIA 512 GB NVMe" with the new model/capacity per KTD2, matching the MS-7D91 line's phrasing shape (line 5).
  3. In `docs/install.md` line 32, replace the KIOXIA by-id example with the new by-id path from KTD1, matching the existing MS-7D91 line's sentence structure (line 33).
- **Execution note:** This is a configuration/documentation identifier correction with no behavioral branching; prove it with the build/eval checks in the Verification Contract rather than unit tests.
- **Patterns to follow:** `hosts/MS-7D91/disko.nix`'s `device` field and `docs/install.md`'s existing MS-7D91 lines (4-5, 33) for phrasing and by-id naming convention.
- **Test scenarios:**
  - Test expectation: none -- pure identifier and prose correction with no branching logic; correctness is proven by the Verification Contract's eval/build checks and by direct comparison against the running system's `lsblk`/`/dev/disk/by-id` output already captured under Sources & Research.
- **Verification:** `nix flake check` succeeds with the corrected `disko.nix` (including the `boot-layout` VM check, which imports this file); the ThinkPad and ThinkPad-bootstrap toplevel builds succeed; no remaining occurrence of the old identifier or capacity strings (`KBG5AZNV512G`, `44FPD2S3QAMU`, `KIOXIA`, the ThinkPad's old "512 GB"/"512GB") outside the historical plan artifacts under `.compound-engineering/` (see Scope Boundaries).

---

## Scope Boundaries

### Deferred to Follow-Up Work

- `docs/install.md`'s unrelated line "Disk swap and hibernation are not configured" (in the Initialize section) appears stale against the existing `/swap` subvolume and 64G swapfile already declared in `disko.nix` before this SSD replacement. That inconsistency predates and is unrelated to the hardware swap this plan addresses; leave it for a separate documentation pass.
- Historical plan artifacts under `.compound-engineering/artifacts/plans/` (`2026-09-21-0149-...-plan.md`, `2026-09-22-1646-...-plan.md`) still name the old KIOXIA drive in point-in-time hardware-spec tables. These are dated records of past scoping, not live configuration or documentation; this plan does not rewrite them, and the Verification Contract's `git grep` excludes that directory accordingly.

---

## Verification Contract

| Command | Purpose |
| --- | --- |
| `nix fmt -- --ci` | Confirm `disko.nix` still matches the repo's `nixfmt-tree` formatting after the device-string edit. |
| `nix flake check` | Run declared checks, including the `boot-layout` VM check that imports `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` (disko's test helper substitutes a disposable QEMU disk for the by-id path, so this proves the file still evaluates and boots, not that the specific by-id path is reachable). |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Confirm the production ThinkPad configuration still evaluates and builds. |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Confirm the bootstrap ThinkPad configuration still evaluates and builds. |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` and the `MS-7D91-bootstrap` equivalent | Confirm the unrelated desktop host is unaffected, per the repository's pre-shipping build convention. |
| `git grep -n "KBG5AZNV512G\|44FPD2S3QAMU\|KIOXIA\|512 GB\|512GB" -- ':!.compound-engineering'` | Confirm no stale identifier or capacity string remains outside the historical plan artifacts under `.compound-engineering/` (see Deferred to Follow-Up Work — those dated records intentionally keep the old hardware description as a point-in-time snapshot). |

Do not run `nixos-rebuild switch` or any disko format/destroy action as part of this verification — the repository convention reserves those for actual hardware installation, and this system is already installed and booting.

## Definition of Done

- `disko.nix`'s device path and both `docs/install.md` references match the SSD confirmed live on the running ThinkPad (R1, R2).
- All Verification Contract commands pass.
- No file other than `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` and `docs/install.md` is modified.
