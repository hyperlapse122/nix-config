# Fresh installation

The supported hosts are the directories under `hosts/`. In the commands below, replace `<host>` with the target machine's directory name; `nix eval .#nixosConfigurations --apply builtins.attrNames` lists every configuration. A machine without a host directory needs [adding a host](adding-a-host.md) first. This guide installs NixOS; a machine that keeps its own Linux distribution follows [non-NixOS hosts](adding-a-host.md#non-nixos-hosts) instead. Notes that apply to one machine only are under [per-host notes](#per-host-notes).

This procedure erases the existing operating system and data on the target installation NVMe disk. Do not repeat it for routine configuration changes.

## Prepare before erasing the disk

1. Complete [authentication recovery preparation](provisioning.md) on the existing system. Store the public GPG key, encrypted tokens, and per-host age identity encrypted for the YubiKey under `secrets/bootstrap/<host>/` in the repository. Verify decryption.
2. Push repository changes to the remote and confirm that the installation environment can clone it over HTTPS without SSH authentication. You can also keep a clone on separate media.
3. Choose a LUKS recovery passphrase. Do not store it in plaintext in the repository or on the target disk. If you will reuse an existing Secure Boot signing bundle, prepare an encrypted external backup.
4. Prepare a NixOS x86_64 installation USB. If the firmware's current Secure Boot policy does not trust the installation media, temporarily disable Secure Boot. Do not erase all certificates or dbx.

If the YubiKey is the only recovery method, losing it prevents recovery of the encrypted age identity. Prepare another GPG recipient or an offline recovery copy before erasing the disk if needed.

## Check the disk from the installation media

Run the following commands in the installation media's terminal. Check network access and fetch the repository.

```sh
git clone https://github.com/hyperlapse122/nix-config.git
cd nix-config
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
sudo dmidecode -s system-product-name
sudo dmidecode -s system-version
```

Confirm that the machine is the one `<host>` describes, and that the `/dev/disk/by-id/` path declared as `device` in `hosts/<host>/disko.nix` matches the target NVMe drive in the `lsblk` output. The per-host notes list each machine's expected path.

Do not select the target solely by its enumeration as `/dev/nvme0n1`.

## Initialize the disk and install the bootstrap configuration

The disko command below **erases the entire target disk**. Run it only when the target path in the file matches the `lsblk` output. Use the disko version pinned in the lock file.

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run .#disko -- \
  --mode disko hosts/<host>/disko.nix
sudo nixos-install --flake .#<host>-bootstrap --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd h82'
```

Enter the LUKS passphrase and keep it safe. The layout consists of a 2 GiB ESP and Btrfs root/home/nix/log/swap subvolumes inside LUKS2. The `/swap` subvolume holds a 64 GiB swapfile; no hibernation resume offset is configured. Disks other than the one in `disko.nix` are not touched.

For the first reboot, keep Secure Boot disabled and enter the LUKS passphrase. Verify Plasma login and `sudo -v`. The bootstrap configuration does not require real token decryption or Secure Boot private keys.

## Prepare local decryption and signing keys

On the installed NixOS, fetch the repository again over HTTPS and recover the age identity. This recovery is needed only for initial installation or recovery. See [provisioning](provisioning.md) for what the helper does and the boundary it preserves.

```sh
./scripts/recover-age-identity
```

On the installed system the helper resolves the host from its hostname, which `mkHost` sets to `<host>`. Pass `--host <host>` when running it anywhere else.

Register this card's PIN now so later Git signing does not prompt for it again. See [provisioning](provisioning.md) for the full per-card, multi-serial design. Enter the PIN at the command's prompt, not in its arguments or shell history.

```sh
nix develop
card_serial='<normalized serial from gpg --card-status>'
secret-tool store --label='OpenPGP card PIN' service gnupg-card-pin username "$card_serial"
unset card_serial
```

```sh
sudo sbctl create-keys
sudo nixos-rebuild switch --flake .#<host>
sudo sbctl verify
```

If restoring an existing signing bundle, restore the full backup of `/var/lib/sbctl` with root-only permissions instead of running `create-keys`. The rebuild deploys user settings, CLI authentication files, and signed boot files together. Check the EFI executables managed by Lanzaboote in the `sbctl verify` output. External kernel payloads are verified by hash, so do not assume that every file on the ESP has a PE signature.

## Enroll Secure Boot keys

Switch the firmware to Setup Mode so you can enroll user keys. In the firmware setup, set Secure Boot mode to "Custom" or clear existing factory keys to enter Setup Mode. Do not delete dbx. Retain Microsoft certificates for compatibility. Check the [per-host notes](#per-host-notes) for a firmware-specific step before enrolling.

```sh
sudo sbctl status
sudo sbctl enroll-keys --microsoft
```

Enable Secure Boot in the firmware and reboot. After the installed NixOS boots successfully, check its state.

```sh
bootctl status --no-pager
sudo sbctl status
```

Do not proceed to TPM enrollment until you confirm that NixOS boots with Secure Boot in the enabled/user state. The new system does not reuse the Fedora shim.

## TPM2 automatic unlocking

The device in the following commands is the **LUKS partition** created by disko, not the whole disk. Verify it first.

```sh
lsblk -o NAME,PATH,FSTYPE,PARTLABEL,MOUNTPOINTS
sudo cryptsetup luksDump /dev/disk/by-partlabel/disk-main-luks
```

Enroll against PCR7 SHA256 in the final Secure Boot state. Do not delete the existing recovery passphrase slot. This configuration does not require a TPM PIN or YubiKey to boot.

```sh
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks \
  --tpm2-device=auto --tpm2-pcrs=7:sha256 --tpm2-with-pin=no
