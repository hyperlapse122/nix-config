---
name: daily-report
description: 오늘의 git 커밋을 분석해 비개발자용 업무일지를 생성한다. "업무일지", "daily log", "오늘 뭐 했지", "일일 보고" 등의 요청 시 사용.
---

# Daily Log Generator

오늘의 git 커밋 히스토리를 분석하여 비개발자가 읽을 수 있는 간결한 업무일지를 생성한다.

## Workflow

1. 오늘 날짜의 **본인 커밋**만 가져온다 (`git config user.email` 기준으로 필터링):
   - **macOS / Git Bash**
     ```bash
     git log --author="$(git config user.email)" --since="$(date +%Y-%m-%d) 00:00:00" --until="$(date -v+1d +%Y-%m-%d) 00:00:00" --oneline --no-merges
     ```
   - **Linux**
     ```bash
     git log --author="$(git config user.email)" --since="$(date +%Y-%m-%d) 00:00:00" --until="$(date -d "+1 day" +%Y-%m-%d) 00:00:00" --oneline --no-merges
     ```
   - **Windows PowerShell**
     ```powershell
     $start = (Get-Date).Date.ToString('yyyy-MM-dd HH:mm:ss')
     $end = (Get-Date).Date.AddDays(1).ToString('yyyy-MM-dd HH:mm:ss')
     $author = git config user.email
     git log --author="$author" --since="$start" --until="$end" --oneline --no-merges
     ```
   - 결과가 비어있으면 `git config user.name` 기준으로도 한 번 더 시도한다 (이메일 미설정 저장소 대비).

2. 커밋 메시지를 분석하여 **비즈니스 관점**으로 그룹핑한다:
   - 기술 용어를 비개발자가 이해할 수 있는 표현으로 변환
   - 사소한 항목(lint fix, typo, chore, docs 등)은 생략
   - 관련 커밋을 하나의 상위 항목으로 묶기

3. 아래 형식으로 출력한다 (앞의 space 두 개 필수):
   ```plaintext
     - 대분류 작업 항목
       - 세부 내용 1
       - 세부 내용 2
   ```

## Rules

- **언어**: 한국어
- **톤**: 간결하고 사실적. 기술 용어 최소화. `~합니다`, `~했습니다`, `~되도록 개선했습니다` 같은 장황한 서술형 문장 금지.
- **생략 대상**: lint/format 자동 수정, 문서 업데이트, VSCode 설정, yarn.lock 변경, 테스트만 단독으로 있는 커밋
- **포함 대상**: 새 기능, 화면 개발, 아키텍처 변경, 시스템 교체, 버그 수정(중요한 것만)
- **깊이**: 최대 2단계 (대분류 → 세부)
- **분량**: 전체 5~10줄 이내
- **문장 스타일**: 명사형 또는 짧은 동사구 위주로 작성. 보고서체보다 메모체를 우선.
- **표현 예시**:
  ```plaintext
    - 레거시 시스템 통합
      - 기존 .NET 기반 라이센스 모듈을 현재 프로젝트 체계에 통합
    - 레거시 호환 및 신규 인증 적용한 라이선스 서비스 제작 (진행 중)
    - 빌드 시스템 표준화
      - Docker 이미지 생성 과정에서 결과물 저장 위치를 통합하여 관리 효율 개선
  ```
- **금지 예시**:
  ```plaintext
    - 인증 흐름을 정비했습니다
      - 로그인 이후 외부 서비스 승인 절차가 자연스럽게 이어지도록 보완했습니다
  ```
