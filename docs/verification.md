# Verification

## Repository checks

```sh
nix fmt -- --ci
nix flake check --no-build
nix flake check
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
```

Run VM checks on Linux with access to `/dev/kvm`. Use only temporary VM disks; do not access the host NVMe disk. `auth-provisioning` checks authentication setup without a card or login session, reapplication of the same generation, failures caused by missing or corrupt keys, retries after key recovery, and restoration of deleted CLI files. `boot-layout` checks the LUKS layout and boot on a temporary disk. `keyd-remap` checks the generated keyd configuration and libinput quirk for both states of the Copilot-key option, and parses both generated files with `keyd check`. `claude` checks that the generated configuration sets `CLAUDE_CODE_DISABLE_AUTO_MEMORY = 1`, that `/etc/claude-code/managed-settings.json` sets `autoMemoryEnabled = false`, `model = opus[1m]`, and `effortLevel = medium`, and that Home Manager does not manage `~/.claude/settings.json`. `gemini` checks that the generated Home Manager configuration sets `disableAutoGenerateMemories = true` and `experimental.autoMemory = false`. `nix-ld` asserts that dynamic linker support (`programs.nix-ld`) is enabled for production and bootstrap configurations, `environment.ldso` points to the nix-ld binary, and baseline shared libraries (`stdenv.cc.cc.lib`, `zlib`, `openssl`) are present. `desktop-autostart` asserts that `programs._1password` is enabled on both configurations and that the production configuration declares enabled, forced autostart entries for 1Password and Kleopatra, each running the configured package with `--silent` and `--daemon` in `X-KDE-autostart-phase=2`, while the bootstrap configuration declares neither. `nixos-rebuild-helper` asserts the four zsh aliases, the packaged `nr` helper and the `nvd diff` invocation baked into it, and the `/etc/nixos-host-variant` marker on both configurations. `nr` drives the rebuild helper's host and flake-directory resolution, its untracked-file warning, its refusal to switch a bootstrap generation without `--host`, and its per-subcommand diff target. `age-identity-helpers` drives the recovery and preparation helpers, including the executed decrypt-to-installer pipeline with both sides stubbed, the unknown-host listing, the round-trip decrypt check, the partial-write and interruption rollbacks, and both helpers' refusal to run as root. `bootstrap-recipients` asserts that every per-host bootstrap directory holds both files and that its recorded recipient appears in `.sops.yaml`, so a regenerated identity cannot ship unable to decrypt `secrets/tokens.yaml`. PIN proxy and recovery helper checks use only fake PINs, tokens, and test keys.

## Hardware checks after installation

A successful VM test or build does not replace these checks. The person who performs them must record the results.

- [ ] Before installation, recover the bootstrap age identity with the actual YubiKey.
- [ ] Boot the installed NixOS with Secure Boot in the enabled/user state.
- [ ] Confirm that the TPM unlocks LUKS automatically.
- [ ] Boot with the recovery passphrase when the TPM is unavailable.
- [ ] Boot both the new generation and a previous generation.
- [ ] Check the default Plasma login, Wi-Fi, Bluetooth, audio, and s2idle suspend/resume.
- [ ] Rebuild successfully without a YubiKey or 1Password session.
- [ ] Confirm valid authentication on GitHub, GitLab.com, and git.jpi.app.
- [ ] Verify signed commits and tags in a temporary Git repository with `git verify-commit` and `git verify-tag`.
- [ ] After signing in to 1Password and enabling its SSH agent, connect over SSH with the selected key.
- [ ] Confirm `op --version` runs and that `op` resolves to the setgid wrapper under `/run/wrappers/bin`.
- [ ] After enabling "Integrate with 1Password CLI" in the app's Developer settings, read one item with `op` and confirm the desktop app authorizes it without a manual `op signin`.
- [ ] Confirm 1Password and Kleopatra both appear in the tray after login with no manual launch, and that neither opens a window.
- [ ] Record whether `~/.1password/agent.sock` exists while 1Password is running but still locked, or only after unlocking. That answer sizes the window in which the first SSH or Git operation of a session can still fail.
- [ ] Confirm the apps' own "start at login" toggles no longer take effect, because Home Manager owns both autostart entries.
- [ ] Run `nrd` from a directory outside the flake checkout and confirm it fails naming `--flake-dir`, then run it inside and confirm it builds.
- [ ] Run `nrs` with an untracked file in the checkout and confirm the file is named on stderr before the build starts.
- [ ] After `nrs`, confirm the generation diff reports the change; after `nrb`, confirm it reports the change staged for next boot.
- [ ] Confirm `bunx tokscale@latest` runs without `patchelf` or dynamic loader errors.
- [ ] After activation, start a fresh `claude` session and confirm it reports model `opus[1m]` and effort `medium` without manual setup. The repository checks verify only the declared values, not that Claude Code applies them; report a mismatch instead of working around it.
- [ ] Confirm with `sudo keyd monitor` that the built-in keyboard reports the device id the keyd module targets.
- [ ] Switch between Korean and English with Caps Lock alone in a Plasma session.
- [ ] Toggle capitalisation with Ctrl+Caps Lock.
- [ ] Confirm the Caps Lock toggle still switches input after resuming from suspend.
- [ ] At the SDDM greeter, confirm Caps Lock alone does nothing and leaves its LED off while Ctrl+Caps Lock still toggles capitalisation.

If the Caps Lock toggle stops working, read `systemctl status keyd` and `journalctl -u keyd`; a rejected configuration is fail-open, so the keyboard reverts to stock behaviour rather than locking, and booting the previous generation restores the last working configuration.

Automation does not reinstall the physical laptop. Report repository verification results separately from completion of this checklist.
