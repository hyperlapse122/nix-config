{ config, lib, ... }:
{
  # Bootstrap is intentionally plain systemd-boot.  It can boot and install
  # the final signed generation before Secure Boot keys or TPM enrollment are
  # available.
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 5;

  # Remove the final module's TPM-only crypttab options for the first install;
  # the normal passphrase remains available as the recovery path.
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = lib.mkForce [ ];
}
