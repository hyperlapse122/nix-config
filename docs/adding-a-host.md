# Adding a host

A host is a directory under `hosts/`. `flake.nix` reads that directory and builds two outputs for each entry: `<host>` for production and `<host>-bootstrap` for the first installation. Adding a machine does not touch `flake.nix`, `modules/`, `home/`, or `tests/`. It needs a host directory, bootstrap age material, and the new recipient in `.sops.yaml`.

Replace `<host>` in every command below with the new directory name.

## Choose the name

The directory name is the host name. `mkHost` in `flake.nix` sets `networking.hostName` from it, so the host files never declare it.

Use the machine's distinctive model identifier, such as the DMI product name or the full model designation. The name must not appear as a substring anywhere in `flake.nix`, `modules/`, `home/`, `tests/`, `scripts/`, `packages/`, or `.github/workflows/`. The `host-name-guard` check scans those paths for every host directory name and fails on any hit. A generic word such as `desktop` or `laptop` would collide with ordinary code and comments, which is why the rule asks for a model identifier. Shared code refers to machines by trait, never by name.

## Create the host directory

Create `hosts/<host>/` with three files.

- `hardware.nix`: kernel modules, firmware, CPU microcode, and graphics drivers. Start from `nixos-generate-config --no-filesystems --show-hardware-config` run on the target from the installation media, then keep only what the machine needs.
- `disko.nix`: the disk layout. Copy an existing host's `disko.nix` to keep the shared layout (a 2 GiB ESP, then LUKS2 around Btrfs subvolumes for `/`, `/home`, `/nix`, `/var/log`, and `/swap`), and change only `device` to the target disk's `/dev/disk/by-id/` path.
- `default.nix`: imports the other two files and declares the host's traits.

```nix
{ ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];
  my.laptop.enable = true;
}
```

Do not import `modules/nixos/profile.nix`. `mkHost` imports it for every host, and the profile imports every NixOS module under `modules/nixos/`. It also sets the shared defaults with `lib.mkDefault`: Podman, CLI authentication, the Tokscale token, Tailscale, and Proton VPN, the last three off on the bootstrap output. A host can override any of them.

### Traits

A trait is a `my.*.enable` option that defaults to `false`. Hardware-specific modules are imported on every host and stay inert until the host enables their trait. Set only the traits the machine's hardware calls for:

| Trait | Enables |
| --- | --- |
| `my.keyd.enable` | The keyd remap of the internal keyboard (`modules/nixos/hardware/keyd.nix`). `my.keyd.copilotKey` adds the correction for a keyboard that ships a Copilot key in place of the right Meta key. |
| `my.fingerprint.enable` | Fingerprint authentication for the lock screen, polkit, and `sudo`. The module keeps it off on the bootstrap output, so write `true`. |
| `my.thunderbolt.enable` | Thunderbolt device authorization through bolt. |
| `my.nuphyGem80.enable` | Device access for the NuPhy Gem80 configurator and firmware flashing. |
| `my.laptop.enable` | The lid-switch policy, in both logind and KDE Powerdevil. |

Other per-host options keep their own meaning. `my.tailscale.advertiseRoutes` makes the host the tailnet's subnet router, which only one host should be, and `my.cliAuth.enableDockerToken` decrypts the Docker Hub token (see `secrets/README.md`). Keep anything that is not a trait, such as an extra mount, in the host's `default.nix`.

A check that covers a trait expects at least one production configuration to enable it. Removing the last host that enables a trait therefore fails `nix flake check`.

## Create bootstrap age material

Each host has its own age identity, encrypted to the OpenPGP card. Run the preparation helper from the development shell on an existing machine with a card inserted:

```sh
nix develop
./scripts/prepare-age-identity \
  --host <host> \
  --recipient 621512777E6933FEB4458FDC4945855D4F283F05
```

It writes `secrets/bootstrap/<host>/age-key.asc` and `secrets/bootstrap/<host>/recipient.txt`, and refuses to overwrite an existing host directory. Do not write either file by hand. [Provisioning](provisioning.md) describes what the helper does with the plaintext.

## Add the recipient to `.sops.yaml` and re-encrypt

`.sops.yaml` has one creation rule per encrypted file, and each rule lists the age recipients that may decrypt it. Append the value from `secrets/bootstrap/<host>/recipient.txt` to the `age:` list of every rule the new host needs, comma-separated. A production host needs `secrets/tokens.yaml`, `secrets/wifi.yaml`, and `secrets/tailscale.yaml`.

Adding a recipient does not change existing ciphertext. Re-encrypt each file to the new recipient list on a machine whose local identity can already decrypt it. The development shell provides `sops`:

```sh
nix develop
export SOPS_AGE_KEY_CMD="sudo cat /var/lib/sops-nix/key.txt"
sops updatekeys -y secrets/tokens.yaml
sops updatekeys -y secrets/wifi.yaml
sops updatekeys -y secrets/tailscale.yaml
unset SOPS_AGE_KEY_CMD
```

## Stage the new files

A flake sees only files that Git tracks. Until the new files are staged, `flake.nix` does not see `hosts/<host>`, and the checks do not see its bootstrap material:

```sh
git add hosts/<host> secrets/bootstrap/<host> .sops.yaml
```

The re-encrypted `secrets/*.yaml` files are already tracked, so the flake sees their new contents without staging. Stage them with the rest before committing.

Confirm that the flake now lists both outputs for the new host, `<host>` and `<host>-bootstrap`:

```sh
nix eval .#nixosConfigurations --apply builtins.attrNames
```

## Run the checks and builds

```sh
nix fmt -- --ci
nix flake check
nix build --no-link .#vmChecks.all
nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.<host>-bootstrap.config.system.build.toplevel
```

Build every other output too before shipping, using the loop in [verification](verification.md#repository-checks). CI builds every output `nixosConfigurations` lists, so the new host joins its build matrix without a workflow change.

Three checks fail when a step above was missed:

- `bootstrap-recipients` (`tests/bootstrap-recipients.nix`) pairs `hosts/` with `secrets/bootstrap/`. It names the side that is missing when a host has no bootstrap material or bootstrap material has no host. It also fails when the recorded recipient does not appear in `.sops.yaml`. Run it alone with `nix build --no-link .#checks.x86_64-linux.bootstrap-recipients`.
- `boot-layout-invariants` (`tests/boot-layout-invariants.nix`) checks the new host's `disko.nix` for the LUKS, ESP, btrfs, and swapfile layout that `boot.nix` relies on. The `boot-layout` VM test boots only the first host's layout, so this check is what covers the new one.
- `host-name-guard` fails when the new name appears in one of the paths listed under [Choose the name](#choose-the-name). Rename the directory, or replace the reference in shared code with a trait.

## Install

Follow [fresh installation](install.md) with the new host's name. Add a subsection under its per-host notes for anything specific to the machine, such as a secondary disk or firmware quirk, and a matching subsection in [verification](verification.md#per-host-hardware-checks) for the hardware checks it needs.
