-- ============================================================
-- URL Scheme: hammerspoon:// 커스텀 스킴 핸들러
-- hammerspoon://file?path=/abs/path&line=42   → Ghostty + nvim
-- hammerspoon://notify?title=제목&msg=내용     → macOS 알림
-- hammerspoon://alert?msg=텍스트&duration=3    → 화면 오버레이
-- hammerspoon://brief?type=morning|evening    → 브리핑 실행
-- hammerspoon://review                        → 코드 리뷰
-- hammerspoon://summarize                     → 페이지 요약
-- hammerspoon://netreport                     → 네트워크 에러 리포트
-- hammerspoon://jump?path=/abs/repo/path      → tmux 윈도우 전환/생성
-- ============================================================
local M = {}

local TMUX_BIN = "/opt/homebrew/bin/tmux"
local GHOSTTY_BUNDLE = "com.mitchellh.ghostty"

local function shellQuote(s)
  return "'" .. (s or ""):gsub("'", [['\'']]) .. "'"
end

-- ── file 액션 ─────────────────────────────────────────────
-- hammerspoon://file?path=/abs/path&line=42

local function handleFile(params)
  local path = params.path
  local line = params.line

  if not path or path == "" then
    print("[url_scheme] file: path 파라미터 없음")
    hs.alert.show("file: path 파라미터 없음")
    return
  end

  if not hs.fs.attributes(path) then
    print("[url_scheme] file: 파일 없음 — " .. path)
    hs.alert.show("파일 없음:\n" .. path)
    return
  end

  local ghostty = hs.application.get(GHOSTTY_BUNDLE)
  if not ghostty then
    print("[url_scheme] file: Ghostty 안 떠있음")
    hs.alert.show("Ghostty 안 떠있음")
    return
  end

  ghostty:activate()

  hs.timer.doAfter(0.15, function()
    local nvimCmd = "nvim"
    if line then
      nvimCmd = nvimCmd .. " +" .. line
    end
    nvimCmd = nvimCmd .. " " .. shellQuote(path)

    local cmd = string.format("%s new-window %s", TMUX_BIN, shellQuote(nvimCmd))

    print("[url_scheme] file: " .. cmd)

    hs.task.new("/bin/zsh", function(exitCode, _, stderr)
      if exitCode ~= 0 then
        print("[url_scheme] file: new-window 실패 — " .. (stderr or ""))
        hs.alert.show("tmux new-window 실패")
      end
    end, { "-c", cmd }):start()
  end)
end

-- ── notify 액션 ───────────────────────────────────────────
-- hammerspoon://notify?title=제목&msg=내용&sound=1

local function handleNotify(params)
  local title = params.title or "Hammerspoon"
  local msg = params.msg or ""

  print("[url_scheme] notify: " .. title .. " — " .. msg)

  local opts = {
    title = title,
    informativeText = msg,
    autoWithdraw = false,
    hasActionButton = false,
  }
  if params.sound ~= "0" then
    opts.soundName = hs.notify.defaultNotificationSound
  end

  hs.notify.new(opts):send()
end

-- ── alert 액션 ────────────────────────────────────────────
-- hammerspoon://alert?msg=완료&duration=3

local function handleAlert(params)
  local msg = params.msg or ""
  local duration = tonumber(params.duration) or 3

  print("[url_scheme] alert: " .. msg)
  hs.alert.show(msg, duration)
end

-- ── brief 액션 ────────────────────────────────────────────
-- hammerspoon://brief?type=morning|evening

local function handleBrief(params)
  local t = params.type or "morning"
  if t == "morning" then
    require("ai_palette.briefing").run()
  elseif t == "evening" then
    require("ai_palette.briefing_evening").run()
  else
    print("[url_scheme] brief: unknown type — " .. t)
    hs.alert.show("brief: unknown type — " .. t)
  end
end

-- ── jump 액션 ─────────────────────────────────────────────
-- hammerspoon://jump?path=/abs/repo/path
-- 해당 path를 cwd로 쓰는 tmux 윈도우가 있으면 전환, 없으면 새로 생성

