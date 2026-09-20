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

부팅이 불가능하면 설치 USB에서 LUKS를 열고 Btrfs root와 ESP를 올바르게 mount한다. disko의 포맷 모드를 재실행하지 않는다. `nixos-enter`로 들어가거나 target root에 `nixos-install`을 사용할 때 저장소 구성과 mount가 일치하는지 확인한다.

## Secure Boot 서명 키 유실

`/var/lib/sbctl`의 외부 암호화 백업을 복원하고 파일 소유권과 권한을 확인한다. 재빌드해 부팅 파일을 다시 서명한다. 백업이 없다면 새 bundle을 생성하고 UEFI 키 등록부터 다시 진행한다. TPM enrollment도 새 Secure Boot 정책에서 갱신한다.

LUKS 복구 자료를 잠긴 대상 디스크에만 두거나, 그 디스크의 TPM 자동 해제를 유일한 복구 수단으로 삼지 않는다.

## YubiKey 분실·교체

기존 설치의 로컬 age identity가 남아 있으면 재빌드는 계속 가능하다. Git 서명은 중단된다. 대체 서명 키의 공개키·fingerprint를 구성에 반영하고 관련 서비스의 검증 키도 갱신한다.

재설치에서 기존 bootstrap 암호문을 복원하려면 등록된 다른 수신자나 별도 오프라인 백업이 필요하다. 모두 없다면 서비스 토큰을 재발급하고 새 age identity와 bootstrap 암호문을 만든다. 분실 카드의 암호문이 새 카드로 자동 복호화되는 것은 아니다.

새 카드의 암호화 공개키를 확인하고 age identity의 bootstrap 암호문을 새 수신자로 갱신한다. 실제 복원을 검증한 뒤 이전 복구 자료의 보관·폐기를 결정한다. PIN 자동 입력은 기존 Secret Service 캐시를 별도로 갱신하며 재빌드와 연결하지 않는다.

## 토큰·age identity 교체

토큰 변경은 SOPS로 암호화된 토큰 파일을 편집하고 재빌드한다. 로컬 age identity가 유출되었다면 새 identity를 생성하고 모든 암호문을 새 수신자로 재암호화한다. bootstrap 암호문과 로컬 identity도 함께 갱신한다. 저장소의 과거 암호문이 남으므로 이미 노출될 수 있는 서비스 토큰은 공급자에서 폐기하고 재발급해야 한다.
