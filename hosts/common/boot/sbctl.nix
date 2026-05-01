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
in
{
  options.my.system.boot.sbctl = {
    enable = lib.mkEnableOption "sbctl Secure Boot key creation and enrollment";
  };

  config = lib.mkIf cfg.enable {
    my.system.boot.systemd-boot.enable = true;

    environment.systemPackages = with pkgs; [ sbctl ];

    systemd.services.sbctl-create-and-enroll-keys = {
      description = "Create and enroll Secure Boot keys with sbctl";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
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

        for var in /sys/firmware/efi/efivars/{PK,KEK,db,dbx}-*; do
          if [ -e "$var" ]; then
            ${pkgs.e2fsprogs}/bin/chattr -i "$var"
          fi
        done

        firmware_builtins=""
        if [ -e /sys/firmware/efi/efivars/dbDefault-8be4df61-93ca-11d2-aa0d-00e098032b8c ]; then
          firmware_builtins="db"
        fi
        if [ -e /sys/firmware/efi/efivars/KEKDefault-8be4df61-93ca-11d2-aa0d-00e098032b8c ]; then
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
      '';
    };
  };
}