local function handleJump(params)
  local path = params.path

  if not path or path == "" then
    print("[url_scheme] jump: path 파라미터 없음")
    hs.alert.show("jump: path 파라미터 없음")
    return
  end

  if not hs.fs.attributes(path) then
    print("[url_scheme] jump: 경로 없음 — " .. path)
    hs.alert.show("경로 없음:\n" .. path)
    return
  end

  local ghostty = hs.application.get(GHOSTTY_BUNDLE)
  if not ghostty then
    print("[url_scheme] jump: Ghostty 안 떠있음")
    hs.alert.show("Ghostty 안 떠있음")
    return
  end

  ghostty:activate()

  hs.timer.doAfter(0.15, function()
    -- 해당 path를 cwd로 쓰는 윈도우 찾기
    local findCmd = string.format(
      "%s list-windows -F '#{window_index} #{pane_current_path}' 2>/dev/null | grep -m1 %s | awk '{print $1}'",
      TMUX_BIN, shellQuote(path)
    )
    local idx = hs.execute(findCmd, true)
    idx = idx and idx:gsub("%s+", "") or ""

    local cmd
    if idx ~= "" then
      cmd = string.format("%s select-window -t :%s", TMUX_BIN, idx)
      print("[url_scheme] jump: 기존 윈도우로 전환 — " .. idx)
    else
      cmd = string.format("%s new-window -c %s", TMUX_BIN, shellQuote(path))
      print("[url_scheme] jump: 새 윈도우 생성 — " .. path)
    end

    hs.task.new("/bin/zsh", function(exitCode, _, stderr)
      if exitCode ~= 0 then
        print("[url_scheme] jump: 실패 — " .. (stderr or ""))
        hs.alert.show("tmux jump 실패")
      end
    end, { "-c", cmd }):start()
  end)
end

-- ── 기존 모듈 래퍼 ───────────────────────────────────────
-- URL 스킴 + launcher 양쪽에서 호출 가능

local function handleReview()    require("ai_palette.review").run() end
local function handleSummarize() require("ai_palette.summarize").run() end
local function handleNetreport() require("ai_palette.netreport").run() end

-- ── 액션 라우터 ───────────────────────────────────────────

local ACTIONS = {
  file      = handleFile,
  notify    = handleNotify,
  alert     = handleAlert,
  brief     = handleBrief,
  jump      = handleJump,
  review    = function() handleReview() end,
  summarize = function() handleSummarize() end,
  netreport = function() handleNetreport() end,
}

function M.start()
  for name, handler in pairs(ACTIONS) do
    hs.urlevent.bind(name, function(_, params)
      print("[url_scheme] " .. name .. " 호출됨")
      handler(params)
    end)
  end
end

-- ── Launcher 항목 (chooser용) ─────────────────────────────

M.LAUNCHER_ITEMS = {
  { text = "Code Review",          subText = "PR/MR diff → Claude 리뷰",       fn = handleReview },
  { text = "Page Summarize",       subText = "브라우저 페이지 요약 + 번역",      fn = handleSummarize },
  { text = "Network Error Report", subText = "cURL → 네트워크 에러 리포트",      fn = handleNetreport },
  { text = "Morning Briefing",     subText = "하루 시작 브리핑 수동 실행",        fn = function() handleBrief({ type = "morning" }) end },
  { text = "Evening Briefing",     subText = "저녁 마무리 브리핑 수동 실행",      fn = function() handleBrief({ type = "evening" }) end },
  { text = "Workmux Refresh",      subText = "메뉴바 agent 현황 새로고침",        fn = function() require("workmux.menubar").refresh() end },
  { text = "Workmux Start Issue",  subText = "Linear 이슈 → worktree 시작",      fn = function() require("workmux.start_issue").run() end },
  { text = "Reload Config",        subText = "Hammerspoon 설정 리로드",           fn = hs.reload },
}

-- ── webview 헬퍼 ──────────────────────────────────────────
-- webview에서 hammerspoon:// 링크 클릭을 hs.urlevent로 전달
-- 사용: wv:policyCallback(require("url_scheme").webviewPolicy)

function M.webviewPolicy(action, webview, navAction)
  local url = navAction.request.URL or ""
  if url:match("^hammerspoon://") then
    hs.urlevent.openURL(url)
    return false
  end
  -- 외부 링크는 기본 핸들러로 열기 (url_dispatcher 경유)
  if url:match("^https?://") then
    hs.urlevent.openURL(url)
    return false
  end
  return true
end

return M
