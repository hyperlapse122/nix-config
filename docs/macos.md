# macOS hosts

This guide covers a Mac from first setup to everyday use. A macOS host is an Apple silicon Mac (`aarch64-darwin`). It gets the same shell, development tools, coding-agent configuration, Git signing, and CLI authentication as a non-NixOS Linux host, and the GUI apps, fonts, and Ghostty settings of a NixOS host. Intel Macs are not supported.

| Host | Machine |
| --- | --- |
| `MacBook-Pro-Mac17-9` | Apple silicon MacBook Pro (model identifier `Mac17,9`) |

A Mac that has no directory under `hosts/` yet needs one first; [adding a host](adding-a-host.md#macos-hosts) creates the directory, the bootstrap age material, the `tokens.yaml` recipient, and the host SSH key. Run those steps on a machine that already has the checkout and a YubiKey, then push, so the Mac can clone the result.

## What the configuration manages

The flake builds two outputs for each macOS host, `darwinConfigurations.<host>` and `darwinConfigurations.<host>-bootstrap`. Each is a nix-darwin system with Home Manager inside it, so one activation applies both layers. The bootstrap output holds no secrets.

- **Nix.** nix-darwin owns `/etc/nix/nix.conf` and keeps `auto-optimise-store` off, because store optimisation corrupts the store on macOS (NixOS/nix#7273).
- **Host marker.** `/etc/nix-config-host` records the host name and whether the bootstrap or production output is applied. `nr` reads the host from it, so the name macOS shows for the machine does not matter.
- **Homebrew.** nix-homebrew installs Homebrew on the first apply, or migrates one already at `/opt/homebrew` in place. The casks come from `modules/shared/darwin-apps.nix`: Ghostty, 1Password, Google Chrome, Claude Desktop, ChatGPT, Orca, OrbStack, and the other GUI apps. Cleanup is `"none"`, so an app you installed by hand stays installed. Each apply installs missing casks and upgrades outdated ones.
- **Nix apps.** VSCodium and the T3 Code desktop app come from Nix. Home Manager copies their bundles into `~/Applications/Home Manager Apps`.
- **Fonts.** The NixOS font list is installed system-wide.
- **System defaults.** `modules/darwin/defaults.nix` is where Dock, Finder, trackpad, and keyboard defaults go. It sets none yet.
- **User environment.** zsh, Git, the development tools, Claude Code, Codex, and the other agents, configured as on a non-NixOS Linux host.

## First setup on the Mac

Run these steps on the Mac, in order, from a local login session, not over SSH.

1. Confirm that FileVault is on. The age identity and the published tokens are plaintext files in your home directory, and FileVault is what encrypts them at rest:

   ```sh
   fdesetup status
   ```

   It must report `FileVault is On.` Turn it on in System Settings > Privacy & Security > FileVault before you continue.

2. Install Nix with the upstream multi-user installer, the same one a non-NixOS Linux host uses. Skip this step if Nix is already installed this way:

   ```sh
   sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
   ```

   Open a new terminal afterwards, so `nix` is on `PATH`.

3. Move the installer's `nix.conf` aside. nix-darwin takes over `/etc/nix/nix.conf` and stops rather than replace a file it did not write:

   ```sh
   sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
   ```

4. Clone the repository. The first time it runs, macOS's `git` may ask to install the Command Line Tools; accept.

   ```sh
   git clone https://github.com/hyperlapse122/nix-config.git
   cd nix-config
   ```

5. Apply the bootstrap output. `nr` is not installed yet, so run nix-darwin's `darwin-rebuild` from its flake. With `nix.conf` moved aside, flakes are not enabled yet, so the command enables them for this one run:

   ```sh
   sudo nix --extra-experimental-features 'nix-command flakes' \
     run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
     switch --flake .#<host>-bootstrap
   ```

   This apply also installs Homebrew and the casks, so it takes a while. It writes `/etc/nix-config-host` and installs GPG, the card tools, `install-user-age-identity`, and `nr`. Open a new terminal afterwards, so they are on `PATH`.

6. Launch OrbStack once from Applications, so it sets up its virtual machine and the `docker` CLI.

7. Give the terminal you apply from the App Management permission, in System Settings > Privacy & Security > App Management. From the second apply on, Home Manager updates the app bundles it copied into `~/Applications/Home Manager Apps`, and its `copyApps` check aborts the activation when the terminal cannot modify them. Apply from a local GUI session, not over SSH: over SSH, the same check aborts unless remote users have Full Disk Access.

8. Create the directories that will hold plaintext secrets, with mode 0700, and exclude each from Time Machine. `tmutil addexclusion` needs the path to exist, so create them first:

   ```sh
   for dir in ~/.config/nix-config/age ~/.local/state/cli-auth ~/.config/gh ~/.config/glab-cli; do
     mkdir -p "$dir"
     chmod 0700 "$dir"
     tmutil addexclusion "$dir"
   done
   ```

9. With a YubiKey inserted, recover the host's age identity. It is the same helper and installer a non-NixOS Linux host uses; GPG reaches the card through macOS's own smart card support, with no pcscd:

   ```sh
   ./scripts/recover-age-identity --user --host <host>
   ```

   It installs `~/.config/nix-config/age/key.txt`. [Provisioning](provisioning.md#recover-once-on-a-non-nixos-host) describes what it checks.

10. Apply the production output. `nr` refuses to move a bootstrap generation to production unless you name the host:

    ```sh
    nr switch --host <host>
    ```

    It publishes the gh and glab configuration, the tokens, and the host's SSH key.

11. Exclude the host's SSH key from Time Machine by path. `host-secrets` replaces that file on every apply, and an ordinary exclusion is attached to the file, so it would be lost with the first replacement. A path exclusion (`-p`) needs `sudo`:

    ```sh
    sudo tmutil addexclusion -p ~/.ssh/id_ed25519_nix_config
    ```

12. Register the host's SSH public key with GitHub and every server the host must reach; see [SSH key](#ssh-key) below.

## Everyday use

Pull, then apply from the clone. Routine applies need no YubiKey:

```sh
git pull
nr switch
```

`nr switch` builds the nix-darwin system as your user, registers it as the system profile, and activates it through `sudo`. Run it from the terminal that holds the App Management permission.

| Command | Effect |
| --- | --- |
| `nr switch` | Build and activate the production output for the host in `/etc/nix-config-host`. |
| `nr switch --host <host>` | Name the host explicitly. Required for the first move from bootstrap to production. |
| `nr switch --bootstrap` | Apply the secret-free bootstrap output again. |
| `nr build` | Build the system without activating it and without `sudo`. |
| `nr boot`, `nr test` | Refused: a Mac has no boot generation. |

Before activating, `nr` checks the age identity. When it is missing, has the wrong owner or mode, or cannot decrypt the secrets, the apply stops, names the file and the recovery command, and prints no secret.

## Secrets and authentication

The age identity lives at `~/.config/nix-config/age/key.txt`, protected by FileVault. It decrypts only `secrets/tokens.yaml` and the host's own `secrets/hosts/<host>/ssh.yaml`; a Mac is never a recipient of the Wi-Fi or Tailscale secrets.

Production activation publishes:

- the gh and glab configuration, under `~/.config/gh` and `~/.config/glab-cli`;
- the registry and CLI tokens, under `~/.local/state/cli-auth/`;
- the host SSH key, at `~/.ssh/id_ed25519_nix_config`.

### YubiKey PIN

Three YubiKeys carry the same signing key, each under its own PIN. The PIN prompt is the native `pinentry_mac` dialog, which offers a "Save in Keychain" checkbox that starts unticked. Ticking it saves that card's PIN in the login Keychain, and later signing with that card needs no dialog. A rejected PIN deletes that card's saved item. [YubiKey PIN on macOS](provisioning.md#yubikey-pin-on-macos) describes the details and how to remove a saved PIN by hand.

### SSH key

A Mac has no 1Password SSH agent configured. It uses its own SSH key, and `~/.ssh/config` names it with `IdentityFile ~/.ssh/id_ed25519_nix_config`. Registering the public key stays manual. After the first production apply, print it:

```sh
ssh-keygen -y -f ~/.ssh/id_ed25519_nix_config
```

Add it to GitHub under Settings > SSH and GPG keys, and to `~/.ssh/authorized_keys` on every server the host must reach. Register it as an authentication key only; Git signing still uses the YubiKey.

## Containers

A Mac runs containers through OrbStack and gets no Podman or minikube. Production activation merges `credHelpers` entries into `~/.docker/config.json`, so OrbStack's `docker` CLI pulls private images from `ghcr.io`, `registry.gitlab.com`, and `registry.jpi.app` with no `docker login`. `docker.io` pulls stay anonymous. [Container runtime and registry authentication](provisioning.md#container-runtime-and-registry-authentication) describes the credential helper.

## App notes

- VSCodium's user directory is `~/Library/Application Support/VSCodium/User`. Its keybindings file is a read-only store link; add a keybinding to `home/h82/dev/vscodium.nix` instead. See [VSCodium](provisioning.md#vscodium).
- The T3 Code desktop app is the flake's pinned nightly, `T3 Code (Nightly).app`. A launch agent sets `T3CODE_DISABLE_AUTO_UPDATE=1` at login, so the app does not update itself off the pin. See [T3 Code](provisioning.md#t3-code).
- An app added to the NixOS user environment needs a macOS decision in `modules/shared/darwin-apps.nix`: a cask, a Nix package, or a reason to leave it out. The `darwin-config` check fails without one.

## Verification

The repository checks for macOS evaluate the fixture host on Linux and build it on CI's `macos-15` runner; none of them activates a Mac. After the first setup, work through the [macOS hardware checklist](verification.md#macos-hosts) and record the results there.

## Losing or retiring the Mac

The age identity and SSH key are plaintext on the Mac's disk, so treat everything it could decrypt as exposed. Revoke its SSH key, remove its recipient, and rotate the tokens as [compromise or decommission](provisioning.md#compromise-or-decommission-of-a-non-nixos-host) describes.
