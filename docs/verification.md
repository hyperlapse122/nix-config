# 검증

## 저장소 검사

```sh
nix fmt -- --ci
nix flake check --no-build
nix flake check
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
```

VM 검사는 `/dev/kvm` 접근이 가능한 Linux에서 실행한다. 임시 VM 디스크만 사용하며 호스트 NVMe에는 접근하지 않는다. `auth-provisioning`은 카드·로그인 세션 없는 인증 적용, 동일 세대 재적용, 키 누락·손상 실패와 복원 재시도, 삭제된 CLI 파일 복구를 검사한다. `boot-layout`은 임시 디스크의 LUKS 레이아웃과 부팅을 검사한다. PIN proxy와 복원 helper 검사는 가짜 PIN·토큰·시험용 키만 사용한다.

## 실제 설치 후 확인

아래 항목은 VM이나 빌드 성공으로 대체할 수 없다. 실제 실행자가 결과를 기록한다.

- [ ] 설치 전에 실제 YubiKey로 bootstrap age identity를 복원할 수 있다.
- [ ] Secure Boot enabled/user 상태로 설치된 NixOS가 부팅된다.
- [ ] TPM으로 LUKS가 자동 해제된다.
- [ ] TPM을 사용할 수 없는 경우 복구 암호로 부팅할 수 있다.
- [ ] 새 부팅 세대와 이전 세대가 각각 부팅된다.
- [ ] 기본 Plasma 로그인, Wi-Fi, Bluetooth, 오디오, s2idle 절전·복귀가 동작한다.
- [ ] YubiKey와 1Password 세션 없이 재빌드가 성공한다.
- [ ] GitHub·GitLab.com·git.jpi.app 인증이 각 호스트에서 유효하다.
- [ ] 임시 Git 저장소의 서명 커밋과 태그를 `git verify-commit`·`git verify-tag`로 검증한다.
- [ ] 1Password 계정 로그인과 SSH agent 활성화 후 선택한 키로 SSH 연결된다.

자동화는 실제 노트북을 재설치하지 않는다. 저장소 검증 결과와 이 체크리스트의 실행 여부는 별도로 보고한다.