```

If the system previously had a separate pcrlock configuration, consult the current systemd manual and the `--tpm2-pcrlock` option to avoid applying an automatically discovered policy file. This repository does not generate a pcrlock policy.

Reboot to verify automatic unlocking, then confirm that you can also boot with the recovery passphrase. On the production output the passphrase prompt appears on the boot splash, and the boot menu opens only while Space is held at power-on. PCR7 binds to the Secure Boot policy; it does not guarantee the integrity of a particular kernel or root data. Retaining Microsoft certificates also trusts other boot paths signed by those certificates.

After enrollment, encrypt and back up the LUKS header and `/var/lib/sbctl` to external media. A header backup contains the key slots from the time of the backup, so treat old backups as sensitive too. Follow the [recovery guide](recovery.md) and [verification checklist](verification.md).

## Per-host notes

### ThinkPad-X1-Carbon-Gen-11

Lenovo ThinkPad X1 Carbon Gen 11 laptop.

- `sudo dmidecode -s system-version` reports the model name here; `system-product-name` reports only Lenovo's machine type.
- `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` identifies the internal Samsung 980 PRO 1TB NVMe as `/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNL0W417359X`.
- In the Lenovo UEFI setup, enter Setup Mode through the Secure Boot settings. The existing `PK`, `KEK`, and `db` EFI variables may carry the efivarfs immutable bit, which makes `sbctl enroll-keys` fail even in Setup Mode. Clear it just before enrolling ([EFI variables immutability](../.compound-engineering/artifacts/solutions/boot-issues/thinkpad-efivars-immutable-blocks-sbctl-enroll.md)):

  ```sh
  sudo chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}* 2>/dev/null || true
  ```

- The fingerprint reader is enabled only on the production output. Enroll after the first production switch; see [provisioning](provisioning.md#fingerprint-enrollment).

### MS-7D91

MSI MS-7D91 desktop workstation with Intel i7-13700F and NVIDIA GeForce RTX 3060.

- `sudo dmidecode -s system-product-name` reports `MS-7D91`.
- `hosts/MS-7D91/disko.nix` identifies the Samsung 980 PRO 1TB NVMe as `/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNF0WB26038A`.
- The secondary 2TB HDD, `/dev/disk/by-id/ata-ST2000DM008-2UB102_ZK30PHAD-part1`, is not touched by disko and is mounted read-write at `/mnt/data` with `nofail`.
- `hosts/MS-7D91/hardware.nix` selects the NVIDIA driver. With modesetting on, the production output also loads it in the initrd for the boot splash.
- In MSI Click BIOS, enter Setup Mode through the Secure Boot settings.
