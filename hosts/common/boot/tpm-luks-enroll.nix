{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.boot.tpm-luks-enroll;

  zeroPcr15 = "0000000000000000000000000000000000000000000000000000000000000000";

  enrollLuksTpm2 = pkgs.writeShellApplication {
    name = "enroll-luks-tpm2";
    runtimeInputs = with pkgs; [
      coreutils
      cryptsetup
      gnugrep
      jq
      sbctl
      systemd
    ];
    text = ''
      devices=(${lib.escapeShellArgs cfg.devices})
      pcrs=${lib.escapeShellArg cfg.pcrs}
      add_recovery_key=0
      check_only=0
      yes=0

      usage() {
        cat <<'EOF'
      Usage: enroll-luks-tpm2 [--check] [--recovery-key] --yes

      Enroll the configured LUKS2 devices for TPM2 unlock.

      Options:
        --check         Validate Secure Boot, TPM2, and LUKS prerequisites only.
        --recovery-key  Add a systemd recovery key before TPM2 enrollment.
        --yes           Confirm the LUKS header mutation.
        -h, --help      Show this help.
      EOF
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --check)
            check_only=1
            ;;
          --recovery-key)
            add_recovery_key=1
            ;;
          --yes)
            yes=1
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        esac
        shift
      done

      if [ "$(id -u)" -ne 0 ]; then
        printf '%s\n' "enroll-luks-tpm2 must be run as root." >&2
        exit 1
      fi

      secure_boot="$(sbctl status --json | jq -r '.secure_boot')"
      setup_mode="$(sbctl status --json | jq -r '.setup_mode')"
      if [ "$secure_boot" != true ] || [ "$setup_mode" != false ]; then
        printf '%s\n' "Secure Boot must be enabled and Setup Mode must be disabled." >&2
        sbctl status >&2
        exit 1
      fi

      tpm_state="$(systemd-analyze has-tpm2 2>&1)" || true
      tpm_verdict="$(printf '%s\n' "$tpm_state" | head -n 1)"
      if [ "$tpm_verdict" != yes ]; then
        printf '%s\n' "TPM2 is not fully available:" >&2
        printf '%s\n' "$tpm_state" >&2
        exit 1
      fi

      if [ ! -e /dev/tpmrm0 ] && [ ! -e /dev/tpm0 ]; then
        printf '%s\n' "No TPM device node found at /dev/tpmrm0 or /dev/tpm0." >&2
        exit 1
      fi

      if ! systemd-cryptenroll --tpm2-device=list | grep -q '^/dev/'; then
        printf '%s\n' "systemd-cryptenroll could not discover a TPM2 device." >&2
        systemd-cryptenroll --tpm2-device=list >&2 || true
        exit 1
      fi

      validate_device() {
        device=$1

        if [ ! -e "$device" ]; then
          printf 'Configured LUKS device does not exist: %s\n' "$device" >&2
          exit 1
        fi

        if ! cryptsetup isLuks "$device"; then
          printf 'Configured device is not a LUKS device: %s\n' "$device" >&2
          exit 1
        fi

        if ! cryptsetup luksDump "$device" | grep -q '^Version:[[:space:]]*2$'; then
          printf 'Configured device is not LUKS2: %s\n' "$device" >&2
          exit 1
        fi
      }

      enroll_device() {
        device=$1

        printf 'Device: %s\n' "$device"
        printf 'TPM2 PCR policy: %s\n' "$pcrs"

        if [ "$add_recovery_key" -eq 1 ]; then
          systemd-cryptenroll "$device" --recovery-key
        fi

        systemd-cryptenroll "$device" --tpm2-device=auto --tpm2-pcrs="$pcrs"
      }

      for device in "''${devices[@]}"; do
        validate_device "$device"
      done

      if [ "$check_only" -eq 1 ]; then
        printf '%s\n' "Prerequisite check passed for all configured devices."
        exit 0
      fi

      if [ "$yes" -ne 1 ]; then
        printf '%s\n' "Refusing to mutate the LUKS header without --yes." >&2
        printf '%s\n' "Create a LUKS header backup before enrollment." >&2
        exit 1
      fi

      for device in "''${devices[@]}"; do
        enroll_device "$device"
      done
    '';
  };
in
{
  options.my.system.boot.tpm-luks-enroll = {
    enable = lib.mkEnableOption "manual TPM2 enrollment command for LUKS2 devices";

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "/dev/disk/by-uuid/3d2268fe-5c8f-42d8-a02d-d500f2df7319"
        "/dev/disk/by-uuid/65f6a6d1-31e0-4bf5-bf13-cbc7705a1163"
      ];
      description = "LUKS2 block devices to enroll with systemd-cryptenroll.";
    };

    pcrs = lib.mkOption {
      type = lib.types.str;
      default = "7+15:sha256=${zeroPcr15}";
      description = "TPM2 PCR policy passed to systemd-cryptenroll.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.devices != [ ];
        message = "Hosts with my.system.boot.tpm-luks-enroll.enable = true must set my.system.boot.tpm-luks-enroll.devices.";
      }
    ];

    environment.systemPackages = [ enrollLuksTpm2 ];
  };
}
