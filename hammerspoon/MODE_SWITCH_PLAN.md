# Hammerspoon 코딩/회의 모드 전환 — 플래닝 초안

## 개요

단축키 하나로 **코딩 모드** ↔ **회의 모드**를 전환한다.  
기존 `ai_palette` 구조와 동일하게 `ai_palette/mode.lua`로 구현한다.

---

## 단축키

| 단축키 | 동작 |
|---|---|
| `Hyper + C` (Cmd+Ctrl+Shift+C) | 코딩 모드 진입 |
| `Hyper + M` (Cmd+Ctrl+Shift+M) | 회의 모드 진입 |

> 토글 방식도 가능 (같은 키로 전환). 일단 각각 분리로 설계.

---

## 코딩 모드 (Coding Mode)

### 목표: 방해 요소 제거 + 개발 환경 세팅

**앱 제어**
- [ ] 집중 앱 열기: Cursor / VS Code, Terminal / iTerm2, 브라우저
- [ ] 커뮤니케이션 앱 숨기기: Slack, Teams, KakaoTalk 등
- [ ] 선택적으로 알림 앱 최소화

**macOS 시스템**
- [ ] 방해 금지(DND / Focus) 모드 ON
  - `hs.execute("shortcuts run 'DND On'")` 또는
  - `do not disturb` AppleScript 활용
- [ ] 화면 밝기 적정 수준 유지 (선택)

**화면 레이아웃**
- [ ] 에디터 → 좌측 2/3
- [ ] 브라우저 (문서/PR) → 우측 1/3
- [ ] `hs.window` + `hs.screen` 으로 배치

**알림 배너**
- [ ] `hs.alert.show("💻 코딩 모드 ON")` 표시

---

## 회의 모드 (Meeting Mode)

### 목표: 커뮤니케이션 환경 세팅 + 개발 도구 정리

**앱 제어**
- [ ] Zoom / Teams / Google Meet 열기 또는 포커스
- [ ] Slack 포커스
- [ ] 에디터·터미널 숨기기 (hide, not quit)

**macOS 시스템**
- [ ] 방해 금지 모드 OFF (알림 수신 허용)
- [ ] 사운드 출력 장치 전환 (선택): 헤드셋 → 자동 감지
  - `hs.audiodevice` 활용 가능

**화면 레이아웃**
- [ ] Zoom 전체 화면 or 중앙 배치
- [ ] Slack → 옆 디스플레이 or 우측 슬림 배치

**알림 배너**
- [ ] `hs.alert.show("🎙 회의 모드 ON")` 표시

---

## 파일 구조 (안)

```
hammerspoon/
├── init.lua                  ← 단축키 바인딩 추가
└── ai_palette/
    ├── mode.lua              ← 신규: 모드 전환 로직
    ├── briefing.lua
    ├── review.lua
    └── ...
```

### init.lua 추가 내용 (예시)

```lua
local mode = require("ai_palette.mode")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "c", mode.coding)  -- Hyper+C
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "m", mode.meeting) -- Hyper+M
```

### mode.lua 스켈레톤

```lua
local M = {}

local function hideApps(names)
  for _, name in ipairs(names) do
    local app = hs.application.find(name)
    if app then app:hide() end
  end
end

local function openOrFocus(name)
  hs.application.launchOrFocus(name)
end

function M.coding()
  -- 1. 개발 앱 열기
  openOrFocus("Cursor")
  openOrFocus("iTerm")

  -- 2. 커뮤니케이션 앱 숨기기
  hideApps({ "Slack", "zoom.us", "Microsoft Teams" })

  -- 3. DND ON (shortcuts 앱 활용)
  hs.execute("shortcuts run 'DND On'", true)

  -- 4. 윈도우 레이아웃 (TODO: 화면 크기에 맞게 조정)
  -- hs.window.focusedWindow():setFrame(...)

  hs.alert.show("💻 코딩 모드 ON")
end

function M.meeting()
  -- 1. 미팅 앱 열기
  openOrFocus("zoom.us")
  openOrFocus("Slack")

  -- 2. 개발 앱 숨기기
  hideApps({ "Cursor", "iTerm", "Terminal" })

  -- 3. DND OFF
  hs.execute("shortcuts run 'DND Off'", true)

  hs.alert.show("🎙 회의 모드 ON")
end

return M
```

---

## 구현 우선순위

| 우선순위 | 항목 | 난이도 |
|---|---|---|
| ★★★ | 앱 열기/숨기기 | 쉬움 |
| ★★★ | 알림 배너 표시 | 쉬움 |
| ★★☆ | DND ON/OFF 연동 | 중간 (Shortcuts 앱 필요) |
| ★★☆ | 윈도우 레이아웃 자동 배치 | 중간 |
| ★☆☆ | 오디오 장치 자동 전환 | 어려움 |
| ★☆☆ | 현재 모드 상태 저장/복원 | 어려움 |

---

## 미결 사항 (결정 필요)

1. **토글 방식 vs 각각 분리 단축키** — 어떤 UX가 더 편한가?
2. **사용 앱 목록** — 코딩 시 주로 쓰는 앱, 회의 시 주로 쓰는 앱 확정
3. **DND 구현 방식** — `shortcuts` CLI 사용 vs AppleScript vs `hs.caffeinate`
4. **윈도우 레이아웃** — 모니터 개수, 선호 배치 방식
5. **모드 진입 시 기존 작업 보존 여부** — 현재 열린 앱/창을 기억해서 복원할지
