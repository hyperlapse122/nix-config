# Verification

## Repository checks

```sh
nix fmt -- --ci
nix flake check --no-build
nix flake check
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
```

Run VM checks on Linux with access to `/dev/kvm`. Use only temporary VM disks; do not access the host NVMe disk. `auth-provisioning` checks authentication setup without a card or login session, reapplication of the same generation, failures caused by missing or corrupt keys, retries after key recovery, and restoration of deleted CLI files. `boot-layout` checks the LUKS layout and boot on a temporary disk. `keyd-remap` checks the generated keyd configuration and libinput quirk for both states of the Copilot-key option, and parses both generated files with `keyd check`. `agent-memory` checks that the generated Home Manager configuration sets `CLAUDE_CODE_DISABLE_AUTO_MEMORY = 1`, `autoMemoryEnabled = false`, `autoDreamEnabled = false`, `disableAutoGenerateMemories = true`, and `experimental.autoMemory = false`. PIN proxy and recovery helper checks use only fake PINs, tokens, and test keys.

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
- [ ] Confirm with `sudo keyd monitor` that the built-in keyboard reports the device id the keyd module targets.
- [ ] Switch between Korean and English with Caps Lock alone in a Plasma session.
- [ ] Toggle capitalisation with Ctrl+Caps Lock.
- [ ] Confirm the Caps Lock toggle still switches input after resuming from suspend.
- [ ] At the SDDM greeter, confirm Caps Lock alone does nothing and leaves its LED off while Ctrl+Caps Lock still toggles capitalisation.

If the Caps Lock toggle stops working, read `systemctl status keyd` and `journalctl -u keyd`; a rejected configuration is fail-open, so the keyboard reverts to stock behaviour rather than locking, and booting the previous generation restores the last working configuration.

Automation does not reinstall the physical laptop. Report repository verification results separately from completion of this checklist.
