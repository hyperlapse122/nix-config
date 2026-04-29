{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.dev.playwright;

  # pietdevries94/playwright-web-flake 가 노출하는 패키지를 사용한다.
  # nixpkgs 의 playwright-driver 대신 이 flake 의 빌드를 쓰는 이유:
  #   - nixpkgs 의 release 주기보다 자주 갱신되어 npm `@playwright/test` 와 버전 동기화가 쉽다.
  #   - flake 태그(예: github:pietdevries94/playwright-web-flake/1.x.y)로 정확한 버전 핀이 가능.
  # 노출 패키지:
  #   - playwright-test    : `playwright` CLI 바이너리
  #   - playwright-driver  : driver (`.browsers` attribute 로 사전 빌드 브라우저 접근)
  pwPkgs = inputs.playwright.packages.${pkgs.stdenv.hostPlatform.system};

  # Playwright 런타임 환경변수 — NixOS Wiki (https://wiki.nixos.org/wiki/Playwright) 기준.
  # PLAYWRIGHT_BROWSERS_PATH                   — 브라우저 경로 (npm 의 ~/.cache/ms-playwright 대신 사용).
  #                                              설정해두면 `playwright install` 단계 자체를 건너뛴다.
  # PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS — playwright 의 distro 의존성 검사 비활성화.
  #                                              nixpkgs 의 wrap 이 이미 모든 lib 을 store path 로 묶어두므로
  #                                              시스템 경로 검증은 의미가 없다.
  # PLAYWRIGHT_HOST_PLATFORM_OVERRIDE          — 호스트 플랫폼 식별자 강제 지정.
  #                                              Wiki 는 "Seems like it is not needed?" 주석을 달아두었지만
  #                                              일부 버전 / CI 경로에서 distro 자동 감지가 실패할 때
  #                                              검증 코드가 거치는 분기 자체를 회피하기 위해 명시.
  # PLAYWRIGHT_NODEJS_PATH                     — playwright 가 사용할 node 바이너리 경로.
  #                                              npm-installed playwright 가 spawn 하는 자식 프로세스에서
  #                                              nixpkgs 와 일치하는 node 가 쓰이도록 핀.
  sessionVars = {
    PLAYWRIGHT_BROWSERS_PATH = "${pwPkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04";
    PLAYWRIGHT_NODEJS_PATH = "${pkgs.nodejs}/bin/node";
  };
in
{
  options.my.dev.playwright = {
    enable = lib.mkEnableOption "Playwright 드라이버 + 브라우저 + 런타임 환경변수 (pietdevries94/playwright-web-flake)";
  };

  config = lib.mkIf cfg.enable {
    # playwright-test           — `playwright` CLI 바이너리 (flake#playwright-test).
    # playwright-driver         — patchelf 처리된 playwright 드라이버 (flake#playwright-driver).
    #                             system lib 누락 경고의 대상이 되는 .so 들을 store path 로 이미 wrap 해둠.
    # playwright-driver.browsers — chromium / firefox / webkit 사전 빌드 바이너리 (driver 와 같은 wrap 적용).
    #
    # 버전 동기화 주의: 프로젝트 package.json 의 "@playwright/test" 와 flake 의 playwright 버전이
    # 일치해야 한다. 불일치 시 npm 측을 다운그레이드하거나 flake input 을 해당 태그로 핀:
    #   inputs.playwright.url = "github:pietdevries94/playwright-web-flake/1.x.y";
    # 사용 가능한 태그: https://github.com/pietdevries94/playwright-web-flake/tags
    home.packages = [
      pwPkgs.playwright-test
      pwPkgs.playwright-driver
      pwPkgs.playwright-driver.browsers
    ];

    # 로그인 셸 (~/.profile, ~/.zshenv) — 터미널 / SSH / TTY 에서 spawn 한 자식 프로세스가 받는다.
    home.sessionVariables = sessionVars;

    # systemd --user 가 관리하는 모든 유닛에 주입 — VS Code 통합 터미널, KDE Plasma 가 띄우는 GUI 앱
    # (예: 데스크톱에서 launch 한 Electron 기반 IDE) 등에서도 동일하게 적용되도록.
    # env.nix 의 동일 패턴 참고.
    systemd.user.sessionVariables = sessionVars;
  };
}
