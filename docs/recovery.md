# Updates and recovery

## Routine configuration applies

```sh
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
```

This command does not format disks or enroll TPM or UEFI keys. Once the local age identity is ready, it does not depend on the YubiKey, desktop keyring, or 1Password login state. Rebuilds work without the card, but actual Git signing does not.

Update inputs with `nix flake update`. Review the `flake.lock` diff and pass `nix flake check` and both host builds before applying. Afterward, use each CLI to check whether its remote token is valid. Successful deployment of authentication files does not guarantee that the server accepts the tokens. Periodic updates are also automated via the `Update flake.lock` GitHub Actions workflow (`.github/workflows/update-flake-lock.yml`), which opens a pull request with updated channel inputs for CI validation.

## Failed authentication applies

```sh
systemctl status sops-install-secrets.service --no-pager
sudo journalctl -u sops-install-secrets.service -b --no-pager
```

Check logs for secrets before sharing them. If the local identity is missing or corrupt, repeat [initial recovery](provisioning.md) with `./scripts/recover-age-identity` and run the same rebuild command. From the installation media or inside `nixos-enter` the hostname is the image's, not a configuration name, so the helper cannot detect the host and `--host ThinkPad-X1-Carbon-Gen-11` is required there. The same command also restores manually deleted CLI configuration files. The next successful apply overwrites local changes to managed gh/glab files.

A failed NixOS switch does not transactionally roll back all system changes. If token publication updated only some files, fix the problem and run the same command again. Do not ignore the error or treat provisioning as complete.

## Roll back a boot generation

Select a supported previous NixOS generation from the boot menu. If the system can boot, use the following command to roll back.

```sh
sudo nixos-rebuild switch --rollback
```

The initial boot generation limit is 5. Before removing old generations, confirm that the current generation boots with Secure Boot. Rollback alone cannot fix changes to firmware/db/dbx that alter whether an older generation is trusted.

## TPM unlock failure

Changes to firmware or Secure Boot policy can prevent automatic unlocking. Boot with the LUKS recovery passphrase and check whether an intended change caused the failure. Update TPM enrollment after verifying the correct final Secure Boot state.

```sh
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks \
  --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7:sha256 --tpm2-with-pin=no
```

Use `--wipe-slot=tpm2` only for TPM slots. Do not delete the recovery passphrase slot. Verify both the new automatic unlock and passphrase unlock before updating the external LUKS header backup.

## Back up LUKS and Secure Boot recovery material

Immediately after installation and after updating TPM slots, connect external media and verify that it is mounted. Replace `backup_mount` and `backup_dir` below with paths on that external media, not on the target disk. The backup files are encrypted for a GPG recipient, so they can be stored independently of whether the media itself is encrypted. Keep plaintext intermediate files only on the temporary filesystem under `/run/user`.

```sh
set -euo pipefail
umask 077
backup_mount=/run/media/h82/EXTERNAL_BACKUP
backup_dir="$backup_mount/thinkpad"
if ! findmnt --mountpoint "$backup_mount" >/dev/null; then
  printf '%s\n' 'external backup mount is missing; refusing to write under /run' >&2
  exit 1
fi
sudo install -d -m 0700 -o "$(id -u)" -g "$(id -g)" "$backup_dir"
backup_tmp=$(mktemp -d /run/user/"$(id -u)"/nix-backup.XXXXXX)
cleanup() {
  sudo rm -f -- "$backup_tmp/luks-header.img" "$backup_tmp/sbctl.tar" "$backup_tmp/header-check" "$backup_tmp/bundle-check"
  rmdir "$backup_tmp" 2>/dev/null || true
}
trap cleanup EXIT
sudo cryptsetup luksHeaderBackup /dev/disk/by-partlabel/disk-main-luks \
  --header-backup-file "$backup_tmp/luks-header.img"
sudo tar --xattrs --acls --numeric-owner -C /var/lib \
  -cpf "$backup_tmp/sbctl.tar" sbctl
sudo chown -R "$(id -u):$(id -g)" "$backup_tmp"
gpg --armor --encrypt \
  --recipient A7F1956CD1A035A139BC7ABFCC740A29852C0E95 \
  --output "$backup_dir/luks-header.img.asc" "$backup_tmp/luks-header.img"
gpg --armor --encrypt \
  --recipient A7F1956CD1A035A139BC7ABFCC740A29852C0E95 \
  --output "$backup_dir/sbctl.tar.asc" "$backup_tmp/sbctl.tar"
test -s "$backup_dir/luks-header.img.asc" \
  && test -s "$backup_dir/sbctl.tar.asc"
gpg --decrypt --output "$backup_tmp/header-check" "$backup_dir/luks-header.img.asc"
gpg --decrypt --output "$backup_tmp/bundle-check" "$backup_dir/sbctl.tar.asc"
cmp "$backup_tmp/luks-header.img" "$backup_tmp/header-check"
cmp "$backup_tmp/sbctl.tar" "$backup_tmp/bundle-check"
cleanup
trap - EXIT
```

