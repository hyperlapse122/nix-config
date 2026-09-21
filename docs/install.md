# Fresh ThinkPad installation

The target is `ThinkPad X1 Carbon Gen 11`, with configuration name `ThinkPad-X1-Carbon-Gen-11`. This procedure erases the existing Fedora installation and all data on the internal NVMe disk. Do not repeat it for routine configuration changes.

## Prepare before erasing the disk

1. Complete [authentication recovery preparation](provisioning.md) on the existing system. Store the public GPG key, encrypted tokens, and age identity encrypted for the YubiKey in the repository. Verify decryption.
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
sudo dmidecode -s system-version
```

Confirm that the by-id path declared in `hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix` identifies the internal KIOXIA 512 GB disk you intend to install on. For a different machine or disk, update and evaluate the declaration first. Do not select the target solely by its enumeration as `/dev/nvme0n1`.

## Initialize the disk and install the bootstrap configuration

The disko command below **erases the entire target disk**. Run it only when the target path in the file matches the `lsblk` output. Use the disko version pinned in the lock file.

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run .#disko -- \
  --mode disko hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix
sudo nixos-install --flake .#ThinkPad-X1-Carbon-Gen-11-bootstrap --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd h82'
```

Enter the LUKS passphrase and keep it safe. The layout consists of a 2 GiB ESP and Btrfs root/home/nix/log subvolumes inside LUKS2. Disk swap and hibernation are not configured.

For the first reboot, keep Secure Boot disabled and enter the LUKS passphrase. Verify Plasma login and `sudo -v`. The bootstrap configuration does not require real token decryption or Secure Boot private keys.

## Prepare local decryption and signing keys

On the installed NixOS, fetch the repository again over HTTPS and follow the age identity recovery procedure in [provisioning](provisioning.md). This recovery is needed only for initial installation or recovery.

```sh
sudo sbctl create-keys
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
sudo sbctl verify
```

If restoring an existing signing bundle, restore the full backup of `/var/lib/sbctl` with root-only permissions instead of running `create-keys`. The rebuild deploys user settings, CLI authentication files, and signed boot files together. Check the EFI executables managed by Lanzaboote in the `sbctl verify` output. External kernel payloads are verified by hash, so do not assume that every file on the ESP has a PE signature.

## Enroll Secure Boot keys

Switch the firmware to Setup Mode so you can enroll user keys. Check the Lenovo firmware menus and the changes they make. Do not delete dbx. Retain Microsoft certificates for compatibility.

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

Reboot to verify automatic unlocking, then confirm that you can also boot with the recovery passphrase. PCR7 binds to the Secure Boot policy; it does not guarantee the integrity of a particular kernel or root data. Retaining Microsoft certificates also trusts other boot paths signed by those certificates.

After enrollment, encrypt and back up the LUKS header and `/var/lib/sbctl` to external media. A header backup contains the key slots from the time of the backup, so treat old backups as sensitive too. Follow the [recovery guide](recovery.md) and [verification checklist](verification.md).
