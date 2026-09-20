# 인증 준비와 복원

YubiKey는 Git 서명과 최초 설치·복구에만 사용한다. 평소 적용에는 LUKS 안의 root 전용 age identity를 사용한다. 1Password는 SSH 키 제공자이며 자동 계정 로그인은 구성하지 않는다.

## 기존 OS를 지우기 전

저장소의 `keys/`에는 기존 Git 서명 키의 공개키만 보관한다. fingerprint는 `A7F1956CD1A035A139BC7ABFCC740A29852C0E95`이다. 실제 카드가 서명과 암호화 subkey를 제공하는지 확인한다.

```sh
gpg --show-keys --with-fingerprint keys/signing.asc
gpg --card-status
```

개인 OpenPGP 키를 디스크로 내보내지 않는다. 사용 가능한 암호화 subkey가 없다면 디스크를 지우지 말고 카드의 키 구성을 먼저 해결한다.

전용 age identity를 생성하고 그 공개 수신자를 기록한다. 임시 평문은 private tmpfs 디렉터리에서만 다루고 shell tracing을 켜지 않는다.

```sh
nix develop
umask 077
secret_tmp=$(mktemp -d /run/user/"$(id -u)"/nix-secrets.XXXXXX)
age-keygen -o "$secret_tmp/age.key"
age-keygen -y "$secret_tmp/age.key" > secrets/recipient.txt
gpg --armor --encrypt \
  --recipient A7F1956CD1A035A139BC7ABFCC740A29852C0E95 \
  --output secrets/bootstrap/thinkpad-age-key.asc "$secret_tmp/age.key"
```

`.sops.yaml`의 수신자를 `secrets/recipient.txt`에 기록한 값으로 설정한다. `secrets/README.md`의 schema에 따라 임시 디렉터리에 토큰 YAML을 작성한다. GitHub, GitLab.com, git.jpi.app의 각 토큰과 사용자명을 준비하며 토큰을 명령 인자로 전달하지 않는다.

```sh
sops --encrypt --age "$(cat secrets/recipient.txt)" \
  --input-type yaml --output-type yaml \
  "$secret_tmp/tokens.yaml" > secrets/tokens.yaml
```

암호화 파일을 복호화해 출력하지 않고 유효성을 검사하고, GPG bootstrap 복원으로 얻은 age 공개 수신자가 기록한 값과 일치하는지 확인한다. 평문을 `git add`하지 않는다. 암호화된 두 파일, 공개 수신자, `.sops.yaml`만 커밋한다. 검증을 마치면 임시 디렉터리를 지운다.

실제 카드와 토큰이 없는 코드 검증에는 `tests/fixtures/`의 시험용 자료만 사용한다. 이 자료를 실제 인증 데이터로 설치하지 않는다.

## 설치한 NixOS에서 한 번 복원

먼저 bootstrap 구성의 공개 GPG 키와 사용자 agent가 배치된 상태로 h82에 로그인한다. 카드 확인이나 공개키 등록을 일반 재빌드의 필수 단계로 두지 않는다. GPG 복호화는 h82의 agent에서 수행하고 root installer에 결과를 파이프로 전달한다. 정확한 helper 호출은 `secrets/README.md`를 따른다.

복원 helper는 기대한 age 공개 수신자를 검증하고 `/var/lib/sops-nix/key.txt`를 root:root 0600으로 원자적으로 설치한다. 잘못된 identity는 기존 키를 덮어쓰지 않는다. 키가 준비되면 다음 명령으로 사용자 인증 파일까지 적용한다.

```sh
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
```

이후에는 같은 명령만 사용한다. YubiKey를 잠시 분리하거나 Secret Service·1Password가 잠겨 있어도 적용할 수 있다. gh/glab 인증 파일은 사용자 소유 0600 일반 파일이며 다음 적용에서 선언한 내용으로 복원된다. 수동 `gh auth login`이나 `glab auth login`을 후속 단계로 반복하지 않는다.

## Git 서명과 SSH

Git 커밋·태그 서명에는 YubiKey가 필요하다. PIN 자동 입력은 기존 Secret Service의 `service=gnupg-card-pin`, `username=<카드 serial>` 항목을 사용한다. 해당 캐시가 없거나 keyring이 잠겼으면 정상 pinentry로 요청한다. PIN 오류나 재시도 제한 경고가 있으면 자동 제출을 반복하지 않는다. 카드 touch 정책은 그대로 따른다.

1Password 앱에 한 번 로그인하고 Settings의 Developer 영역에서 SSH agent를 활성화한다. 저장소가 `IdentityAgent ~/.1password/agent.sock`과 `~/.config/1Password/ssh/agent.toml`의 키 선택을 배치한다. 앱 로그인·잠금 해제·SSH 승인은 사용자가 수행한다.

## 적용 후 확인

각 CLI의 auth status를 확인하고 필요한 호스트별 Git HTTPS 접근을 시험한다. 상태 출력이나 디버그 로그에 토큰이 포함되지 않게 주의한다. GPG 서명은 임시 Git 저장소에서 확인한다. SSH는 1Password를 로그인·해제한 상태에서 실제 키를 선택해 확인한다.