The LUKS header contains the key slots from the time of the backup. Keep both `.asc` files on external media. If you suspect that the header backup was exposed, replace the recovery passphrase and service credentials.

If the system cannot boot, use the installation USB to open the existing filesystems with the declared layout below. Do not rerun disko's formatting mode. With network access on the installation USB, clone the repository again into `/tmp/nix-config` under the target root. Without network access, copy it from external media to the same path.

```sh
sudo cryptsetup open /dev/disk/by-partlabel/disk-main-luks cryptroot
sudo mount -o subvol=/root,compress=zstd,noatime /dev/mapper/cryptroot /mnt
sudo install -d /mnt/home /mnt/nix /mnt/var/log /mnt/boot /mnt/tmp
sudo mount -o subvol=/home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
sudo mount -o subvol=/nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
sudo mount -o subvol=/log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log
sudo mount /dev/disk/by-partlabel/disk-main-ESP /mnt/boot
if sudo test -d /mnt/tmp/nix-config/.git; then
  sudo git -C /mnt/tmp/nix-config pull --ff-only
else
  sudo git clone https://github.com/hyperlapse122/nix-config.git /mnt/tmp/nix-config
fi
```

`nixos-enter` creates the required `/dev`, `/sys`, and `/proc` bind mounts itself. Restore `/var/lib/sbctl` before running `nixos-rebuild boot`. The commands to restore signed boot files follow.

## Lost Secure Boot signing keys

Connect the encrypted external backup, restore `/var/lib/sbctl`, and check the backup files' ownership and permissions. To restore from a running installation, extract the saved bundle and sign the next boot generation again:

```sh
set -o pipefail
gpg --decrypt /path/to/sbctl.tar.asc | \
  sudo tar --xattrs --acls --numeric-owner -xpf - -C /var/lib
sudo chown -R root:root /var/lib/sbctl
sudo chmod -R go-rwx /var/lib/sbctl
sudo nixos-rebuild boot --flake .#ThinkPad-X1-Carbon-Gen-11
```

On the installation USB, complete the mount procedure above, then import the public key and check the card as the live environment's normal user. Decrypt in the shell opened by `nix develop`; do not depend on the target's root GPG agent.

```sh
nix develop path:/mnt/tmp/nix-config
gpg --import /mnt/tmp/nix-config/keys/signing.asc
gpg --card-status
set -o pipefail
gpg --decrypt /path/to/sbctl.tar.asc | \
  sudo tar --xattrs --acls --numeric-owner -xpf - -C /mnt/var/lib
sudo chown -R root:root /mnt/var/lib/sbctl
sudo chmod -R go-rwx /mnt/var/lib/sbctl
sudo nixos-enter --root /mnt -c \
  'cd /tmp/nix-config && nixos-rebuild boot --flake .#ThinkPad-X1-Carbon-Gen-11'
```

If the existing `/mnt/var/lib/sbctl` is intact, skip decryption and extraction and run only the last command. Without a backup, generate a new bundle and repeat UEFI key enrollment. Update TPM enrollment under the new Secure Boot policy too.

Do not keep LUKS recovery material only on the locked target disk or rely on that disk's TPM automatic unlock as the sole recovery method.

## Lost or replaced YubiKey

Rebuilds remain possible while the existing installation retains its local age identity. Git signing stops. Update the configuration with the replacement signing key's public key and fingerprint, and update the verification keys on the relevant services.

Recovering the existing bootstrap ciphertext during reinstallation requires another registered recipient or a separate offline backup. If neither exists, reissue service tokens and create a new age identity and bootstrap ciphertext. A replacement card cannot automatically decrypt ciphertext encrypted for the lost card.

Verify the new card's public encryption key and update the age identity's bootstrap ciphertext for the new recipient. Test actual recovery before deciding whether to retain or discard old recovery material. Update the existing Secret Service cache for automatic PIN entry separately; do not tie it to rebuilds.

## Replace tokens or the age identity

To change tokens, edit the SOPS-encrypted token file and rebuild. If the local age identity was exposed, generate a new identity and re-encrypt all ciphertext for the new recipient. Update the bootstrap ciphertext and local identity together. Historical ciphertext remains in the repository, so revoke and reissue potentially exposed service tokens through their providers.
