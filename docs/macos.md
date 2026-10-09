# macOS hosts

This guide covers a Mac from first setup to everyday use. A macOS host is an Apple silicon Mac (`aarch64-darwin`). It gets the same shell, development tools, coding-agent configuration, Git signing, and CLI authentication as a non-NixOS Linux host, and the GUI apps, fonts, and Ghostty settings of a NixOS host. Intel Macs are not supported.

| Host | Machine |
| --- | --- |
| `MacBook-Pro-Mac17-9` | Apple silicon MacBook Pro (model identifier `Mac17,9`) |

A Mac that has no directory under `hosts/` yet needs one first; [adding a host](adding-a-host.md#macos-hosts) creates the directory, the bootstrap age material, the `tokens.yaml` recipient, and the host SSH key. Run those steps on a machine that already has the checkout and a YubiKey, then push, so the Mac can clone the result.

Before the first setup, have:

- the host directory and its secrets pushed to `main`;
- an administrator account on the Mac, for `sudo`;
- an Apple Account for the Mac App Store, which Xcode comes from;
- one of the three YubiKeys and its PIN, for the identity recovery in step 10;
- network and time for the first apply, which downloads Homebrew, every cask, the Podman machine image, Xcode, an iOS Simulator runtime, and the Android SDK;
- no directory at `~/Library/Android/sdk`, where Android Studio installs its SDK by default. Home Manager links the SDK there and stops the apply when it finds a real directory in the way. Move an existing one aside with `mv ~/Library/Android/sdk ~/Library/Android/sdk.before-nix-config`.

## What the configuration manages

The flake builds two outputs for each macOS host, `darwinConfigurations.<host>` and `darwinConfigurations.<host>-bootstrap`. Each is a nix-darwin system with Home Manager inside it, so one activation applies both layers. The bootstrap output holds no secrets.

- **Nix.** nix-darwin owns `/etc/nix/nix.conf` and keeps `auto-optimise-store` off, because store optimisation corrupts the store on macOS (NixOS/nix#7273).
- **Host marker.** `/etc/nix-config-host` records the host name and whether the bootstrap or production output is applied. `nr` reads the host from it, so the name macOS shows for the machine does not matter.
- **Homebrew.** nix-homebrew installs Homebrew on the first apply, or migrates one already at `/opt/homebrew` in place. The casks come from `modules/shared/darwin-apps.nix`: Ghostty, 1Password, Google Chrome, Claude Desktop, ChatGPT, and the other GUI apps. Cleanup is `"none"`, so an app you installed by hand stays installed. Each apply installs missing casks and upgrades outdated ones.
- **Xcode.** Xcode is the one Mac App Store app the configuration manages. `modules/darwin/xcode.nix` installs it with `mas` after the casks, or upgrades it when the App Store has a newer version, so the App Store decides the version. When `xcode-select` points at the Command Line Tools or nowhere, the step points it at Xcode. The step also accepts the license and runs first-launch setup when either is pending. It needs the App Store signed in; see step 6.
- **Android SDK.** A Mac gets the same pinned Android SDK as a Linux x86_64 host, from `packages/android-sdk.nix`, built for Apple silicon with `arm64-v8a` system images. It sits at `~/Library/Android/sdk`, a read-only link into the Nix store. `ANDROID_HOME` and `ANDROID_SDK_ROOT` point there. An SDK Android Studio already installed at that path must be moved aside before the first apply; see the prerequisites above.
- **Mobile devices.** The iOS Simulators and Android Virtual Devices listed in `my.mobileDevices`; see [Mobile devices](#mobile-devices).
- **Nix apps.** VSCodium and the T3 Code desktop app come from Nix. Home Manager copies their bundles into `~/Applications/Home Manager Apps`.
- **Containers.** One Podman machine, with minikube inside it on production outputs; see [Containers](#containers).
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

3. Move aside the files the installer wrote or edited in `/etc`. nix-darwin takes over `/etc/nix/nix.conf`, `/etc/bashrc`, and `/etc/zshrc`, and its activation stops rather than replace a file it did not write:

   ```sh
   for file in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
     sudo mv "$file" "$file.before-nix-darwin"
   done
   ```

   The installer's lines in `/etc/bashrc` and `/etc/zshrc` are what put `nix` on `PATH`, so run steps 4 to 7 in the terminal that is already open. A terminal opened before step 7 finishes has no `nix`; load it there with `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.

4. Clone the repository to `~/src/github.com/hyperlapse122/nix-config`, the path `ghq` uses with the configured root `~/src`. `ghq` is not installed until the bootstrap apply, so clone with `git`. The first time it runs, macOS's `git` may ask to install the Command Line Tools; accept.

   ```sh
   git clone https://github.com/hyperlapse122/nix-config.git ~/src/github.com/hyperlapse122/nix-config
   cd ~/src/github.com/hyperlapse122/nix-config
   ```

5. Find the host directory for this Mac. A Mac's host name contains its model identifier with the comma replaced by a hyphen, such as `Mac17-9` in `MacBook-Pro-Mac17-9`, so look it up from `sysctl`:

   ```sh
   host=$(ls hosts | grep -x ".*$(sysctl -n hw.model | tr , -).*")
   echo "$host"
   ```

   It must print exactly one name. When it prints none, the Mac has no host directory yet; see [adding a host](adding-a-host.md#macos-hosts). When it prints more than one, set `host` to the right one by hand.

6. Open the App Store app and sign in with your Apple Account. The apply downloads Xcode with the App Store account signed in to your login session, so it cannot install Xcode until you sign in. On a Mac where you already installed Xcode from the App Store, apply keeps that copy and upgrades it in place.

   Without the sign-in, the apply still succeeds. It prints a line asking you to sign in to the App Store, skips Xcode and the iOS Simulators, and sets up everything else, the Android SDK and Android Virtual Devices included. Sign in later and apply again to add Xcode and the iOS Simulators.

7. Apply the bootstrap output. `nr` is not installed yet, so run nix-darwin's `darwin-rebuild` from its flake. With `nix.conf` moved aside, flakes are not enabled yet, so the command enables them for this one run:

   ```sh
   sudo nix --extra-experimental-features 'nix-command flakes' \
     run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
     switch --flake ".#$host-bootstrap"
   ```

   This apply also installs Homebrew, the casks, and Xcode, downloads an iOS Simulator runtime, creates the Podman machine, and creates the declared mobile devices, so it takes a while and needs network. It writes `/etc/nix-config-host`, which records the host from now on, and installs GPG, the card tools, `install-user-age-identity`, and `nr`. Open a new terminal afterwards, so they are on `PATH`.

8. Give the terminal you apply from the App Management permission, in System Settings > Privacy & Security > App Management. From the second apply on, Home Manager updates the app bundles it copied into `~/Applications/Home Manager Apps`, and its `copyApps` check aborts the activation when the terminal cannot modify them. Apply from a local GUI session, not over SSH: over SSH, the same check aborts unless remote users have Full Disk Access.

9. Create the directories that will hold plaintext secrets, with mode 0700, and exclude each from Time Machine. `tmutil addexclusion` needs the path to exist, so create them first:

   ```sh
   for dir in ~/.config/nix-config/age ~/.local/state/cli-auth ~/.config/gh ~/.config/glab-cli; do
     mkdir -p "$dir"
     chmod 0700 "$dir"
     tmutil addexclusion "$dir"
   done
   ```

10. With a YubiKey inserted, recover the host's age identity. It is the same helper and installer a non-NixOS Linux host uses; GPG reaches the card through macOS's own smart card support, with no pcscd. The new terminal does not have `host` from step 5, so read it from the marker the bootstrap apply wrote:

    ```sh
    cd ~/src/github.com/hyperlapse122/nix-config
    host=$(sed -n 's/^host=//p' /etc/nix-config-host)
    ./scripts/recover-age-identity --user --host "$host"
    ```

    It installs `~/.config/nix-config/age/key.txt`. [Provisioning](provisioning.md#recover-once-on-a-non-nixos-host) describes what it checks.

11. Apply the production output, in the same terminal. `nr` refuses to move a bootstrap generation to production unless you name the host:

    ```sh
    nr switch --host "$host"
    ```

    It publishes the gh and glab configuration, the tokens, and the host's SSH key.

12. Exclude the host's SSH key from Time Machine by path. `host-secrets` replaces that file on every apply, and an ordinary exclusion is attached to the file, so it would be lost with the first replacement. A path exclusion (`-p`) needs `sudo`:

    ```sh
    sudo tmutil addexclusion -p ~/.ssh/id_ed25519_nix_config
    ```

13. Register the host's SSH public key with GitHub and every server the host must reach; see [SSH key](#ssh-key) below.

## Everyday use

Pull, then apply from the clone. Routine applies need no YubiKey:

```sh
cd ~/src/github.com/hyperlapse122/nix-config
git pull
nr switch
```

`nr switch` builds the nix-darwin system as your user, registers it as the system profile, and activates it through `sudo`. Run it from the terminal that holds the App Management permission. `nr` builds the flake of the Git checkout it runs in; from anywhere else, name the checkout with `--flake-dir`.

| Command | Effect |
| --- | --- |
| `nr switch` | Build and activate the production output for the host in `/etc/nix-config-host`. |
| `nr switch --host <host>` | Name the host explicitly. Required for the first move from bootstrap to production. |
| `nr switch --bootstrap` | Apply the secret-free bootstrap output again. |
| `nr switch --flake-dir <path>` | Build from the checkout at `<path>` instead of the current one. |
| `nr build` | Build the system without activating it and without `sudo`. |
| `nr boot`, `nr test` | Refused: a Mac has no boot generation. |

The age identity is checked twice, and either check stops the apply before anything is published. Before building, `nr` stops when `~/.config/nix-config/age/key.txt` is missing. During activation, before Home Manager changes a single link, `host-secrets` stops when the identity is not owned by you, does not have mode 0600, or cannot decrypt every secret. Both name the file and the recovery command, and neither prints a secret.

### Rolling back

Every `nr switch` adds a generation to the system profile, `/nix/var/nix/profiles/system`. To return to the previous one, point the profile back at it and activate it, as `nr` does for a new generation:

```sh
sudo nix-env -p /nix/var/nix/profiles/system --rollback
sudo /nix/var/nix/profiles/system/activate
```

The next `nr switch` from the checkout builds a new generation again, so fix the checkout before applying once more.

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

A Mac runs containers in one Podman machine, `podman-machine-default`: a rootful Fedora CoreOS VM on the libkrun provider with 4 CPUs and an 8 GiB memory cap. Every apply, bootstrap included, creates it when it is missing, and a launch agent starts it at login and whenever it stops. No app needs launching and no account signs in.

- **Memory.** 8 GiB is a cap, not a reservation. The VM holds host memory only while the guest uses it, and libkrun hands pages the guest frees back to macOS. macOS reclaims them lazily, so Activity Monitor can keep showing the old size until memory gets tight. Changing the cap or the CPUs in `home/h82/dev/containers.nix` reaches the existing machine on the next apply: the apply stops the machine, changes it, and the launch agent starts it again.
- **minikube.** On a production output, a second launch agent waits until the machine answers, then starts the `minikube` cluster on the Podman driver with containerd, 4 GiB, and 2 CPUs. A failed start is retried every minute; its log is `~/Library/Logs/minikube.log`. A bootstrap output starts no cluster. A cluster that stops mid-session, for example after the machine restarts, comes back at the next login or with `minikube start`.
- **docker.** `docker` is a link to `podman`, as on NixOS, and `DOCKER_HOST` names the machine's API socket under the per-user temporary directory, for shells and for apps launched from Finder or the Dock. Testcontainers works with no other setting.
- **Registry credentials.** `~/.config/containers/auth.json` maps `ghcr.io`, `registry.gitlab.com`, and `registry.jpi.app` to `docker-credential-sops`, so `podman pull` and `docker pull` fetch private images with no login. `docker.io` pulls stay anonymous. A Docker API client that pulls a private image without sending credentials itself makes the VM look for the helper, which only the Mac has, so that pull fails. [Container runtime and registry authentication](provisioning.md#container-runtime-and-registry-authentication) describes the credential helper.
- **Other machines.** The configuration manages only `podman-machine-default`, and every apply deletes any other Podman machine. Create containers, not machines.

### Moving off OrbStack

A Mac set up before this change still has OrbStack installed: the apply no longer lists the cask, and Homebrew cleanup is `"none"`, so nothing removes it. When you no longer need its containers and images, remove it with its data:

```sh
brew uninstall --zap orbstack
```

`~/.docker/config.json` stays behind and is harmless: `docker` is Podman now, which reads `auth.json` instead.

## App notes

- VSCodium's user directory is `~/Library/Application Support/VSCodium/User`. Its keybindings file is a read-only store link; add a keybinding to `home/h82/dev/vscodium.nix` instead. See [VSCodium](provisioning.md#vscodium).
- The T3 Code desktop app is the flake's pinned nightly, `T3 Code (Nightly).app`. A launch agent sets `T3CODE_DISABLE_AUTO_UPDATE=1` at login, so the app does not update itself off the pin. See [T3 Code](provisioning.md#t3-code).
- An app added to the NixOS user environment needs a macOS decision in `modules/shared/darwin-apps.nix`: a cask, a Nix package, or a reason to leave it out. The `darwin-config` check fails without one.
- T3 Code finds the Android SDK at `~/Library/Android/sdk` even when started from the Dock or Finder, where `ANDROID_HOME` is not set. The `emulator` in that tree sets `ANDROID_HOME` and `ANDROID_SDK_ROOT` itself before it starts the store emulator, so an AVD boots from T3 Code's Device panel.

### Mobile devices

The option `my.mobileDevices`, in `home/h82/dev/mobile-devices.nix`, lists the iOS Simulators and Android Virtual Devices (AVDs) a Mac gets. The default list is one `iPhone 18 Pro` and one `pixel_10_pro`. Each entry has three fields:

- `platform`: `"ios"` or `"android"`.
- `model`: for iOS, a device type name from `xcrun simctl list devicetypes`, such as `iPhone 18 Pro`; for Android, a device id from `avdmanager list device -c`, such as `pixel_10_pro`.
- `version`: optional. For iOS, an iOS version such as `"27.0"`; left out, it is the newest iOS Simulator SDK the installed Xcode carries. For Android, a pinned API key from `packages/android-sdk-repo.json`, such as `"36"` or `"37.0"`; left out, it is the newest pinned API level.

Every apply, bootstrap included, runs `mobile-devices` as your user and creates each listed device that does not exist yet. The name carries the version: an iOS Simulator is named `<model> (iOS <version>)`, such as `iPhone 18 Pro (iOS 27.0)`, and an AVD `<model>_API_<api>`, such as `pixel_10_pro_API_37.0`. A device with that name is left as it is. When the newest iOS Simulator runtime is missing, the apply downloads it first. It downloads no other iOS version, so an entry pinned to an older iOS version whose runtime is not installed is skipped with a message. A device that cannot be created is reported and the apply continues.

To add a device, add an entry to the option's `default` list in `home/h82/dev/mobile-devices.nix` and apply. These two entries add an iPad on the newest iOS and a Pixel on API 36:

```nix
{
  platform = "ios";
  model = "iPad Pro 13-inch (M5)";
}
{
  platform = "android";
  model = "pixel_10_pro";
  version = "36";
}
```

The apply never deletes, erases, or renames a device. A device you remove from the list, or one you created by hand, stays. When an App Store upgrade of Xcode brings a newer iOS runtime, or the SDK pin gains a newer API level, the next apply creates the listed devices again on the new version, and the old devices and runtimes stay. Each iOS runtime takes about 8 GB. Remove what you no longer need by hand:

```sh
xcrun simctl list devices            # names and UDIDs
xcrun simctl delete <udid>
xcrun simctl runtime list            # installed runtimes and their identifiers
xcrun simctl runtime delete <identifier>
avdmanager list avd -c               # AVD names
avdmanager delete avd -n <name>
```

AVDs live in `~/.android/avd` and name their system image by its SDK path. When the pin drops an API level, the AVDs for that level no longer boot; delete them.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| The first apply stops on unexpected files in `/etc` | A file the installer wrote is still in place. Move it aside as step 3 does, then apply again. |
| `nix: command not found` in a new terminal during setup | `/etc/bashrc` and `/etc/zshrc` are moved aside and nix-darwin has not replaced them yet. Run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`. |
| `nr: running the bootstrap generation; …` | A bare `nr switch` will not move a bootstrap generation to production. Recover the identity, then run the `nr switch --host` command the message names, or reapply with `nr switch --bootstrap`. |
| `nr: no age identity at …` | The identity is not recovered yet. Run the `recover-age-identity` command the message names, from the clone. |
| `… is not owned by …`, `… must have mode 0600`, or `cannot decrypt …` during activation | The identity file has the wrong owner or mode, or it is not this host's. Recover it again with the same command. |
| `nr: not inside a git repository; …` | `nr` was run outside the clone. `cd` into it, or pass `--flake-dir <path>`. |
| `docker` or `podman` reports that the connection is refused, while `podman machine list` shows the machine running | gvproxy, the machine's network helper, died. Run `podman machine stop`; the launch agent starts the machine again within a minute. |
| The first apply stops in `podmanMachines` | `podman machine init` could not download the machine image. Apply again once the network is back. |
| The second apply aborts in `copyApps` | The terminal lacks the App Management permission, or the apply runs over SSH. See step 8. |
| The apply stops with `Existing file '…/Library/Android/sdk' would be clobbered` | An SDK, usually Android Studio's, is a real directory at `~/Library/Android/sdk`, where Home Manager links the pinned SDK. Run `mv ~/Library/Android/sdk ~/Library/Android/sdk.before-nix-config` and apply again. Point Android Studio at the linked SDK, or delete the old one once nothing uses it. |
| The apply prints `xcode: App Store install failed; sign in to the App Store …`, and `mobile-devices` reports that the iOS Simulators were skipped | The App Store is not signed in, so the apply skipped Xcode and the iOS Simulators and set up everything else. Open the App Store, sign in with your Apple Account, and apply again. `xcode: App Store upgrade failed; …` has the same fix; the installed Xcode stays at its version until then. |

## Verification

The repository checks for macOS evaluate the fixture host on Linux and build it on CI's `macos-15` runner; none of them activates a Mac. An activation that exits 0 is not proof that every step applied, so confirm the state each step names. After the first setup, work through the [macOS hardware checklist](verification.md#macos-hosts) and record the results there.

## Losing or retiring the Mac

The age identity and SSH key are plaintext on the Mac's disk, so treat everything it could decrypt as exposed. Revoke its SSH key, remove its recipient, and rotate the tokens as [compromise or decommission](provisioning.md#compromise-or-decommission-of-a-non-nixos-host) describes.
