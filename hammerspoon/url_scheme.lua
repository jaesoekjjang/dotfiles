-- ============================================================
-- URL Scheme: hammerspoon:// 커스텀 스킴 핸들러
-- hammerspoon://file?path=/abs/path&line=42   → Ghostty + nvim
-- hammerspoon://notify?title=제목&msg=내용     → macOS 알림
-- hammerspoon://alert?msg=텍스트&duration=3    → 화면 오버레이
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

-- ── 액션 라우터 ───────────────────────────────────────────

local ACTIONS = {
  file   = handleFile,
  notify = handleNotify,
  alert  = handleAlert,
}

function M.start()
  for name, handler in pairs(ACTIONS) do
    hs.urlevent.bind(name, function(_, params)
      print("[url_scheme] " .. name .. " 호출됨")
      handler(params)
    end)
  end
end

-- ── webview 헬퍼 ──────────────────────────────────────────
-- webview에서 hammerspoon:// 링크 클릭을 hs.urlevent로 전달
-- 사용: wv:policyCallback(require("url_scheme").webviewPolicy)

function M.webviewPolicy(action, webview, navAction)
  local url = navAction.request.URL or ""
  if url:match("^hammerspoon://") then
    hs.urlevent.openURL(url)
    return false -- webview 내 네비게이션 차단
  end
  return true
end

return M
