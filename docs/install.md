# ThinkPad 새 설치

대상은 `ThinkPad X1 Carbon Gen 11`, 구성 이름은 `ThinkPad-X1-Carbon-Gen-11`이다. 이 절차는 기존 Fedora와 내부 NVMe의 모든 데이터를 지운다. 평소 설정 변경에는 이 절차를 반복하지 않는다.

## 지우기 전에 준비

1. [인증 복원 준비](provisioning.md)를 기존 시스템에서 완료한다. 공개 GPG 키, 암호화 토큰, YubiKey로 암호화한 age identity를 저장소에 저장하고 복호화를 확인한다.
2. 저장소의 변경을 원격에 올리고, 설치 환경에서 SSH 인증 없이 HTTPS로 clone할 수 있는지 확인한다. 별도 매체에 clone을 보관해도 된다.
3. LUKS 복구 암호를 정한다. 저장소나 대상 디스크에 평문으로 저장하지 않는다. 기존 Secure Boot 서명 bundle을 재사용한다면 외부 암호화 백업도 준비한다.
4. NixOS x86_64 설치 USB를 준비한다. 설치 매체가 현재 펌웨어의 Secure Boot 신뢰에 포함되지 않으면 Secure Boot를 일시적으로 끈다. 이때 모든 인증서나 dbx를 지우지 않는다.

YubiKey가 유일한 복원 수단이고 그것을 잃어버리면 암호화된 age identity를 복원할 수 없다. 필요하면 별도 GPG 수신자나 오프라인 복원본을 지우기 전에 준비한다.

## 설치 매체에서 디스크 확인

이후 명령은 설치 매체의 터미널에서 실행한다. 네트워크 연결을 확인하고 저장소를 가져온다.

```sh
git clone https://github.com/hyperlapse122/nix-config.git
cd nix-config
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
sudo dmidecode -s system-version
```

`hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix`에 선언한 by-id 경로가 설치할 내부 KIOXIA 512 GB 디스크인지 확인한다. 다른 장비나 디스크라면 먼저 선언을 수정하고 평가한다. `/dev/nvme0n1`이라는 순서만으로 대상을 결정하지 않는다.

## 디스크 초기화와 bootstrap 설치

아래 disko 명령이 **전체 대상 디스크를 삭제한다**. 파일의 대상 경로와 `lsblk` 출력이 일치할 때만 실행한다. lock의 disko를 사용한다.

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run .#disko -- \
  --mode disko hosts/ThinkPad-X1-Carbon-Gen-11/disko.nix
sudo nixos-install --flake .#ThinkPad-X1-Carbon-Gen-11-bootstrap --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd h82'
```

LUKS 암호를 입력하고 잃어버리지 않게 보관한다. 레이아웃은 2 GiB ESP와 LUKS2 안의 Btrfs root/home/nix/log subvolume이다. 디스크 swap과 최대절전은 구성하지 않는다.

첫 재부팅은 Secure Boot를 끈 상태에서 LUKS 암호를 입력한다. Plasma 로그인과 `sudo -v`를 확인한다. bootstrap에는 실제 토큰 복호화와 Secure Boot 개인키가 필요하지 않다.

## 로컬 복호화 키와 서명 키 준비

설치한 NixOS에서 HTTPS로 저장소를 다시 가져오고 [프로비저닝](provisioning.md)의 age identity 복원 절차를 실행한다. 복원은 최초 설치·복구에만 필요하다.

```sh
sudo sbctl create-keys
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
sudo sbctl verify
```

기존 서명 bundle을 복원하는 경우에는 `create-keys` 대신 백업한 `/var/lib/sbctl` 전체를 root 전용 권한으로 복원한다. 재빌드는 사용자 설정, CLI 인증 파일, 서명된 부팅 파일을 함께 배치한다. `sbctl verify` 출력에서 Lanzaboote가 관리하는 EFI 실행 파일을 확인한다. 외부 커널 payload는 해시로 검증하는 구조이므로 ESP의 모든 파일이 PE 서명을 가진다고 가정하지 않는다.

## Secure Boot 등록

펌웨어 설정에서 사용자 키를 등록할 수 있도록 Setup Mode로 전환한다. Lenovo 펌웨어의 메뉴와 변경 내용을 확인하고 dbx를 삭제하지 않는다. Microsoft 인증서는 호환성을 위해 유지한다.

```sh
sudo sbctl status
sudo sbctl enroll-keys --microsoft
```

펌웨어에서 Secure Boot를 활성화하고 재부팅한다. 설치한 NixOS가 정상 부팅된 뒤 확인한다.

```sh
bootctl status --no-pager
sudo sbctl status
```

Secure Boot enabled/user 상태와 NixOS 부팅을 확인하기 전에는 TPM 등록으로 넘어가지 않는다. 새 시스템에서는 Fedora shim을 그대로 이용하지 않는다.

## TPM2 자동 해제

다음 명령의 장치는 disko가 만든 **LUKS 파티션**이며 디스크 전체가 아니다. 먼저 확인한다.

```sh
lsblk -o NAME,PATH,FSTYPE,PARTLABEL,MOUNTPOINTS
sudo cryptsetup luksDump /dev/disk/by-partlabel/disk-main-luks
```

최종 Secure Boot 상태에서 PCR7 SHA256에 등록한다. 기존 복구 암호 슬롯은 지우지 않는다. 이 구성은 TPM PIN이나 YubiKey를 부팅에 요구하지 않는다.

```sh
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks \
  --tpm2-device=auto --tpm2-pcrs=7:sha256 --tpm2-with-pin=no
```

별도로 pcrlock을 구성했던 시스템이라면 자동 발견된 policy 파일을 적용하지 않도록 현재 systemd 매뉴얼과 `--tpm2-pcrlock` 옵션을 확인한다. 이 저장소는 pcrlock policy를 생성하지 않는다.

재부팅해 자동 해제를 확인하고 복구 암호로도 부팅할 수 있는지 확인한다. PCR7은 Secure Boot 정책에 바인딩하며 특정 커널·루트 데이터의 무결성을 보장하지 않는다. Microsoft 인증서를 유지하면 그 인증서로 서명된 다른 부팅 경로도 신뢰 범위에 들어간다.

등록 후 LUKS header와 `/var/lib/sbctl`을 암호화해 외부 매체에 백업한다. header 백업에는 당시 키 슬롯이 들어 있으므로 오래된 백업도 민감 자료로 취급한다. [복구 가이드](recovery.md)와 [검증표](verification.md)를 따른다.
