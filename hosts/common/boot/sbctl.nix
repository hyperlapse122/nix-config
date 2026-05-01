{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.boot.sbctl;

  keyDirs = [
    "/var/lib/sbctl/keys/PK"
    "/var/lib/sbctl/keys/KEK"
    "/var/lib/sbctl/keys/db"
  ];

  immutableVarsFile = "/var/lib/sbctl/immutable-efivars.list";

  efivarfsGuid = "8be4df61-93ca-11d2-aa0d-00e098032b8c";
in
{
  options.my.system.boot.sbctl = {
    enable = lib.mkEnableOption "sbctl Secure Boot key creation and enrollment";
  };

  config = lib.mkIf cfg.enable {
    my.system.boot.systemd-boot.enable = true;

    environment.systemPackages = with pkgs; [
      jq
      sbctl
    ];

    boot.loader.systemd-boot.extraInstallCommands = lib.mkAfter ''
      missing_keys=0
      for dir in ${lib.concatStringsSep " " keyDirs}; do
        key_name=''${dir##*/}
        if [ ! -f "$dir/$key_name.key" ]; then
          missing_keys=1
        fi
      done

      if [ "$missing_keys" -eq 1 ]; then
        ${pkgs.sbctl}/bin/sbctl create-keys
      fi

      ${pkgs.coreutils}/bin/install -d -m 0700 /var/lib/sbctl
      status_json="$(${pkgs.sbctl}/bin/sbctl status --json)"
      setup_mode="$(printf '%s\n' "$status_json" | ${pkgs.jq}/bin/jq -r '.setup_mode')"

      if [ "$setup_mode" = true ]; then
        immutable_vars_tmp="$(${pkgs.coreutils}/bin/mktemp)"
        if [ -f ${immutableVarsFile} ]; then
          ${pkgs.coreutils}/bin/cat ${immutableVarsFile} >> "$immutable_vars_tmp"
        fi

        for var in /sys/firmware/efi/efivars/{PK,KEK,db,dbx}-*; do
          if [ -e "$var" ]; then
            attr_line="$(${pkgs.e2fsprogs}/bin/lsattr -d "$var" 2>/dev/null || true)"
            attrs=''${attr_line%% *}
            case "$attrs" in
              *i*) printf '%s\n' "$var" >> "$immutable_vars_tmp" ;;
            esac
            ${pkgs.e2fsprogs}/bin/chattr -i "$var"
          fi
        done

        ${pkgs.coreutils}/bin/sort -u "$immutable_vars_tmp" > ${immutableVarsFile}

        restore_immutable_vars() {
          while IFS= read -r var; do
            if [ -n "$var" ] && [ -e "$var" ]; then
              ${pkgs.e2fsprogs}/bin/chattr +i "$var"
            fi
          done < ${immutableVarsFile}
        }
        trap restore_immutable_vars EXIT

        firmware_builtins=""
        if [ -e /sys/firmware/efi/efivars/dbDefault-${efivarfsGuid} ]; then
          firmware_builtins="db"
        fi
        if [ -e /sys/firmware/efi/efivars/KEKDefault-${efivarfsGuid} ]; then
          if [ -n "$firmware_builtins" ]; then
            firmware_builtins="$firmware_builtins,KEK"
          else
            firmware_builtins="KEK"
          fi
        fi

        if [ -n "$firmware_builtins" ]; then
          ${pkgs.sbctl}/bin/sbctl enroll-keys --microsoft --firmware-builtin="$firmware_builtins"
        else
          ${pkgs.sbctl}/bin/sbctl enroll-keys --microsoft
        fi
      else
        printf '%s\n' "Skipping sbctl key enrollment because the system is not in Setup Mode."
      fi

      boot_mount=${config.boot.loader.efi.efiSysMountPoint}
      verify_json="$(${pkgs.sbctl}/bin/sbctl verify --json || true)"
      if [ -n "$verify_json" ]; then
        printf '%s\n' "$verify_json" \
          | ${pkgs.jq}/bin/jq -r --arg boot_mount "$boot_mount" '
              .[]
              | select(.is_signed != -1)
              | .file_name
              | select(startswith($boot_mount + "/"))
            ' \
          | while IFS= read -r file; do
              if [ -n "$file" ] && [ -e "$file" ]; then
                ${pkgs.sbctl}/bin/sbctl sign --save "$file"
              fi
            done
      fi
    '';

    systemd.services.sbctl-restore-efivar-immutability = {
      description = "Restore Secure Boot EFI variable immutability";
      wantedBy = [ "multi-user.target" ];
      after = [ "sys-firmware-efi-efivars.mount" ];
      unitConfig.ConditionPathExists = "/sys/firmware/efi/efivars";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        if [ -f ${immutableVarsFile} ]; then
          while IFS= read -r var; do
            if [ -n "$var" ] && [ -e "$var" ]; then
              attr_line="$(${pkgs.e2fsprogs}/bin/lsattr -d "$var" 2>/dev/null || true)"
              attrs=''${attr_line%% *}
              case "$attrs" in
                *i*) ;;
                *) ${pkgs.e2fsprogs}/bin/chattr +i "$var" ;;
              esac
            fi
          done < ${immutableVarsFile}
        fi
      '';
    };
  };
}
