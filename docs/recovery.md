# 업데이트와 복구

## 평소 적용

```sh
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
```

이 명령은 디스크를 포맷하거나 TPM·UEFI 키를 등록하지 않는다. 로컬 age identity가 준비되어 있으면 YubiKey, 데스크톱 keyring, 1Password 로그인 상태에 의존하지 않는다. 카드가 없어도 재빌드는 가능하지만 실제 Git 서명은 불가능하다.

입력 갱신은 `nix flake update`로 수행한다. `flake.lock` diff를 검토하고 `nix flake check`와 두 호스트 빌드를 통과시킨 뒤 적용한다. 원격 토큰의 유효성은 적용 후 각 CLI로 확인한다. 인증 배치 성공이 서버에서의 토큰 유효성을 보장하지는 않는다.

## 실패한 인증 적용

```sh
systemctl status sops-install-secrets.service --no-pager
sudo journalctl -u sops-install-secrets.service -b --no-pager
```

로그를 공유하기 전 비밀정보가 없는지 확인한다. 로컬 identity가 없거나 손상되었으면 [최초 복원](provisioning.md)을 다시 수행하고 같은 재빌드 명령을 실행한다. CLI 설정 파일을 수동으로 삭제한 경우도 같은 명령으로 복구한다. gh/glab 관리 파일의 로컬 변경은 다음 성공한 적용에서 덮어쓴다.

NixOS switch 실패는 전체 시스템 변경을 되돌리는 트랜잭션이 아니다. 토큰 게시 중 일부 파일만 갱신되었다면 문제를 해결하고 같은 명령을 다시 실행한다. 오류를 무시하고 프로비저닝 완료로 처리하지 않는다.

## 부팅 세대 롤백

부팅 메뉴에서 지원되는 이전 NixOS 세대를 선택한다. 부팅 가능한 상태에서 시스템을 되돌리려면 다음을 사용한다.

```sh
sudo nixos-rebuild switch --rollback
```

부팅 세대 수는 5개로 시작한다. 오래된 세대를 정리하기 전에 현재 세대가 Secure Boot로 부팅되는지 확인한다. firmware/db/dbx 변경으로 이전 세대의 신뢰 조건이 달라진 경우에는 rollback만으로 해결되지 않는다.

## TPM 해제 실패

펌웨어나 Secure Boot 정책이 바뀌면 자동 해제가 실패할 수 있다. LUKS 복구 암호로 부팅하고 원인이 의도한 변경인지 확인한다. 정상적인 최종 Secure Boot 상태를 확인한 후 TPM 등록을 갱신한다.

```sh
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks \
  --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7:sha256 --tpm2-with-pin=no
```

`--wipe-slot=tpm2`는 TPM 슬롯에만 사용한다. 복구 암호 슬롯을 삭제하지 않는다. 새 자동 해제와 암호 해제를 확인한 뒤 LUKS header 외부 백업을 갱신한다.

## LUKS와 Secure Boot 자료 백업

설치 직후와 TPM 슬롯을 갱신한 뒤에는 외부 매체를 연결하고 실제 mount인지 확인한다.
아래의 `backup_mount`와 `backup_dir`은 대상 디스크가 아닌 외부 매체의 경로로 바꾼다.
백업 파일은 GPG 수신자로 다시 암호화하므로 매체 자체의 암호화 여부와 별개로 보관할 수
있다. 평문 중간 파일은 `/run/user`의 임시 파일시스템에만 둔다.

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

LUKS header에는 당시 keyslot이 포함되므로 두 `.asc` 파일 모두 외부 매체에 보관하고,
header 백업이 유출된 것으로 의심되면 복구 암호와 서비스 자격 증명을 교체한다.

부팅이 불가능하면 설치 USB에서 disko의 포맷 모드를 재실행하지 말고, 아래처럼 선언된
레이아웃으로만 기존 파일시스템을 연다. 설치 USB에서 네트워크가 되면 저장소를 target
root의 `/tmp/nix-config`에 다시 clone하고, 네트워크가 없으면 외부 매체에서 같은 경로로
복사한다.

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
sudo nixos-enter --root /mnt
```

`nixos-enter`가 필요한 `/dev`, `/sys`, `/proc` bind mount를 자체적으로 만든다.
`nixos-rebuild boot`을 실행하기 전에 `/var/lib/sbctl`을 복원해야 하며, 서명된 부팅
복원 명령은 아래와 같다.

## Secure Boot 서명 키 유실

외부 암호화 백업을 연결한 뒤 `/var/lib/sbctl`을 복원하고, 백업 파일의 소유권과
권한을 확인한다. 실행 중인 설치에서 복원할 때는 다음처럼 보관한 bundle을 풀고 다음
부팅 세대를 다시 서명한다.

```sh
set -o pipefail
gpg --decrypt /path/to/sbctl.tar.asc | \
  sudo tar --xattrs --acls --numeric-owner -xpf - -C /var/lib
sudo chown -R root:root /var/lib/sbctl
sudo chmod -R go-rwx /var/lib/sbctl
sudo nixos-rebuild boot --flake .#ThinkPad-X1-Carbon-Gen-11
```

설치 USB에서 복원하는 경우에는 먼저 위의 LUKS·Btrfs·ESP mount 절차를 수행한 뒤,
외부 매체의 `sbctl.tar.asc`를 `/mnt/var/lib`에 복호화해 풀고 `nixos-enter` 안에서
`/tmp/nix-config`의 같은 `nixos-rebuild boot` 명령을 실행한다.
백업이 없다면 새 bundle을 생성하고 UEFI 키 등록부터 다시 진행한다. TPM enrollment도
새 Secure Boot 정책에서 갱신한다.

LUKS 복구 자료를 잠긴 대상 디스크에만 두거나, 그 디스크의 TPM 자동 해제를 유일한 복구 수단으로 삼지 않는다.

## YubiKey 분실·교체

기존 설치의 로컬 age identity가 남아 있으면 재빌드는 계속 가능하다. Git 서명은 중단된다. 대체 서명 키의 공개키·fingerprint를 구성에 반영하고 관련 서비스의 검증 키도 갱신한다.

재설치에서 기존 bootstrap 암호문을 복원하려면 등록된 다른 수신자나 별도 오프라인 백업이 필요하다. 모두 없다면 서비스 토큰을 재발급하고 새 age identity와 bootstrap 암호문을 만든다. 분실 카드의 암호문이 새 카드로 자동 복호화되는 것은 아니다.

새 카드의 암호화 공개키를 확인하고 age identity의 bootstrap 암호문을 새 수신자로 갱신한다. 실제 복원을 검증한 뒤 이전 복구 자료의 보관·폐기를 결정한다. PIN 자동 입력은 기존 Secret Service 캐시를 별도로 갱신하며 재빌드와 연결하지 않는다.

## 토큰·age identity 교체

토큰 변경은 SOPS로 암호화된 토큰 파일을 편집하고 재빌드한다. 로컬 age identity가 유출되었다면 새 identity를 생성하고 모든 암호문을 새 수신자로 재암호화한다. bootstrap 암호문과 로컬 identity도 함께 갱신한다. 저장소의 과거 암호문이 남으므로 이미 노출될 수 있는 서비스 토큰은 공급자에서 폐기하고 재발급해야 한다.
