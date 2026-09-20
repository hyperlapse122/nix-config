# Nix Config

ThinkPad X1 Carbon Gen 11용 NixOS Flake. nixos-unstable을 lock으로 고정하고 기본 Plasma 환경을 사용한다.

```sh
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
```

최초 설치·키 복원을 마친 뒤에는 이 명령이 시스템, Home Manager, gh/glab 인증 파일을 함께 적용한다. YubiKey는 Git 서명과 최초 secret 복원에 사용하며, 일반 재빌드는 LUKS 내부의 로컬 age identity를 사용한다. 1Password 로그인은 수동이며 SSH agent 설정은 선언한다.

## 포함하는 환경

zsh, Git, Ghostty, Claude Code, Codex, omp, gh, glab, 1Password GUI, Google Chrome. 코딩 에이전트의 로그인·설정·플러그인은 이전하지 않는다. macOS와 NixOS 이외 Linux는 후속 범위다.

## 설치와 운영

- [새 설치](docs/install.md): 내부 NVMe 초기화, bootstrap, Secure Boot, TPM2 등록
- [인증 준비와 복원](docs/provisioning.md): 저장소 암호문 준비와 YubiKey를 이용한 최초 복원
- [업데이트와 복구](docs/recovery.md): 실패 재시도, 롤백, TPM·카드·서명 키 복구
- [검증](docs/verification.md): 자동 검사와 실제 장비 확인 항목
- [Secret 파일 규약](secrets/README.md)

`ThinkPad-X1-Carbon-Gen-11-bootstrap` 출력은 개인키와 토큰 없이 설치할 수 있다. 최종 출력도 평문 secret 없이 평가·빌드할 수 있지만, 실제 적용에는 로컬 age identity와 암호화 토큰, Secure Boot 서명 bundle이 필요하다. 저장소에 실제 토큰과 bootstrap 암호문을 준비하기 전에는 인증 복원이 완료된 상태가 아니다.

## 개발 검사

```sh
nix flake check
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
nix fmt
```

설치·enrollment는 일회성 명시적 작업이다. 검증을 위해 현재 호스트에서 disko나 rebuild switch를 실행하지 않는다.
