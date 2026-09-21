---
title: Claude Code Managed Defaults - Plan
type: feat
date: 2026-09-21
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
topic: claude-managed-defaults
origin: https://github.com/hyperlapse122/nix-config/issues/19
---

# Claude Code Managed Defaults - Plan

## Goal Capsule

- **Objective:** h82 가 새 기기나 새 세대에서 `claude` 를 실행하면 손으로 설정하지 않아도 의도한 모델과 추론 강도로 바로 작업할 수 있다.
- **Means:** Claude Code 설정을 managed settings 티어에 선언하고 해당 모듈을 `claude` 로 정리한다 (KTD1, KTD2).
- **Authority:** 이 계획 > 이슈 #19 본문. 이슈가 제안한 `~/.claude/settings.json` 경로는 KTD1 이 대체한다.
- **Execution profile:** 표준 구현. 코드 변경 후 `nix flake check` 와 두 호스트 빌드로 검증한다. 호스트 activation(`nixos-rebuild switch`)은 실행하지 않는다.
- **Stop conditions:** managed settings 티어가 `model` 또는 `effortLevel` 키를 무시한다는 증거가 나오면 멈추고 보고한다. 하드웨어 설치나 파티셔닝이 필요해지면 멈춘다.
- **Finishes and ships:** `ce-work` 가 구현하고, 상위 파이프라인이 PR 로 배송한다.

---

## Product Contract

### Summary

Claude Code 의 기본 모델과 추론 강도를 NixOS managed settings 로 선언한다. 기존 `agent-memory` 모듈은 Claude Code 설정 전반을 담게 되므로 `claude` 로 이름을 바꾸고, 함께 들어 있던 Gemini/Antigravity 설정은 별도 모듈로 분리한다. 회귀 검사와 문서도 새 이름과 새 설정에 맞춘다.

### Problem Frame

현재 `claude-code` 는 패키지로만 설치되고, 모델과 추론 강도는 사용자가 매번 손으로 맞춘다. 기기를 다시 설치하거나 홈 디렉터리를 잃으면 그 설정이 사라진다. 이 저장소의 목적은 환경을 선언적으로 재현하는 것이므로 이 두 값도 선언 대상이다. 한편 `agent-memory` 라는 이름은 메모리 스위치만 담던 시절의 이름이라, 모델 기본값이 들어오면 모듈 내용과 이름이 어긋난다.

### Requirements

**Claude Code 기본값**

- R1. `/etc/claude-code/managed-settings.json` 이 `model` 을 `opus[1m]` 로 선언한다.
- R2. 같은 파일이 최상위 `effortLevel` 을 `medium` 으로 선언한다.
- R3. 같은 파일이 기존 `autoMemoryEnabled = false` 를 그대로 유지한다.

**모듈 구조**

- R4. NixOS 모듈은 `modules/nixos/claude.nix` 에 있고, 호스트 설정이 그 경로를 import 한다.
- R5. Claude Code 용 Home Manager 설정(`CLAUDE_CODE_DISABLE_AUTO_MEMORY`)은 `home/h82/claude.nix` 에 있다.
- R6. Gemini/Antigravity 설정은 `home/h82/gemini.nix` 에 있고, `home/h82/default.nix` 가 두 모듈을 모두 import 한다.
- R7. `agent-memory` 라는 이름의 모듈, 테스트, 체크는 저장소에 남지 않는다.

**검증과 문서**

- R8. `flake.nix` 가 `claude` 와 `gemini` 체크를 등록하고, 각 체크가 해당 모듈의 생성 결과를 검사한다.
- R9. `claude` 체크는 R1, R2, R3, R5 를 각각 단언하고(R2 는 최상위 `effortLevel`), Home Manager 가 `~/.claude/settings.json` 을 관리하지 않음을 계속 단언한다.
- R10. `README.md` 의 "Coding-agent logins, settings, and plugins are not migrated" 문장이 관리되는 기본값을 반영하도록 좁혀진다.
- R11. `docs/provisioning.md` 와 `docs/verification.md` 가 새 모듈 이름, 새 체크 이름, 새 설정을 반영한다.

### Key Decisions

- managed settings 티어에 선언한다 (session-settled: user-directed — chosen over Home Manager 가 `~/.claude/settings.json` 을 쓰는 방식: Claude Code 가 그 파일을 런타임에 재작성하므로 read-only store symlink 를 놓을 수 없다). Governs R1, R2, R3.
- 모듈 이름을 `claude` 로 바꾼다 (session-settled: user-directed — chosen over `agent-memory` 이름 유지: 모듈이 메모리 스위치를 넘어 Claude Code 설정 전반을 담는다). Governs R4, R5, R7.

### Scope Boundaries

**포함**

- h82 사용자와 `ThinkPad-X1-Carbon-Gen-11` 호스트(production, bootstrap).

**Deferred to Follow-Up Work**

- 다른 사용자나 다른 호스트로 모듈을 공유하는 일반화. 지금은 사용자와 호스트가 하나뿐이다.
- Claude Code 의 다른 설정(hooks, statusLine, 플러그인)의 선언적 관리.

**Outside this product's identity**

- 코딩 에이전트 로그인과 인증 자격 증명의 마이그레이션.

### Success Criteria

- `nix flake check` 와 두 호스트 빌드가 통과한다.
- 새 체크가 mutation testing 에서 각 단언마다 실패한다.

### Sources

- `modules/nixos/agent-memory.nix`: 현재 managed settings 선언.
- `home/h82/agent-memory.nix`: Claude 환경변수와 Gemini 설정이 한 모듈에 섞여 있는 현재 상태.
- `tests/agent-memory.nix`: mutation-safe 단언 패턴(null 보호, 명시적 `if ... exit 1`).
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`
- `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`
- 설치된 claude-code 2.1.278 바이너리 문자열: 최상위 `effortLevel` 은 "Persisted effort level for supported models.", 모델별 `modelSettings.<model>.effortLevel` 은 "Persisted effort level for this model." 로 기술된다. 최상위 키가 모델 세대에 묶이지 않는다.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **managed settings 에 `model` 과 `effortLevel` 을 추가한다**: `environment.etc."claude-code/managed-settings.json"` 의 attrset 에 두 키를 더한다 (session-settled: user-directed — chosen over Home Manager 가 `~/.claude/settings.json` 을 작성: Claude Code 가 그 파일을 소유하고 재작성한다). Governs R1, R2, R3.
- KTD2. **모듈을 `claude` 와 `gemini` 로 분리한다**: `modules/nixos/agent-memory.nix` 는 `modules/nixos/claude.nix` 로, `home/h82/agent-memory.nix` 는 Claude 부분만 남긴 `home/h82/claude.nix` 와 Gemini 부분을 옮긴 `home/h82/gemini.nix` 로 나눈다 (session-settled: user-directed — chosen over 한 모듈에 두 에이전트를 유지: AGENTS.md 의 "각 모듈은 하나의 관심사" 규칙과 새 이름이 맞지 않는다). Governs R4, R5, R6, R7.
- KTD3. **effort 는 최상위 `effortLevel` 로 선언한다**: 설치된 claude-code 2.1.278 에는 최상위 `effortLevel`("Persisted effort level for supported models.")과 모델별 `modelSettings.<canonical>.effortLevel`("Persisted effort level for this model.")이 모두 있다. 최상위 키를 고르면 `opus` 별칭이 다음 세대를 가리켜도 선언이 그대로 유효하다. 모델별 키는 별칭과 canonical 이름이 어긋나는 순간 조용히 무효가 되고 체크도 그 어긋남을 잡지 못한다. `model` 은 별칭 `opus[1m]` 을 그대로 쓴다. Governs R1, R2.
- KTD4. **체크도 모듈을 따라 둘로 나눈다**: `tests/claude.nix` 와 `tests/gemini.nix` 를 만들고 `flake.nix` 에 `claude`, `gemini` 로 등록한다. 기존 mutation-safe 패턴(`lib.optionalString` 으로 null 을 셸 분기로 내리는 방식)을 그대로 따른다. Governs R8, R9.
- KTD5. **`git mv` 로 이름을 바꾼다**: 새 파일을 만들고 옛 파일을 지우는 대신 이동으로 기록해 리뷰에서 변경분이 드러나게 한다. Governs R4, R7.

### Assumptions

- managed settings 는 사용자 설정보다 우선하므로, 여기에 `model` 을 선언하면 `/model` 로 고른 값이 영구적으로 남지 않는다. 이슈가 요구한 "수동 설정 없이 기본값 적용"의 대가로 수용한다. 되돌리려면 해당 키를 모듈에서 빼면 된다. 이 동작을 `docs/provisioning.md` 에 기록한다.
- 현재 호스트에는 `/etc/claude-code/managed-settings.json` 이 아직 없다. 직전 커밋의 managed settings 전환이 아직 activation 되지 않았기 때문이며, 이 계획은 activation 을 수행하지 않는다.

### Sequencing

U1 → U2 → U3 → U4. U3 의 체크는 U1, U2 가 만든 구조를 읽으므로 앞선다.

---

## Implementation Units

### U1. NixOS 모듈 rename 과 managed settings 확장

- **Goal:** `modules/nixos/claude.nix` 가 model, effort, 메모리 스위치를 managed settings 로 선언한다.
- **Requirements:** R1, R2, R3, R4, R7 (KTD1, KTD3, KTD5)
- **Files:** `modules/nixos/agent-memory.nix` → `modules/nixos/claude.nix` (이동), `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` (import 경로)
- **Approach:** `git mv` 로 옮긴 뒤 attrset 에 `model = "opus[1m]"` 과 `effortLevel = "medium"` 을 추가한다. 기존 주석은 managed settings 티어를 고른 이유를 계속 설명하도록 유지하고, 모델 값이 사용자 재정의보다 우선한다는 비자명한 제약을 한 줄로 남긴다.
- **Test Scenarios:** U3 의 `claude` 체크가 담당한다.
- **Verification:** `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`

### U2. Home Manager 모듈 분리

- **Goal:** Claude 용 설정과 Gemini 용 설정이 각자의 모듈에 있다.
- **Requirements:** R5, R6, R7 (KTD2, KTD5)
- **Files:** `home/h82/agent-memory.nix` → `home/h82/claude.nix` (이동 후 축소), `home/h82/gemini.nix` (신규), `home/h82/default.nix` (imports)
- **Approach:** 이동한 `claude.nix` 에는 `CLAUDE_CODE_DISABLE_AUTO_MEMORY` 만 남기고, `.gemini/*` 파일 선언을 `gemini.nix` 로 옮긴다. `default.nix` 의 imports 는 알파벳 순서를 유지한다. 각 모듈의 주석은 상대 모듈을 가리키던 문구를 새 파일 이름으로 고친다.
- **Test Scenarios:** U3 의 `claude`, `gemini` 체크가 담당한다.
- **Verification:** 두 호스트 빌드 모두 성공.

### U3. 체크 분리와 신규 단언

- **Goal:** `claude` 체크가 새 기본값을 지키고, `gemini` 체크가 Gemini 설정을 지킨다.
- **Requirements:** R7, R8, R9 (KTD4, KTD5)
- **Files:** `tests/agent-memory.nix` → `tests/claude.nix` (이동 후 축소·확장), `tests/gemini.nix` (신규), `flake.nix`
- **Approach:** `claude.nix` 체크는 기존 managed settings 단언에 `model` 과 최상위 `effortLevel` 단언을 더하고, Gemini 단언은 새 `gemini.nix` 체크로 옮긴다. 두 체크 모두 대상 항목이 없을 때 Nix 평가가 죽지 않도록 `... or null` 로 읽고 `pkgs.lib.optionalString` 의 absent/present 분기로 감싼다. 이는 managed settings 에만 있던 `managedAbsent`/`managedPresent` 패턴을 `.gemini/settings.json` 과 `.gemini/antigravity-cli/settings.json` 에도 적용한다는 뜻이다. `flake.nix` 의 `agent-memory` 등록을 `claude` 와 `gemini` 로 교체한다.
- **Test Scenarios:**
  - `model` 이 `opus[1m]` 일 때 체크가 통과한다.
  - `model` 을 `sonnet` 으로 바꾸면 체크가 실패한다.
  - `model` 키를 지우면 체크가 실패한다(`jq` 가 `null` 을 돌려주는 경로).
  - `effortLevel` 을 `high` 로 바꾸면 체크가 실패한다.
  - `effortLevel` 키를 지우면 체크가 실패한다.
  - `autoMemoryEnabled` 를 `true` 로 바꾸면 체크가 실패한다.
  - managed settings 항목 자체를 지우면 체크가 평가 오류가 아니라 명시적 메시지로 실패한다.
  - `CLAUDE_CODE_DISABLE_AUTO_MEMORY` 를 지우면 `claude` 체크가 실패한다.
  - `~/.claude/settings.json` 을 Home Manager 가 관리하면 `claude` 체크가 실패한다.
  - Gemini 단언 각각을 뒤집으면 `gemini` 체크가 실패한다.
  - `.gemini/settings.json` 선언과 `.gemini/antigravity-cli/settings.json` 선언을 각각 삭제하면 `gemini` 체크가 평가 오류가 아니라 명시적 메시지로 실패한다.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude`, `nix build --no-link .#checks.x86_64-linux.gemini`, 그리고 위 mutation 을 하나씩 적용해 실패를 확인한 뒤 되돌린다.

### U4. 문서 갱신

- **Goal:** 문서가 새 이름, 새 체크, 새 기본값을 설명한다.
- **Requirements:** R10, R11
- **Files:** `README.md`, `docs/provisioning.md`, `docs/verification.md`
- **Approach:** `README.md` 의 마이그레이션 제외 문장을 좁혀 Claude Code 의 모델·추론 강도 기본값은 관리된다고 적는다. `docs/provisioning.md` 는 (1) 새 모듈 경로, (2) Claude Code 항목의 낡은 서술 교정 — 메모리 스위치는 `~/.claude/settings.json` 이 아니라 `/etc/claude-code/managed-settings.json` 이 담고 `autoDreamEnabled` 언급은 삭제, (3) managed settings 가 사용자 설정을 이긴다는 점과 되돌리는 방법, (4) 기본 모델을 `opus[1m]` 로 두면 모든 세션이 1M 컨텍스트 변형으로 시작하고 1M 을 쓸 수 없는 환경에서는 표준 컨텍스트로 물러난다는 점(표준을 원하면 `[1m]` 표기를 뺀다)을 적는다. `docs/verification.md` 의 `agent-memory` 체크 설명을 `claude` 와 `gemini` 두 항목으로 나누되, 체크가 단언하지 않는 `autoDreamEnabled` 를 `claude` 항목에 옮겨 적지 말고 `model` 과 `effortLevel` 단언을 넣는다. 같은 문서에 activation 이후 1회 수동 확인 절차(사용자가 명시적으로 activation 한 뒤 `claude` 를 실행해 기본 모델과 effort 표시가 선언값과 일치하는지 확인하고, 불일치는 Stop conditions 에 따라 보고)를 남긴다.
- **Test expectation:** none — 문서 전용 단위.
- **Verification:** 문서에 남은 `agent-memory` 문자열이 계획 아카이브 밖에 없다(`rg 'agent-memory' --glob '!.compound-engineering/**'`).

---

## Verification Contract

| 게이트 | 명령 | 적용 단위 |
|---|---|---|
| 포맷 | `nix fmt -- --ci` | U1–U3 |
| 전체 체크 | `nix flake check` | 전부 |
| production 빌드 | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1, U2 |
| bootstrap 빌드 | `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1, U2 |
| mutation 검증 | U3 의 각 mutation 을 적용해 체크 실패를 확인하고 되돌린다 | U3 |
| 잔여 이름 | `rg 'agent-memory'` 결과가 계획 아카이브에만 남는다 | U4 |

위 게이트는 선언된 값만 검증하며, Claude Code 가 managed settings 티어에서 그 값을 실제로 적용하는지는 확인하지 못한다. 런타임 적용은 U4 가 `docs/verification.md` 에 남기는 activation 이후 1회 수동 확인이 담당한다.

`nixos-rebuild switch` 는 검증 수단이 아니다. 하드웨어 반영은 사용자의 명시적 지시가 있을 때만 한다.

---

## Definition of Done

- R1–R11 이 모두 충족된다.
- `nix flake check` 와 두 호스트 빌드가 통과한다.
- `claude`, `gemini` 체크가 mutation testing 에서 각 단언마다 실패한다.
- 저장소에 `agent-memory` 이름의 모듈·테스트·체크가 남지 않는다.
- 시도했다 버린 코드나 주석이 diff 에 남지 않는다.
